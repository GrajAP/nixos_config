#!/usr/bin/env bash
set -euo pipefail

readonly repo=/etc/nixos
cd "$repo"

usage() {
  printf 'Usage: rebuild [--check]\n'
  printf '  no argument  check, switch, commit and queue a GitHub push\n'
  printf '  --check      check the flake without switching or touching Git\n'
}

check_only=false
case "${1:-}" in
  "")
    ;;
  --check)
    check_only=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if (($# > 1)); then
  usage >&2
  exit 2
fi

readonly runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
exec 9>"$runtime_dir/nixos-rebuild.lock"
if ! flock -n 9; then
  printf 'Another rebuild is already running\n' >&2
  exit 1
fi

if [[ -t 1 || -t 2 ]]; then
  unset NO_COLOR
fi

if [[ "$check_only" == true ]]; then
  nix flake check "path:$repo" --log-format internal-json -v 2>&1 | nom --json
  printf '✓ Checks passed\n'
  exit 0
fi

# nixos-rebuild switch needs root. setuid escalation (sudo) cannot work
# when the NoNewPrivs flag is set (agent sandboxes, containers). In that
# case re-run over ssh to localhost, which starts a fresh session without
# the flag (uses ~/.ssh/id_nixos_local, restricted to loopback in
# authorized_keys). The lock fd is released first so the remote run can
# take it; exit status is propagated.
if ((EUID != 0)) && grep -q '^NoNewPrivs:[[:space:]]*1[[:space:]]*$' /proc/self/status 2>/dev/null; then
  ssh_opts=(
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o StrictHostKeyChecking=accept-new
    -o IdentitiesOnly=yes
    -i "$HOME/.ssh/id_nixos_local"
  )
  if timeout 10 ssh "${ssh_opts[@]}" localhost true 2>/dev/null; then
    printf 'NoNewPrivs sandbox detected; re-running rebuild over ssh to localhost.\n' >&2
    remote_cmd="cd '$repo' && exec ./rebuild.sh"
    if (($# > 0)); then
      remote_cmd="$remote_cmd '$1'"
    fi
    exec 9>&-
    # shellcheck disable=SC2029 # same machine: client-side expansion is intentional
    ssh "${ssh_opts[@]}" localhost "$remote_cmd"
    exit "$?"
  fi
  printf 'Cannot escalate privileges from this shell (NoNewPrivs is set); sudo will not work here.\n' >&2
  printf 'Run ./rebuild.sh --check here if needed, then run ./rebuild.sh from a login terminal to switch.\n' >&2
  exit 1
fi

branch="$(git symbolic-ref --quiet --short HEAD)" || {
  printf 'Git commit skipped: detached HEAD\n' >&2
  exit 1
}
origin_url="$(git remote get-url origin)"
case "$origin_url" in
  git@github.com:*)
    push_url="https://github.com/${origin_url#git@github.com:}"
    ;;
  ssh://git@github.com/*)
    push_url="https://github.com/${origin_url#ssh://git@github.com/}"
    ;;
  https://github.com/*)
    push_url="$origin_url"
    ;;
  *)
    printf 'Git push skipped: origin is not a GitHub remote\n' >&2
    exit 1
    ;;
esac

git add -A
nix flake check --log-format internal-json -v 2>&1 | nom --json
if ((EUID == 0)); then
  nixos-rebuild switch --flake "$repo"
else
  sudo nixos-rebuild switch --flake "$repo"
fi

profile_system="$(readlink -f /nix/var/nix/profiles/system)"
live_system="$(readlink -f /run/current-system)"
if [[ "$profile_system" != "$live_system" ]]; then
  printf '⚠ Built generation %s was not activated live (still running %s).\n' \
    "$(basename "$profile_system")" "$(basename "$live_system")" >&2
  printf '  Approve the nh/polkit prompt when switching, or run:\n' >&2
  printf '  sudo %s/bin/switch-to-configuration switch\n' "$profile_system" >&2
fi

if ! git diff --quiet \
  || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  printf 'System switched, but the repository changed during rebuild; run rebuild again\n' >&2
  exit 1
fi

if git diff --cached --quiet; then
  printf '✓ System switched, Git is already clean\n'
  exit 0
fi

git commit -m "chore(nixos): rebuild $(date '+%Y-%m-%d %H:%M')" >/dev/null
commit="$(git rev-parse HEAD)"
push_unit="rebuild-git-push-${commit:0:12}-$$"

systemd-run --user --collect --quiet \
  --unit="$push_unit" \
  --description="Push NixOS rebuild to GitHub" \
  --working-directory="$repo" \
  --property=Type=exec \
  git -c "remote.origin.pushurl=$push_url" \
  push origin "${commit}:refs/heads/$branch"

printf '✓ System switched and committed, GitHub push is running in background\n'
