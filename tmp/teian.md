ロゼッタ絡みの `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2` は、**コンテナ内で起動しようとしている Chrome/Chromium バイナリと実行環境（コンテナのアーキテクチャ／エミュレーション設定）が不整合**であることを示唆します。Apple Silicon (M4) ホスト上で linux/amd64 イメージを走らせ、その中で x86\_64 Chrome を起動しようとしている／あるいは Puppeteer が誤ったバイナリを拾っているケースでよく出ます。arm64 ネイティブ Chromium を入れて Puppeteer（＝aws-azure-login が内部利用）にそのパスを教えることで解決できる可能性が高いです。([omahoco][1], [Zenn][2])

以下、\*\*推奨ルート（ネイティブ arm64 コンテナで Chromium を明示）\*\*と、代替策（amd64 エミュレート継続、Puppeteer パス変更、GUIを捨てる等）を順に示します。

---

## なぜ起きる？

* `aws-azure-login` は内部で **Puppeteer を使って Chromium/Chrome を自動操作**し、Azure AD のログイン（含 MFA）をブラウザ経由で完了して AWS 一時クレデンシャルを取得します。([omahoco][1], [GitHub][3])
* Puppeteer はアーキテクチャを見て自前で Chromium をダウンロード／パス推定しますが、**ARM 環境で適切なバイナリが見つからないと失敗**したり、誤って x86\_64 用を拾って Rosetta/QEMU 越しに実行しようとしてコケることがあります。([omahoco][1], [Zenn][2])
* Apple Silicon 上の Docker で Puppeteer/Chromium を動かす際、\*\*プラットフォーム指定やバイナリ取得方法を誤るとロゼッタ関連の起動失敗（今回のエラー）\*\*が頻発することが報告されています。([Zenn][2], [Stack Overflow][4])

---

## 推奨解法（A案）：arm64 ネイティブ Docker イメージで Chromium をインストールし、Puppeteer にパスを渡す

### 方針

1. Docker ビルドを **`linux/arm64`**（M4 ネイティブ）で行う。
2. ベース OS のパッケージマネージャで **arm64 版 Chromium** をインストール。
3. Puppeteer が勝手に別アーキの Chromium を落とさないよう `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true`。
4. Puppeteer（=aws-azure-login）へ実バイナリ位置を `PUPPETEER_EXECUTABLE_PATH` で通知。
5. コンテナ内で `aws-azure-login` を npm グローバルインストール。
6. 実行時に Chrome フラグ（`--no-sandbox` 等）を必要に応じ付加。

この「Chromiumを手動インストールし Puppeteer にパスを明示」「自動ダウンロードを抑止」という流れが Apple Silicon 環境での既知のワークアラウンドです。([omahoco][1], [Zenn][2])

### サンプル Dockerfile（Debian bookworm slim の例）

```dockerfile
# Apple Silicon (M1/M2/M3/M4) でネイティブ arm64 ビルド
FROM --platform=linux/arm64 node:20-bookworm-slim

# Puppeteer が変なバイナリを落とさないように先に環境変数を定義
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 依存パッケージと Chromium をインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      chromium \
      ca-certificates \
      fonts-liberation \
      libatk-bridge2.0-0 \
      libnss3 \
      libxss1 \
      libasound2 \
      libxshmfence1 \
      && rm -rf /var/lib/apt/lists/*

# aws-azure-login をグローバルインストール
RUN npm install -g aws-azure-login --unsafe-perm

# 実行ラッパ（必要に応じて Chrome 起動オプションを追加）
ENTRYPOINT ["aws-azure-login"]
```

> メモ: ディストリによって Chromium のパッケージ名やインストールパス（`/usr/bin/chromium` vs `/usr/bin/chromium-browser`）が変わるので `which chromium*` で確認してください。Apple Silicon で Homebrew 経由インストール時のパス差異を修正する必要があった実例があります。([omahoco][1])

> もし Puppeteer が依然として誤検出する場合、Puppeteer の実装内で ARM 時のデフォルトパスを書き換えて回避した報告もあります（強引な手段・アップデート時再発注意）。([omahoco][1])

### 実行例

ホストの AWS 設定ディレクトリをマウントして利用（公式 README の Docker 例を参考）。([GitHub][3])

