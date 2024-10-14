#!/bin/bash

# 必要な情報を変数に設定
TOKEN="xoxb-xxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx"
CHANNEL="C1234567890"  # チャンネルID
IMAGE_PATH="/tmp/image.jpg"  # 画像の保存先を /tmp に設定
COMMENT="Photo taken at $(date)!"  # 撮影時刻をコメントに含める

# 画像を撮影（画像の保存先は /tmp/image.jpg）
libcamera-still -o /tmp/image.jpg \
                --width 4056 --height 3040 \  # 最大解像度（12MP）
                --rotation 180 \              # 必要に応じて回転
                --sharpness 1.0 \             # シャープネスの強調
                --brightness 0.5 \            # 明るさ調整
                --contrast 1.0 \              # コントラスト調整
                --gain 1.0 \                  # ゲイン（感度）
                --saturation 1.0 \            # 彩度調整
                --ev 0 \                      # 露出補正
                --timeout 1000 \              # タイムアウト
                --hdr \                       # HDRを有効にする
                --metadata                    # メタデータを含める

# Slackに画像をアップロードするAPIリクエスト
curl -F file=@"$IMAGE_PATH" \
     -F "initial_comment=$COMMENT" \
     -F "channels=$CHANNEL" \
     -H "Authorization: Bearer $TOKEN" \
     https://slack.com/api/files.upload

