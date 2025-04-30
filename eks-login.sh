#!/bin/bash
set -e

# 環境変数のチェック
if [ -z "${CLUSTER_NAME}" ] || [ -z "${REGION}" ] || [ -z "${ROLE_ARN}" ]; then
  echo "エラー: 必要な環境変数が設定されていません"
  echo "CLUSTER_NAME, REGION, ROLE_ARNを設定してください"
  exit 1
fi

# AWS認証情報をクリア
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

# AWS認証セッションのチェック
echo "1. AWS認証セッションをチェックします..."
if aws sts get-caller-identity &>/dev/null; then
  echo "既存のAWS認証セッションが有効です。ログインステップをスキップします。"
  ALREADY_LOGGED_IN=true
else
  echo "AWSにログインします..."
  aws-azure-login --no-sandbox
  ALREADY_LOGGED_IN=false
fi

# 現在の認証情報を確認
echo "2. 現在の認証情報を確認します..."
aws sts get-caller-identity

# クラスター情報の表示
echo "3. 使用するクラスター情報:"
echo "クラスター名: ${CLUSTER_NAME}"
echo "リージョン: ${REGION}"
echo "ロールARN: ${ROLE_ARN}"

# 指定されたロールに切り替え
echo "4. 指定したロールに切り替えます..."
CREDS=$(aws sts assume-role \
    --role-arn ${ROLE_ARN} \
    --role-session-name eks-operation)

# 認証情報を環境変数に設定
export AWS_ACCESS_KEY_ID=$(echo ${CREDS} | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo ${CREDS} | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo ${CREDS} | jq -r .Credentials.SessionToken)
export AWS_DEFAULT_REGION=${REGION}

# ロールの切り替えが成功したか確認
echo "5. ロールの切り替えを確認します..."
aws sts get-caller-identity

# kubectlの設定を初期化
echo "6. kubectl設定を初期化します..."
rm -f /root/.kube/config || true
mkdir -p /root/.kube

# AWS EKS update-kubeconfigを実行し、明示的に--insecure-skip-tls-verifyフラグを含める設定を準備
echo "7. AWS EKS update-kubeconfigを実行します..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} \
  --region ${REGION} \
  --alias ${CLUSTER_NAME}

# kubeconfigの内容を表示
echo "8. 生成されたkubeconfigを表示します..."
cat /root/.kube/config | grep -v secret | grep -v token

# kubeconfigにinsecure-skip-tls-verifyを設定
echo "9. kubeconfigにinsecure-skip-tls-verifyを設定します..."
kubectl config set-cluster ${CLUSTER_NAME} --insecure-skip-tls-verify=true

echo "10. AWS認証情報を確認します..."
env | grep AWS_ | grep -v SECRET | grep -v SESSION