```
docker run --rm -it \
  -v $HOME/.aws:/root/.aws \
  my-aws-azure-login-image \
  --profile yourprofile --mode gui
```

---

## 補足フラグ（Chrome起動時）

コンテナ内 Chromium はサンドボックスや共有メモリ領域で問題を起こすことがあります。その場合は Puppeteer の launch オプションに以下を追加するのが定石です（必要な場合のみ）。※aws-azure-login 側で追加引数を渡す方法はバージョンによって異なるので実行ログを確認してください。([Zenn][2])

* `--no-sandbox`
* `--disable-setuid-sandbox`
* `--disable-dev-shm-usage`
* `--headless=new`（最新 headless 実装を強制／環境依存）

---

## 代替策

### B案：amd64 コンテナを維持し Rosetta で動かす（非推奨・性能/安定性注意）

Apple Silicon 上で `--platform=linux/amd64` を指定して Docker イメージをビルドし、Docker Desktop の **「Use Rosetta」オプションを有効化**して x86\_64 Chromium をそのまま使う手もあります。ただしエミュレーション負荷が高く、今回のような起動失敗要因になりやすいので、基本はネイティブ arm64 へ移行を推奨します。([Stack Overflow][4])

### C案：ホスト側 Chromium/Chrome を利用（Puppeteer にリモート接続）

Puppeteer は `executablePath` の代わりに既存ブラウザの DevTools プロトコルエンドポイントへ接続するモードをサポートします。ホスト上で正しく動く Chrome を開き、`--remote-debugging-port=9222` で待機させ、コンテナから `wsEndpoint` で接続すればアーキ不整合問題を回避できます（パス差異で困った例からの派生ワークアラウンド）。([omahoco][1], [Zenn][2])

### D案：ブラウザ自動操作をやめて CLI/手動モード

`aws-azure-login` はブラウザ自動操作以外のモード（CLI / デバイスコード等）でのログインをサポートしており、GUI ブラウズが難しい環境ではそちらに切り替えてトークン取得のみ行う運用も可能です。([GitHub][3])

---

## 次に教えてほしいこと

まだ完全な環境情報をいただいていないので、下記を差し支えない範囲で教えてください。適切な Dockerfile & 実行コマンドを一緒に詰めましょう。

1. **コンテナの現在のアーキテクチャ**（`docker inspect <image> | grep Architecture` or コンテナ内 `uname -m`）。
2. **ベースイメージ名**。
3. **Chromium のインストール方法／パス**（未インストールならなしで可）。
4. `aws-azure-login` 実行コマンド（引数含む）と `--mode`。
5. セキュリティポリシー的に `--no-sandbox` は許容できますか？

これらがわかれば、あなたの既存 Dockerfile に最小限の修正パッチを出します。

---

### トラブルシュートのミニチェックリスト

* [ ] コンテナを `linux/arm64` で再ビルドしたか？（`docker buildx build --platform=linux/arm64`）
* [ ] `chromium --version` がコンテナ内で実行できるか。
* [ ] `node -e "console.log(process.arch)"` が `arm64` を返すか。
* [ ] `env | grep PUPPETEER` でパス・スキップ設定が反映されているか。
* [ ] `aws-azure-login --mode gui --no-sandbox`（オプション名は実際に `--help` で確認）で試行。

---

必要情報をいただければ、実際に動く最小再現リポ構成（Dockerfile＋runコマンド）を提示いたします。よろしくお願いします。

[1]: https://omahony.id.au/installing-aws-azure-login-on-apple-m1/ "Installing aws-azure-login on Apple M1"
[2]: https://zenn.dev/frog/articles/24a20e8a2811b5 "Apple Silicon(M2)上のDockerでPuppeteer(Chromium)をHeadlessモードで動かす"
[3]: https://github.com/aws-azure-login/aws-azure-login "GitHub - aws-azure-login/aws-azure-login: Use Azure AD SSO to log into the AWS via CLI."
[4]: https://stackoverflow.com/questions/71452265/how-to-run-puppeteer-on-a-docker-container-on-a-macos-apple-silicon-m1-arm64-hos?utm_source=chatgpt.com "How to run Puppeteer on a Docker container on a MacOS Apple ..."
