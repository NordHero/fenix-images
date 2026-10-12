# Changelog

## [1.4.0](https://github.com/villekr/fenix-images/compare/v1.3.0...v1.4.0) (2026-10-10)


### Features

* add image version/provenance (KAPSULI_INFO, info.json, OCI labels) ([#62](https://github.com/villekr/fenix-images/issues/62)) ([12224fe](https://github.com/villekr/fenix-images/commit/12224fe43cd40e2bec9ff6a27e0bf842fb6745a5))
* **base:** bake Oh-My-Zsh, add HEALTHCHECK, drop host-only fonts ([#57](https://github.com/villekr/fenix-images/issues/57)) ([559996f](https://github.com/villekr/fenix-images/commit/559996f0687f92b18117b4f43fed6df801dc96b0))
* kapsuli-sync — declare and clone a kapsuli's git repos ([#63](https://github.com/villekr/fenix-images/issues/63)) ([af588e6](https://github.com/villekr/fenix-images/commit/af588e69965b4d90ab8212122cb6cf303077b628))
* seed ~/.aws/config from non-secret AWS SSO env vars ([#64](https://github.com/villekr/fenix-images/issues/64)) ([83eadc1](https://github.com/villekr/fenix-images/commit/83eadc10b450bc6dc0466e45d3f5f07096281db7))

## [1.3.0](https://github.com/villekr/fenix-images/compare/v1.2.0...v1.3.0) (2026-10-10)


### Features

* **base:** add openssh-client to the base image ([#42](https://github.com/villekr/fenix-images/issues/42)) ([6256b17](https://github.com/villekr/fenix-images/commit/6256b17ff0ca7196949f7327d09feec68d86b53b))
* install az/copilot/gcloud via mise backends; EXTRA_TOOLS = kiro-cli only ([#55](https://github.com/villekr/fenix-images/issues/55)) ([f661033](https://github.com/villekr/fenix-images/commit/f6610333f7d0d5d6c4b6985239897a0e4ba538e5))
* productize as fenix-images (Layer 3 base + capsule template) ([#53](https://github.com/villekr/fenix-images/issues/53)) ([133ea79](https://github.com/villekr/fenix-images/commit/133ea79a736009d83a49460ba7803fceafa67dd7))


### Bug Fixes

* **extra-tools:** make kiro-cli install idempotent ([#43](https://github.com/villekr/fenix-images/issues/43)) ([0796e58](https://github.com/villekr/fenix-images/commit/0796e58abe313ae9ba73956316c1f9281b5339b4))
* make container provisioning non-fatal with status markers and a report ([#48](https://github.com/villekr/fenix-images/issues/48)) ([d18356f](https://github.com/villekr/fenix-images/commit/d18356fc8eabe051201e4c57864df094f8ed43de))
* **prompt:** align iTerm2 profile names with fenix ([#40](https://github.com/villekr/fenix-images/issues/40)) ([5064406](https://github.com/villekr/fenix-images/commit/506440682ad4a31598cc1cae6b00b37eb9a21866))
* **prompt:** restore iTerm2 profile switch inside containers ([#44](https://github.com/villekr/fenix-images/issues/44)) ([6a32b3c](https://github.com/villekr/fenix-images/commit/6a32b3cf41a5080bfc39ed10ccc90021ad4bc1f8))
* single-source iTerm title (prefix once) and restore it on exit ([#49](https://github.com/villekr/fenix-images/issues/49)) ([e663dae](https://github.com/villekr/fenix-images/commit/e663dae3b605ec3a3a8504bc3d375f0b8091000c))

## [1.2.0](https://github.com/villekr/kapsuli-images/compare/v1.1.0...v1.2.0) (2026-10-08)


### Features

* add editors and pager to base image ([#39](https://github.com/villekr/kapsuli-images/issues/39)) ([2389665](https://github.com/villekr/kapsuli-images/commit/2389665d5d6929bc134e619ddf35f1bebfe6223c))
* **prompt:** set kapsuli title on startup and add login banner ([#37](https://github.com/villekr/kapsuli-images/issues/37)) ([a1776ce](https://github.com/villekr/kapsuli-images/commit/a1776cea1d3e4aff3945765bdfc4919254554fff))

## [1.1.0](https://github.com/villekr/kapsuli-images/compare/v1.0.1...v1.1.0) (2026-10-07)


### Features

* **prompt:** match host p10k rainbow style; prefix window title with kapsuli name ([#32](https://github.com/villekr/kapsuli-images/issues/32)) ([c9cac0e](https://github.com/villekr/kapsuli-images/commit/c9cac0e7e9136b2784614f0bd0c6b5fc0608a089))

## [1.0.1](https://github.com/villekr/kapsuli-images/compare/v1.0.0...v1.0.1) (2026-10-06)


### Bug Fixes

* **ci:** slim release workflow to build+push; drop stale provision.sh check ([#22](https://github.com/villekr/kapsuli-images/issues/22)) ([5e77b07](https://github.com/villekr/kapsuli-images/commit/5e77b070d0823c8ede914d4700ecc16ec0161136))
* **ci:** trigger release on release-published + workflow_dispatch ([#20](https://github.com/villekr/kapsuli-images/issues/20)) ([d6c06f0](https://github.com/villekr/kapsuli-images/commit/d6c06f0eb61c1b6a6f7ae767dd11dc71a89b3749))

## 1.0.0 (2026-10-06)


### Features

* **images:** make go a full dev image; add build-essential to base ([4c59b24](https://github.com/villekr/kapsuli-images/commit/4c59b245cbd78875f24cf59193c97cb42d588c62))
* layered capsule images with composable go layer (issue [#6](https://github.com/villekr/kapsuli-images/issues/6)/[#7](https://github.com/villekr/kapsuli-images/issues/7)) ([2db9beb](https://github.com/villekr/kapsuli-images/commit/2db9bebe0db93fe079a979e2c917ae5695967044))


### Bug Fixes

* **base:** add headless xclip shim to silence clipboard warnings ([276a3f5](https://github.com/villekr/kapsuli-images/commit/276a3f500039eacc6a997d983a4babc33e1f3967))
* **base:** apply LTS security updates at build; keep ubuntu 24.04 pinned ([#8](https://github.com/villekr/kapsuli-images/issues/8)) ([6d98e90](https://github.com/villekr/kapsuli-images/commit/6d98e90d5545ed3c89a19c580834dd9fb2564346))
* **base:** show a kapsuli animal icon in the prompt instead of 'devbox' text ([#10](https://github.com/villekr/kapsuli-images/issues/10)) ([398adc1](https://github.com/villekr/kapsuli-images/commit/398adc159bcfd1bde9d675b251793a0d24059dc7))
* **ci:** build images on the shared docker daemon so chained FROM resolves ([4f9cc7e](https://github.com/villekr/kapsuli-images/commit/4f9cc7ed859bb3e479ece03fda3e9184c53cd58a))
* **ci:** make Trivy SARIF upload non-blocking ([#19](https://github.com/villekr/kapsuli-images/issues/19)) ([7ae95f2](https://github.com/villekr/kapsuli-images/commit/7ae95f290ea804bd7ef4ea18ba61a11867049a38))
