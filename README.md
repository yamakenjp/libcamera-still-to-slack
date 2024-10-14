# libcamera-still-to-slack

このプロジェクトは、Raspberry Piカメラを使って画像を撮影し、その画像をSlackに投稿するためのスクリプトです。

## 必要な環境

- Raspberry Pi
- libcamera
- curl

## ファイル構成
- `.slack_option`: Slack APIトークンとチャンネルIDを設定するファイル
- `.libcamera_options`: libcamera-stillのオプションを設定するファイル
- `upload_image_to_slack.sh`: 画像を撮影し、Slackにアップロードするシェルスクリプト

## セットアップ手順

1. **リポジトリをクローンします**。
    ```bash
    git clone https://github.com/yamakenjp/rpicam-still-to-slack.git
    cd rpicam-still-to-slack
    ```

2. **サンプル設定ファイルをコピーします**。
    ```bash
    cp .slack_option.sample .slack_option
    cp .libcamera_options.sample .libcamera_options
    ```

3. **`.slack_option`ファイルにSlackのトークンとチャンネルIDを設定します**。
   ```bash
   # .slack_option
   TOKEN="xoxb-xxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx"
   CHANNEL="C1234567890"
   ```

4. **`.libcamera_options`ファイルにlibcamera-stillのオプションを設定します。**。
   ```bash
   # ~/.libcamera_options

   # 画像の幅を設定
   --width 4056

   # 画像の高さを設定
   --height 3040

   # 画像を180度回転
   --rotation 180

   # シャープネスを強調（0.0 - 1.0の範囲）
   --sharpness 1.0

   # 明るさを調整（0.0 - 1.0の範囲）
   --brightness 0.5

   # コントラストを調整（0.0 - 1.0の範囲）
   --contrast 1.0

   # ゲイン（感度）の設定（通常は1.0）
   --gain 1.0

   # 彩度を調整（0.0 - 1.0の範囲）
   --saturation 1.0

   # 露出補正を設定（-2.0から2.0の範囲）
   --ev 0

   # 撮影のタイムアウトを設定（ミリ秒単位）
   --timeout 1000

   # HDR（高ダイナミックレンジ）を有効にする
   --hdr

   # メタデータを含める
   --metadata
   ```
5. スクリプトを実行します。

```bash
./upload_image_to_slack.sh
```
