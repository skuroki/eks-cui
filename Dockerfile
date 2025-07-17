# seleniarmイメージを使用（ARM64ネイティブ、Chrome最適化済み）
FROM seleniarm/standalone-chromium:latest

# 非対話モード＆日本語ロケール設定
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    AWS_AZURE_LOGIN_MODE=cli \
    AWS_AZURE_LOGIN_NO_PROMPT=true \
    AWS_AZURE_LOGIN_NO_SANDBOX=true \
    DISPLAY=:99 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222"

# rootユーザーに切り替え（seleniarmイメージはselenuserがデフォルト）
USER root

# NodeJSのrepositoryを追加とパッケージインストール
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg wget less && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# 必要パッケージのインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      nodejs \
      curl \
      unzip \
      jq \
      locales && \
    locale-gen ja_JP.UTF-8 && \
    npm install -g aws-azure-login@1.2.0 && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2 のインストール（ARM64版）
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip && \
    cd /tmp && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# kubectl のインストール
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl && \
    rm -rf /var/lib/apt/lists/*

# helm のインストール
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# eksctl のインストール（ARM64版）
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.171.0/eksctl_Linux_arm64.tar.gz" \
    | tar xz -C /usr/local/bin

# Xvfb起動スクリプトを作成
RUN echo '#!/bin/bash\nXvfb :99 -screen 0 1920x1080x24 &\nexport DISPLAY=:99\nexec "$@"' > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# 作業ディレクトリ
WORKDIR /workspace

# エントリーポイント設定
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
