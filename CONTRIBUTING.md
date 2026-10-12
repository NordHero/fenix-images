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

The same checks run as **pre-commit hooks** (`.pre-commit-config.yaml`) and in
**CI** (`.github/workflows/build-images.yml`):

| Tool | Role |
|---|---|
| `shellcheck -S warning` | shell linting |
| `shfmt -i 2 -ci -bn` | shell formatting (2-space indent, indented case arms) |
| `hadolint` | Dockerfile linting |
| `gitleaks` | secret scanning |
| `trivy` | image vulnerability scan (HIGH/CRITICAL) in CI |

CI also builds the base image and asserts the entrypoint reaches steady state
and that one `[tools]` and one `EXTRA_TOOLS` package provision and resolve.

Keep `main` green; open a pull request and never push to `main` directly.
Conventional Commits drive [release-please](https://github.com/googleapis/release-please)
(`feat`/`fix`/`chore`/`ci`/...).

## Scope

This repo builds the fenix **Layer 3** base image and ships a sample capsule.
It does not contain project or customer content, cloud/AI work, or secrets —
see [`README.md`](README.md), [`AGENTS.md`](AGENTS.md), and
[`SECURITY.md`](SECURITY.md).
