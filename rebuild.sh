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
  printf '  no argument  check, switch, commit and push to GitHub (needs sudo)\n'
  printf '  --check      check the flake without switching or touching Git (rootless)\n'
  printf '  --build      check and build the system without switching or touching Git (rootless)\n'
}

# Runs first, so a secret is never evaluated, committed or pushed.
# Config: .gitleaks.toml.
leak_scan() {
  local -a cmd=(gitleaks)
  if ! command -v gitleaks >/dev/null 2>&1; then
    if command -v nix >/dev/null 2>&1; then
      cmd=(nix run --inputs-from "$repo" nixpkgs#gitleaks --)
    else
      printf '⚠ gitleaks not found; skipping the secret scan\n' >&2
      return 0
    fi
  fi

  if "${cmd[@]}" dir "$repo" --no-banner --redact --verbose; then
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
  # Picks up other hosts' commits before the build. GIT_TERMINAL_PROMPT=0: a
  # credential prompt would otherwise hang the run while it holds the lock.
  if ! GIT_TERMINAL_PROMPT=0 git pull --ff-only; then
    printf '⚠ could not fast-forward from origin (no credentials, or the branch has diverged); continuing with the local tree\n' >&2
  fi
fi

git add -A
# path:, so the working tree is built, not HEAD.
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
  # Hand-made commits since the last run.
  unpushed=1
fi

if ((unpushed == 0)); then
  printf '✓ System switched, Git is already clean\n'
  exit 0
fi

# Every host pushes to the same branch, so origin often moves during a run.
# Merge it in before pushing. A conflict aborts and is left for a human.
integrate_origin() {
  local upstream
  upstream="$(git rev-parse --quiet --verify '@{upstream}' 2>/dev/null)" || return 0

  GIT_TERMINAL_PROMPT=0 git fetch --quiet origin "$branch" 2>/dev/null || {
    printf '⚠ git fetch failed; the push below may be rejected\n' >&2
    return 0
  }

  git merge-base --is-ancestor "$upstream" HEAD && return 0

  printf 'Merging origin/%s into %s before pushing\n' "$branch" "$branch"
  if GIT_TERMINAL_PROMPT=0 GIT_MERGE_AUTOEDIT=no git merge --no-edit "$upstream"; then
    return 0
  fi

  git merge --abort 2>/dev/null || true
  printf '✗ could not merge origin/%s cleanly; merge aborted, nothing was pushed\n' \
    "$branch" >&2
  printf '  Resolve by hand: git fetch origin && git merge origin/%s\n' "$branch" >&2
  return 1
}

push_branch() {
  local commit attempt
  commit="$(git rev-parse HEAD)"

  # One retry: another host can push between the fetch and this push.
  for attempt in 1 2; do
    if GIT_TERMINAL_PROMPT=0 git -c "remote.origin.pushurl=$push_url" \
      push origin "${commit}:refs/heads/$branch"; then
      printf '✓ Pushed to %s\n' "$push_url"
      return 0
    fi

    if ((attempt == 1)); then
      printf '⚠ push rejected; integrating origin and retrying once\n' >&2
      # A merge makes a new commit to push, so re-read HEAD.
      integrate_origin && commit="$(git rev-parse HEAD)"
      continue
    fi

    return 1
  done
}

if ((has_origin)); then
  integrate_origin || true

  if ((committed == 1)); then
    printf '✓ System switched and committed\n'
  else
    printf '✓ System switched, %s local commit(s) to publish\n' \
      "$(git rev-list --count '@{upstream}..HEAD')"
  fi

  # Foreground on purpose: a failed push must be loud, not lost in a unit.
  if ! push_branch; then
    printf '✗ push failed; the system is updated but these commits are local only.\n' >&2
    printf '  Run: git push origin %s\n' "$branch" >&2
    exit 1
  fi
else
  printf '✓ System switched and committed (no GitHub origin; push skipped)\n'
fi
