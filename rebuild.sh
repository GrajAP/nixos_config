#!/usr/bin/env bash
set -euo pipefail

readonly repo=/etc/nixos
cd "$repo"

sudo() {
  if grep -q 'NoNewPrivs:[[:space:]]*1' /proc/self/status 2>/dev/null; then
    local flags=(--user --quiet --same-dir --collect)
    if [[ -t 0 && -t 1 ]]; then
      flags+=(--pty)
    else
      flags+=(--pipe)
    fi
    systemd-run "${flags[@]}" /run/wrappers/bin/sudo "$@"
  else
    command sudo "$@"
  fi
}

usage() {
  printf 'Usage: rebuild [--check|--build]\n'
  printf '  no argument  check, switch, commit and queue a GitHub push (needs root via sudo)\n'
  printf '  --check      check the flake without switching or touching Git (rootless)\n'
  printf '  --build      check and build the system without switching or touching Git (rootless)\n'
}

# Scans the working tree, which is what `git add -A` below would commit and the
# push at the end would publish. This runs before `nix flake check` so a secret
# is never evaluated, committed or pushed, whatever the mode. The config lives in
# .gitleaks.toml next to the script; --redact keeps the secret out of the
# terminal and out of the log.
leak_scan() {
  if ! command -v gitleaks >/dev/null 2>&1; then
    printf '⚠ gitleaks not found; skipping the secret scan\n' >&2
    return 0
  fi

  if gitleaks dir "$repo" --no-banner --redact --verbose; then
    printf '✓ No secrets found\n'
    return 0
  fi

  printf '✗ gitleaks found secrets; nothing was built, committed or pushed.\n' >&2
  printf '  Move them out of the repo, or allowlist them in .gitleaks.toml if public.\n' >&2
  return 1
}

mode="switch"
case "${1:-}" in
  "")
    ;;
  --check)
    mode="check"
    ;;
  --build)
    mode="build"
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

leak_scan || exit 1

if [[ "$mode" == "check" ]]; then
  nix flake check "path:$repo" --log-format internal-json -v 2>&1 | nom --json
  printf '✓ Checks passed\n'
  exit 0
fi

if [[ "$mode" == "build" ]]; then
  nix flake check "path:$repo" --log-format internal-json -v 2>&1 | nom --json
  nixos-rebuild build --flake "$repo#$(hostname)"
  printf '✓ Build succeeded (no switch, Git untouched)\n'
  exit 0
fi

branch="$(git symbolic-ref --quiet --short HEAD)" || {
  printf 'Git commit skipped: detached HEAD\n' >&2
  exit 1
}

has_origin=0
push_url=""
if origin_url="$(git remote get-url origin 2>/dev/null)"; then
  case "$origin_url" in
    git@github.com:*)
      push_url="https://github.com/${origin_url#git@github.com:}"
      has_origin=1
      ;;
    ssh://git@github.com/*)
      push_url="https://github.com/${origin_url#ssh://git@github.com/}"
      has_origin=1
      ;;
    https://github.com/*)
      push_url="$origin_url"
      has_origin=1
      ;;
    *)
      printf 'Git push skipped: origin is not a GitHub remote\n' >&2
      ;;
  esac
fi

tree_clean=1
if ! git diff --quiet || ! git diff --cached --quiet \
  || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  tree_clean=0
fi

if ((has_origin && tree_clean)); then
  git pull --ff-only || printf '⚠ git pull --ff-only failed; continuing with the local tree\n' >&2
fi

git add -A
# path:, not a bare "$repo#attr". A flake that resolves to a git repository is
# evaluated from HEAD, which means a staged or edited file is invisible to both
# the checks and the switch: the build would describe yesterday's config, and
# only the commit below would carry the edit. `path:` evaluates the working
# tree, untracked files included, so what gets built is what gets committed.
# (fleet/auto-rebuild does the same, and commits before switching for the same
# reason.)
nix flake check "path:$repo" --log-format internal-json -v 2>&1 | nom --json
sudo nixos-rebuild switch --flake "path:$repo#$(hostname)"

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

unpushed=0
committed=0
if ! git diff --cached --quiet; then
  git commit -m "chore(nixos): rebuild $(date '+%Y-%m-%d %H:%M')" >/dev/null
  unpushed=1
  committed=1
elif git rev-parse --quiet --verify '@{upstream}' >/dev/null \
  && [[ -n "$(git log --oneline '@{upstream}..HEAD')" ]]; then
  # Commits made by hand since the last run. Work authored here is published;
  # work that only arrived from origin is not pushed back, or every host in the
  # fleet would re-push the others' commits at each other. Same rule as
  # fleet/auto-rebuild.
  unpushed=1
fi

if ((unpushed == 0)); then
  printf '✓ System switched, Git is already clean\n'
  exit 0
fi

if ((has_origin)); then
  commit="$(git rev-parse HEAD)"

  if ((committed == 1)); then
    printf '✓ System switched and committed\n'
  else
    printf '✓ System switched, %s local commit(s) to publish\n' \
      "$(git rev-list --count '@{upstream}..HEAD')"
  fi

  # In the foreground, with prompting off. This used to run through
  # `systemd-run --user`, which inherited a PATH without gh: the credential
  # helper failed and the push died with status 128 inside a unit nobody was
  # watching, so the commits silently stayed local.
  if GIT_TERMINAL_PROMPT=0 git -c "remote.origin.pushurl=$push_url" \
    push origin "${commit}:refs/heads/$branch"; then
    printf '✓ Pushed to %s\n' "$push_url"
  else
    printf '⚠ push failed; those commits are local only. Run: git push origin %s\n' \
      "$branch" >&2
  fi
else
  printf '✓ System switched and committed (no GitHub origin; push skipped)\n'
fi
