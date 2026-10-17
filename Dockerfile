FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV BROWSER=true
ENV DEV_USER=dev
ENV DEV_UID=1000
ENV DEV_GID=1000
ENV DEV_HOME=/home/dev

ARG OHMYZSH_COMMIT=964ddf789b022b6958b27d02d7fa54f552de21e9
ARG POWERLEVEL10K_COMMIT=d05a1b00f9a61f9578bf9dc19b8451942dde8734
ARG YQ_VERSION=v4.54.1
ARG YQ_SHA256_AMD64=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f
ARG YQ_SHA256_ARM64=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b
ARG GH_APT_FINGERPRINTS="2C6106201985B60E6C7AC87323F3D4EA75716059 7F38BBB59D064DBCB3D84D725612B36462313325"

ARG IMAGE_VERSION=dev
ARG SOURCE_COMMIT=unknown
ARG BUILD_DATE=unknown

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git zsh locales \
      openssh-client \
      unzip tini \
      python3 python-is-python3 \
      vim nano less \
      bubblewrap socat \
      dbus-x11 gnome-keyring libsecret-1-0 libsecret-tools \
    && rm -f /usr/share/dbus-1/services/org.freedesktop.secrets.service \
      /usr/share/dbus-1/services/org.gnome.keyring.service \
      /usr/share/dbus-1/services/org.freedesktop.impl.portal.Secret.service \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN if getent passwd ${DEV_UID} >/dev/null; then \
      existing="$(getent passwd ${DEV_UID} | cut -d: -f1)"; \
      userdel -r "$existing" 2>/dev/null || true; \
    fi \
    && groupadd -g ${DEV_GID} ${DEV_USER} \
    && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /usr/bin/zsh -d ${DEV_HOME} ${DEV_USER}

RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && got="$(gpg --show-keys --with-colons /usr/share/keyrings/githubcli-archive-keyring.gpg | awk -F: '/^pub/{getline; print $10}' | sort | tr '\n' ' ')" \
    && want="$(printf '%s\n' ${GH_APT_FINGERPRINTS} | sort | tr '\n' ' ')" \
    && test "$got" = "$want" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && mv /usr/bin/gh /usr/bin/gh.real

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
      amd64) want="${YQ_SHA256_AMD64}" ;; \
      arm64) want="${YQ_SHA256_ARM64}" ;; \
      *) exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}" -o /tmp/yq \
    && echo "${want}  /tmp/yq" | sha256sum -c - \
    && install -m 0755 /tmp/yq /usr/local/bin/yq \
    && rm -f /tmp/yq \
    && yq --version

RUN fetch() { git init -q "$3" && git -C "$3" fetch -q --depth=1 "$1" "$2" && git -C "$3" checkout -q FETCH_HEAD && rm -rf "$3/.git"; } \
    && fetch https://github.com/ohmyzsh/ohmyzsh.git "${OHMYZSH_COMMIT}" /opt/devbox-skel/.oh-my-zsh \
    && fetch https://github.com/romkatv/powerlevel10k.git "${POWERLEVEL10K_COMMIT}" \
      /opt/devbox-skel/.oh-my-zsh-custom/themes/powerlevel10k \
    && chown -R ${DEV_UID}:${DEV_GID} /opt/devbox-skel

COPY --chown=${DEV_UID}:${DEV_GID} base/zshrc /opt/devbox-skel/.zshrc
COPY --chown=${DEV_UID}:${DEV_GID} base/p10k.zsh /opt/devbox-skel/.p10k.zsh

COPY --chmod=0755 base/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 base/provision.sh /usr/local/bin/provision.sh
COPY --chmod=0755 base/xclip-shim.sh /usr/local/bin/xclip
COPY --chmod=0755 base/capsule-info.sh /usr/local/bin/capsule-info
COPY --chmod=0755 base/capsule-sync.sh /usr/local/bin/capsule-sync
COPY --chmod=0755 base/capsule-git.sh /usr/local/bin/capsule-git
COPY --chmod=0755 base/capsule-unlock.sh /usr/local/bin/capsule-unlock
COPY --chmod=0755 base/gh.sh /usr/bin/gh

RUN mkdir -p /etc/capsule/start.d /etc/capsule/zshrc.d \
    && printf '{\n  "image_version": "%s",\n  "source_commit": "%s",\n  "build_date": "%s",\n  "base_os": "ubuntu:24.04"\n}\n' \
      "${IMAGE_VERSION}" "${SOURCE_COMMIT}" "${BUILD_DATE}" > /etc/capsule/info.json

LABEL org.opencontainers.image.title="fenix-base" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/NordHero/fenix-images" \
      org.opencontainers.image.base.name="ubuntu:24.04"

ENV CAPSULE_INFO="fenix-base ${IMAGE_VERSION} (${SOURCE_COMMIT}, built ${BUILD_DATE})"

USER ${DEV_USER}
WORKDIR ${DEV_HOME}

ENV PATH="${DEV_HOME}/.local/bin:/usr/local/bin:${PATH}"

RUN mkdir -p ${DEV_HOME}/workspace

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD sh -c 'f="$HOME/.capsule/status"; [ ! -f "$f" ] || grep -q "rc=0" "$f"'

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

FROM base AS cloud-ops
ARG CLOUD_CLIS=""
COPY --chmod=0755 base/cloud-ops.sh /usr/local/bin/cloud-ops.sh
COPY --chmod=0755 vendor/capsule-tools.sh /usr/local/bin/capsule-tools
COPY vendor/tools/ /usr/local/share/capsule-tools/tools/
COPY vendor/gemini/ /usr/local/share/capsule-tools/gemini/
USER root
RUN CLOUD_CLIS="${CLOUD_CLIS}" /usr/local/bin/cloud-ops.sh
USER ${DEV_USER}

FROM cloud-ops AS agents
ARG CODING_AGENTS=""
COPY --chmod=0755 base/agents.sh /usr/local/bin/agents.sh
USER root
RUN CODING_AGENTS="${CODING_AGENTS}" /usr/local/bin/agents.sh
USER ${DEV_USER}

FROM agents AS mise
ARG MISE_VERSION=v2026.10.10
USER root
RUN arch="$(dpkg --print-architecture | sed 's/amd64/x64/;s/arm64/arm64/')" \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${arch}-musl.tar.gz" -o /tmp/mise.tgz \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/SHASUMS256.txt" -o /tmp/SHASUMS256.txt \
    && want="$(grep "mise-${MISE_VERSION}-linux-${arch}-musl.tar.gz\$" /tmp/SHASUMS256.txt | awk '{print $1}')" \
    && echo "${want}  /tmp/mise.tgz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/mise.tgz \
    && mv /tmp/mise/bin/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise /tmp/mise.tgz /tmp/SHASUMS256.txt \
    && mise --version
COPY --chmod=0755 base/start.d/10-mise.sh /etc/capsule/start.d/10-mise.sh
COPY base/zshrc.d/10-mise.zsh /etc/capsule/zshrc.d/10-mise.zsh
USER ${DEV_USER}

ENV PATH="${DEV_HOME}/.local/share/mise/shims:${DEV_HOME}/.local/bin:/usr/local/bin:${PATH}"
