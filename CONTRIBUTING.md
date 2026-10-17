# Contributing

External contributions are not accepted. Pull requests from forks by anyone
who is not an owner, member or collaborator are closed automatically
(`.github/workflows/close-external-prs.yml`). Report security issues privately
via **Security > Report a vulnerability** (see [`SECURITY.md`](SECURITY.md)).

Conventions for agents and automation live in [`AGENTS.md`](AGENTS.md); this
guide covers the local setup and quality gates for human contributors.

## Local setup

```bash
pipx install pre-commit            # or: brew install pre-commit
pre-commit install                 # run hooks on every commit
pre-commit run --all-files         # one-off full sweep
```

## Quality gates

**Pre-commit hooks** (`.pre-commit-config.yaml`, local only):

| Tool | Role |
|---|---|
| `shellcheck -S warning` | shell linting |
| `shfmt -i 2 -ci -bn` | shell formatting (2-space indent, indented case arms) |
| `hadolint` | Dockerfile linting |
| `gitleaks` | secret scanning |

**CI** (`.github/workflows/build-images.yml`):

- `validate-config`: example `mise.toml` parses and has no `"latest"`.
- `build`: builds the image; asserts contents, the entrypoint, the keyring
  password flows, `capsule-sync`, AWS seeding, provisioning of one `[tools]`
  and one `EXTRA_TOOLS` package; Trivy scan (HIGH/CRITICAL).
- `install-matrix`: on changes under `vendor/` or to the Dockerfile, installs
  every `capsule-tools` entry on amd64 and arm64 (one cell per tool/arch, so a
  broken pin fails only that entry) and runs the one-Python-on-`PATH` check.
- `cloud-ops-full`: builds the full `aws gcloud az` selection, asserts the CLIs
  and their Python, the `capsule-tools list`, and that a tampered trust anchor
  fails the build; Trivy scan.
- `size-report`: reports per-tool and per-target image sizes to the job summary
  and fails when a tool grows more than 20% vs `.github/sizes.json` without the
  `size-growth-ok` label.
- `verify-example`: runs the example capsule, installs its declared tools, and
  Trivy-scans the installed tools (HIGH/CRITICAL).
- `ci-ok`: always runs and passes only when every job above passed or was
  skipped. Jobs are skipped by path: docs-only changes skip all of them;
  `verify-example` runs only when the image or example changes;
  `install-matrix`, `cloud-ops-full` and `size-report` run only when `vendor/`
  or the Dockerfile changes. `ci-ok` is the required status check on `main`.

release-please PRs are pushed with the workflow token, which does not trigger
workflows; `release-please.yml` dispatches `build-images` on the release branch
so the PR gets `ci-ok`. To re-run CI on any branch:
`gh workflow run build-images.yml --ref <branch>`.

Keep `main` green; open a pull request and never push to `main` directly.
Conventional Commits drive [release-please](https://github.com/googleapis/release-please)
(`feat`/`fix`/`chore`/`ci`/...).

## Scope

This repo builds a minimal development base image and ships a sample capsule.
It does not contain project or customer content, cloud/AI work, or secrets —
see [`README.md`](README.md), [`AGENTS.md`](AGENTS.md), and
[`SECURITY.md`](SECURITY.md).
