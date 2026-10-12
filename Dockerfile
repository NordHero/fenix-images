FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV BROWSER=true
ENV DEV_USER=dev
ENV DEV_UID=1000
ENV DEV_GID=1000
ENV DEV_HOME=/home/dev

ARG MISE_VERSION=v2026.10.3

ARG IMAGE_VERSION=dev
ARG SOURCE_COMMIT=unknown
ARG BUILD_DATE=unknown

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git zsh locales \
      openssh-client \
      unzip \
      vim nano less \
      dbus-x11 gnome-keyring libsecret-1-0 libsecret-tools \
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
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && mv /usr/bin/gh /usr/bin/gh.real \
    && printf '#!/bin/bash\n[ -f "$HOME/.keyring-env" ] && source "$HOME/.keyring-env"\nexec /usr/bin/gh.real "$@"\n' > /usr/bin/gh \
    && chmod +x /usr/bin/gh

RUN arch="$(dpkg --print-architecture | sed 's/amd64/x64/;s/arm64/arm64/')" \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${arch}-musl.tar.gz" -o /tmp/mise.tgz \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/SHASUMS256.txt" -o /tmp/SHASUMS256.txt \
    && want="$(grep "mise-${MISE_VERSION}-linux-${arch}-musl.tar.gz\$" /tmp/SHASUMS256.txt | awk '{print $1}')" \
    && echo "${want}  /tmp/mise.tgz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/mise.tgz \
    && mv /tmp/mise/bin/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise /tmp/mise.tgz /tmp/SHASUMS256.txt \
    && mise --version

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git \
      /opt/devbox-skel/.oh-my-zsh \
    && rm -rf /opt/devbox-skel/.oh-my-zsh/.git \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      /opt/devbox-skel/.oh-my-zsh-custom/themes/powerlevel10k \
    && rm -rf /opt/devbox-skel/.oh-my-zsh-custom/themes/powerlevel10k/.git \
    && chown -R ${DEV_UID}:${DEV_GID} /opt/devbox-skel

COPY --chown=${DEV_UID}:${DEV_GID} base/zshrc /opt/devbox-skel/.zshrc
COPY --chown=${DEV_UID}:${DEV_GID} base/p10k.zsh /opt/devbox-skel/.p10k.zsh

COPY --chmod=0755 base/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 base/provision.sh /usr/local/bin/provision.sh
COPY --chmod=0755 base/xclip-shim.sh /usr/local/bin/xclip
COPY --chmod=0755 base/kapsuli-info.sh /usr/local/bin/kapsuli-info
COPY --chmod=0755 base/kapsuli-sync.sh /usr/local/bin/kapsuli-sync
COPY --chmod=0755 extra-tools.sh /usr/local/bin/extra-tools.sh

RUN mkdir -p /etc/kapsuli \
    && printf '{\n  "image_version": "%s",\n  "source_commit": "%s",\n  "build_date": "%s",\n  "base_os": "ubuntu:24.04"\n}\n' \
      "${IMAGE_VERSION}" "${SOURCE_COMMIT}" "${BUILD_DATE}" > /etc/kapsuli/info.json

LABEL org.opencontainers.image.title="fenix-base" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/villekr/fenix-images" \
      org.opencontainers.image.base.name="ubuntu:24.04"

ENV KAPSULI_INFO="fenix-base ${IMAGE_VERSION} (${SOURCE_COMMIT}, built ${BUILD_DATE})"

USER ${DEV_USER}
WORKDIR ${DEV_HOME}

ENV PATH="${DEV_HOME}/.local/share/mise/shims:${DEV_HOME}/.local/bin:/usr/local/bin:${PATH}"

RUN mkdir -p ${DEV_HOME}/workspace

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD sh -c 'f="$HOME/.provisioned/status"; [ ! -f "$f" ] || grep -q "rc=0" "$f"'

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
