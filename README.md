# libcamera-still-to-slack

このプロジェクトは、Raspberry Piカメラを使って画像を撮影し、その画像をSlackに投稿するためのスクリプトです。

## 必要な環境

- Raspberry Pi
- libcamera
- curl

## ファイル構成
- `.slack_option`: Slack APIトークンとチャンネルIDを設定するファイル
- `upload_image_to_slack.sh`: 画像を撮影し、Slackにアップロードするシェルスクリプト

## セットアップ手順

1. **リポジトリをクローンします**。
    ```bash
    git clone https://github.com/yamakenjp/libcamera-still-to-slack.git
    cd libcamera-still-to-slack
    ```

2. **サンプル設定ファイルをコピーします**。
    ```bash
    cp .slack_option.sample .slack_option
    ```

3. **`.slack_option`ファイルにSlackのトークンとチャンネルIDを設定します**。
   ```bash
   # .slack_option
   TOKEN="xoxb-xxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx"
   CHANNEL="C1234567890"
   ```

4. **`upload_image_to_slack.sh`ファイルに緯度経度やlibcameraのオプションを設定します。**。

   ```
5. スクリプトを実行します。

```bash
./upload_image_to_slack.sh
```
