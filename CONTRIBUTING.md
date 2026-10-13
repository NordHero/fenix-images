# Contributing

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

- `validate-config`: example `mise.toml` parses, has no `"latest"`, and
  `example/mise.lock` is current (`mise lock` produces no diff).
- `build`: builds the image; asserts contents, the entrypoint, the keyring
  password flows, `capsule-sync`, AWS seeding, provisioning of one `[tools]`
  and one `EXTRA_TOOLS` package; Trivy scan (HIGH/CRITICAL).
- `verify-example`: runs the example capsule and installs its full toolset.
- `ci-ok`: always runs and passes only when every job above passed or was
  skipped. Jobs are skipped by path: docs-only changes skip all of them;
  `verify-example` runs only when the image or example changes. `ci-ok` is the
  required status check on `main`.

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
