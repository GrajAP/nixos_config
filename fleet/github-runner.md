# GitHub Actions runner on grajpap

Three self-hosted runners for `be-spotted/bespotted_codex`: `system/ci/default.nix`.
Label: `grajpap-ci`. Units: `github-runner-bespotted.service`,
`github-runner-bespotted-2.service`, `github-runner-bespotted-3.service`. They
restart 30 s after a crash. Each keeps its Rust build output in
`/var/lib/github-runner-cache/bespotted/cargo-target/<name>`.

## First setup

A unit stays inactive until its token file exists. One registration token is
valid for one hour and can register every runner; each runner keeps its own
credentials afterwards. Changing
`workDir`, the url, the name or the labels needs a new token before the rebuild.

```bash
# on a machine logged in with `gh`
token="$(gh api -X POST repos/be-spotted/bespotted_codex/actions/runners/registration-token --jq .token)"

# as root on grajpap
for name in bespotted bespotted-2 bespotted-3; do
  printf %s "$token" > "/var/lib/github-runner-tokens/$name.token"
  chmod 600 "/var/lib/github-runner-tokens/$name.token"
  systemctl start "github-runner-$name"
done
```

Then send jobs to it:

```bash
gh variable set CI_RUNNER -R be-spotted/bespotted_codex --body grajpap-ci
```

## Recovery

- Back to GitHub-hosted runners: `gh variable delete CI_RUNNER -R be-spotted/bespotted_codex`.
- Jobs wait while the PC is off. GitHub fails a job queued for 24 hours.
- GitHub removes a runner that stays offline for 14 days. Repeat first setup with
  a new token.
- The shutdown widget timer does not wait for CI: a job running at that moment is lost.
- The job can reach the Docker socket, which is root on this PC. Keep this runner
  on private repos only.
