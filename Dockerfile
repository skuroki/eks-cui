# ベースイメージに Ubuntu 22.04 を使用
FROM ubuntu:22.04

# 非対話モード＆日本語ロケール設定
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    AWS_AZURE_LOGIN_MODE=cli \
    AWS_AZURE_LOGIN_NO_PROMPT=true \
    AWS_AZURE_LOGIN_NO_SANDBOX=true \
    DISPLAY="" \
    PUPPETEER_SKIP_DOWNLOAD=false

# 基本パッケージのインストール
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg wget less && \
    mkdir -p /etc/apt/keyrings

# NodeJSのrepositoryを追加
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# Google Chromeのリポジトリを追加
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list

# 必要パッケージのインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      nodejs \
      curl \
      unzip \
      jq \
      ca-certificates \
      gnupg \
      lsb-release \
      locales \
      google-chrome-stable \
      libx11-xcb1 \
      libxcomposite1 \
      libxcursor1 \
      libxdamage1 \
      libxext6 \
      libxi6 \
      libxtst6 \
      libnss3 \
      libcups2 \
      libxss1 \
      libxrandr2 \
      libasound2 \
      libatk1.0-0 \
      libatk-bridge2.0-0 \
      libpangocairo-1.0-0 \
      libgtk-3-0 \
      libgbm1 && \
    locale-gen ja_JP.UTF-8 && \
    npm install -g aws-azure-login@1.2.0 && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2 のインストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
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

# eksctl のインストール
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/v0.171.0/eksctl_Linux_amd64.tar.gz" \
    | tar xz -C /usr/local/bin

# 作業ディレクトリ
WORKDIR /workspace
