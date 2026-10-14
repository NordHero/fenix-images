# Changelog

## [3.1.0](https://github.com/NordHero/fenix-images/compare/v3.0.0...v3.1.0) (2026-10-14)


### Features

* daily mise version check PR and supply-chain disclaimer ([#15](https://github.com/NordHero/fenix-images/issues/15)) ([19a8f38](https://github.com/NordHero/fenix-images/commit/19a8f38b6abc815a7e1f6f88d1d3c012a63e391a))

## [3.0.0](https://github.com/NordHero/fenix-images/compare/v2.1.0...v3.0.0) (2026-10-13)


### ⚠ BREAKING CHANGES

* a capsule on a fresh volume no longer provisions its mise.toml on start unless CAPSULE_TRUST_MISE=1 is set or the user runs `mise trust ~/mise.toml && provision.sh`. Existing volumes keep their trust.

### Bug Fixes

* narrow safe.directory, harden capsule-sync input and welcome text ([#10](https://github.com/NordHero/fenix-images/issues/10)) ([cb5a107](https://github.com/NordHero/fenix-images/commit/cb5a10700196a6d51fd39c2441583dd504e3b0b9))
* provision only a trusted mise.toml ([#11](https://github.com/NordHero/fenix-images/issues/11)) ([b1c3ff8](https://github.com/NordHero/fenix-images/commit/b1c3ff8fb75df3a18b6d6d04b437cdced8a29282))

## [2.1.0](https://github.com/NordHero/fenix-images/compare/v2.0.0...v2.1.0) (2026-10-13)


### Features

* keyring password, supply-chain pinning, CI gate ([#7](https://github.com/NordHero/fenix-images/issues/7)) ([a9b610e](https://github.com/NordHero/fenix-images/commit/a9b610eaf929afbc148e3252ea6fccc1b4efc48a))

## [2.0.0](https://github.com/NordHero/fenix-images/compare/v1.4.0...v2.0.0) (2026-10-13)


### ⚠ BREAKING CHANGES

* rename KAPSULI_* to CAPSULE_* and kapsuli-* to capsule-* ([#3](https://github.com/NordHero/fenix-images/issues/3))

### Features

* rename KAPSULI_* to CAPSULE_* and kapsuli-* to capsule-* ([#3](https://github.com/NordHero/fenix-images/issues/3)) ([cc5ca41](https://github.com/NordHero/fenix-images/commit/cc5ca41a9f758b688c7f990b757309a2cfdd8961))


### Bug Fixes

* security quick wins (pinned actions, SARIF threshold, LF endings, tini) ([#6](https://github.com/NordHero/fenix-images/issues/6)) ([8697b4a](https://github.com/NordHero/fenix-images/commit/8697b4a623c27931726201eb82fb3af00a0a2e82))

## 1.4.0 (2026-10-10)


### Features

* add image version/provenance (CAPSULE_INFO, info.json, OCI labels) (#62) (12224fe)
* **base:** bake Oh-My-Zsh, add HEALTHCHECK, drop host-only fonts (#57) (559996f)
* capsule-sync — declare and clone a capsule's git repos (#63) (af588e6)
* seed ~/.aws/config from non-secret AWS SSO env vars (#64) (83eadc1)

## 1.3.0 (2026-10-10)


### Features

* **base:** add openssh-client to the base image (#42) (6256b17)
* install az/copilot/gcloud via mise backends; EXTRA_TOOLS = kiro-cli only (#55) (f661033)
* productize as fenix-images (base image + capsule template) (#53) (133ea79)


### Bug Fixes

* **extra-tools:** make kiro-cli install idempotent (#43) (0796e58)
* make container provisioning non-fatal with status markers and a report (#48) (d18356f)
* **prompt:** align iTerm2 profile names (#40) (5064406)
* **prompt:** restore iTerm2 profile switch inside containers (#44) (6a32b3c)
* single-source iTerm title (prefix once) and restore it on exit (#49) (e663dae)

## 1.2.0 (2026-10-08)


### Features

* add editors and pager to base image (#39) (2389665)
* **prompt:** set capsule title on startup and add login banner (#37) (a1776ce)

## 1.1.0 (2026-10-07)


### Features

* **prompt:** use p10k rainbow style; prefix window title with capsule name (#32) (c9cac0e)

## 1.0.1 (2026-10-06)


### Bug Fixes

* **ci:** slim release workflow to build+push; drop stale provision.sh check (#22) (5e77b07)
* **ci:** trigger release on release-published + workflow_dispatch (#20) (d6c06f0)

## 1.0.0 (2026-10-06)


### Features

* **images:** make go a full dev image; add build-essential to base (4c59b24)
* layered capsule images with composable go layer (issue #6/#7) (2db9beb)


### Bug Fixes

* **base:** add headless xclip shim to silence clipboard warnings (276a3f5)
* **base:** apply LTS security updates at build; keep ubuntu 24.04 pinned (#8) (6d98e90)
* **base:** show a capsule animal icon in the prompt instead of 'devbox' text (#10) (398adc1)
* **ci:** build images on the shared docker daemon so chained FROM resolves (4f9cc7e)
* **ci:** make Trivy SARIF upload non-blocking (#19) (7ae95f2)
