FROM debian:bullseye-slim

RUN set -eux; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            jq \
            git \
            curl \
            ca-certificates \
        ; \
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
            dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg; \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
            tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
        apt update && \
        apt install -y --no-install-recommends gh ; \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
