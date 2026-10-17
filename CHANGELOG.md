# Changelog

## [4.0.0](https://github.com/NordHero/fenix-images/compare/v3.1.0...v4.0.0) (2026-10-17)


### ⚠ BREAKING CHANGES

* capsules must build the image via `build:` with a `target:` instead of referencing a prebuilt `image:`. The example capsule is updated accordingly.
* CAPSULE_REPOS, CAPSULE_REPOS_FILE, GIT_USER_NAME and GIT_USER_EMAIL are ignored. Declare repos and git identity in git.yaml mounted at /home/dev/.capsule-git.yaml. The legacy manifest's dir must now match ^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$.

### Features

* agents layer + claude-code; remove EXTRA_TOOLS ([#32](https://github.com/NordHero/fenix-images/issues/32)) ([#35](https://github.com/NordHero/fenix-images/issues/35)) ([521d42f](https://github.com/NordHero/fenix-images/commit/521d42f59a9d024e079c81e77ee04afaf4f3d54d))
* capsule-info lists image + mise tools; fix formatting and node denial ([#42](https://github.com/NordHero/fenix-images/issues/42)) ([d5e8063](https://github.com/NordHero/fenix-images/commit/d5e806321d538367d1b190a9454ab4bc6e7ea6ba))
* capsule-updates reports pending OS updates and image age ([#34](https://github.com/NordHero/fenix-images/issues/34)) ([#40](https://github.com/NordHero/fenix-images/issues/40)) ([2ffbbc1](https://github.com/NordHero/fenix-images/commit/2ffbbc155531c73460c995ba092a9eea279942b1))
* cloud-ops layer (aws, gcloud, az) via capsule-tools ([#29](https://github.com/NordHero/fenix-images/issues/29)) ([#33](https://github.com/NordHero/fenix-images/issues/33)) ([a101066](https://github.com/NordHero/fenix-images/commit/a10106629ea1426131db8b7175a40d10a37522f2))
* copilot agent (checksum-only, pinned) ([#32](https://github.com/NordHero/fenix-images/issues/32)) ([#36](https://github.com/NordHero/fenix-images/issues/36)) ([6d37944](https://github.com/NordHero/fenix-images/commit/6d37944ad1ec98f8ba34c8580822e1ba080d0d36))
* deny mise [tools] that shadow registered cloud/agent tools ([#31](https://github.com/NordHero/fenix-images/issues/31)) ([#39](https://github.com/NordHero/fenix-images/issues/39)) ([8472048](https://github.com/NordHero/fenix-images/commit/84720489a53fec4c18baf581cd04f8f229ad4abd))
* gemini agent (opt-in, scoped Node) ([#32](https://github.com/NordHero/fenix-images/issues/32)) ([#38](https://github.com/NordHero/fenix-images/issues/38)) ([7ee1431](https://github.com/NordHero/fenix-images/commit/7ee1431d6ba21f7149a67e03a14257d5d72d67e5))
* git.yaml for capsule git identity and repos ([#27](https://github.com/NordHero/fenix-images/issues/27)) ([bca188b](https://github.com/NordHero/fenix-images/commit/bca188bf2b580034005222bd18074e490525d5e8))
* install bubblewrap + socat (vendor-neutral local-sandbox backends) ([#24](https://github.com/NordHero/fenix-images/issues/24)) ([b6f2f06](https://github.com/NordHero/fenix-images/commit/b6f2f06d01f9c6bcb26c3c7b2261786387a865a6))
* kiro-cli agent (checksum-only from manifest) ([#32](https://github.com/NordHero/fenix-images/issues/32)) ([#37](https://github.com/NordHero/fenix-images/issues/37)) ([83ab6aa](https://github.com/NordHero/fenix-images/commit/83ab6aaa36a1217c06f82a7ac29c7e3e55d9eb3d))
* multi-stage image with base, cloud-ops, agents, mise targets ([#28](https://github.com/NordHero/fenix-images/issues/28)) ([#32](https://github.com/NordHero/fenix-images/issues/32)) ([38a0f5a](https://github.com/NordHero/fenix-images/commit/38a0f5aeb8e9b1f1f692bd1e72d1bf018442ae52))
* portable capsule colors and host terminal requirements ([#21](https://github.com/NordHero/fenix-images/issues/21)) ([38ce63c](https://github.com/NordHero/fenix-images/commit/38ce63c7dd4b1b528db9c7327fb4e8291271543f))


### Bug Fixes

* bake a system Python into the base image ([#26](https://github.com/NordHero/fenix-images/issues/26)) ([f46fd86](https://github.com/NordHero/fenix-images/commit/f46fd8608081bc7aa9fdc20b99bd820206b6c3ab))
* **capsule-git:** include source location in validation errors ([#30](https://github.com/NordHero/fenix-images/issues/30)) ([b2289d9](https://github.com/NordHero/fenix-images/commit/b2289d901d5c657c15154d3732606b81d3f236b4))

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
