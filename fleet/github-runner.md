# GitHub Actions runner on grajpap

Self-hosted runner for `be-spotted/bespotted_codex`: `system/ci/default.nix`.
Label: `grajpap-ci`. Unit: `github-runner-bespotted.service`.

## First setup

The unit stays inactive until the token file exists. The registration token is
valid for one hour, and the runner keeps its own credentials afterwards. Changing
`workDir`, the url, the name or the labels needs a new token before the rebuild.

```bash
# on a machine logged in with `gh`
token="$(gh api -X POST repos/be-spotted/bespotted_codex/actions/runners/registration-token --jq .token)"

# as root on grajpap
printf %s "$token" > /var/lib/github-runner-tokens/bespotted.token
chmod 600 /var/lib/github-runner-tokens/bespotted.token
systemctl start github-runner-bespotted
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
- The auto-shutdown timer does not wait for CI: a job running at that moment is lost.
- The job can reach the Docker socket, which is root on this PC. Keep this runner
  on private repos only.
