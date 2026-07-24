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
nh os switch --diff never

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
