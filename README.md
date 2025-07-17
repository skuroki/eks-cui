このコンテナの目的は、ホスト機に依存すること無くEKSへのkubectlコマンド実行ができることである
実行時には、今登録したログイン時のロールから、本番作業用のロールに切り替えて行う想定である

## 対応環境

このツールは以下の環境で動作します：
- Intel MacBook (x86_64)
- Apple Silicon MacBook (M1/M2/M3/M4) - ARM64ネイティブ対応

Apple Silicon環境では、seleniarmベースのDockerイメージを使用してChromiumが最適化されています。

## 初期設定

### Docker Composeのビルド

```
docker compose build
```

### 環境変数の設定

`.env.sample` をコピーして `.env` ファイルを作成し、必要な環境変数を設定します：

```
cp .env.sample .env
```

`.env` ファイルを編集して、以下の環境変数を設定します：

- `CLUSTER_NAME`: 対象のEKSクラスター名（例：Production）
- `REGION`: AWSリージョン（例：ap-northeast-1）
- `ROLE_ARN`: 使用するIAMロールのARN（例：arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME）

### AWS認証設定

初回使用時には、AWS Azure Loginの設定が必要です：

```
docker compose run --rm eks-cui aws-azure-login --configure
```

## 使用手順

### 1. AWS認証とEKSコンテキスト設定（eks-login.sh使用）

以下のコマンドでAWS認証からEKSコンテキスト設定まで一括で実行できます。

```
docker compose run --rm eks-cui ./eks-login.sh
```

このスクリプトは以下を自動的に実行します：
- AWS認証セッションのチェック（必要な場合はログイン）
- ロールの切り替え
- 指定クラスターのkubeconfig設定
- TLS検証スキップ設定

### 2. kubectlコマンドの実行

認証後、以下のようにkubectlコマンドを実行できます：

```
docker compose run --rm eks-cui kubectl get pods
docker compose run --rm eks-cui kubectl get nodes
docker compose run --rm eks-cui kubectl get deployments
```
