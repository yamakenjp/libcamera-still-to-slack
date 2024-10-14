#!/bin/bash

# 必要な情報を変数に設定
TOKEN="xoxb-xxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx"
CHANNEL="C1234567890"  # チャンネルID
IMAGE_PATH="/tmp/image.jpg"  # 画像の保存先を /tmp に設定
COMMENT="Photo taken at $(date)!"  # 撮影時刻をコメントに含める

# 画像を撮影（画像の保存先は /tmp/image.jpg）
raspistill -o "$IMAGE_PATH" \
           -w 4056 -h 3040 \
           -hf -vf \
           -ex auto \
           -awb auto \
           -q 100 \
           -sh 40 \
           -br 60 \
           -co 10 \
           -ISO 100 \
           -drc high \
           -a 12 -a "Photo taken at %Y-%m-%d %X" \
           -sa 0

# Slackに画像をアップロードするAPIリクエスト
curl -F file=@"$IMAGE_PATH" \
     -F "initial_comment=$COMMENT" \
     -F "channels=$CHANNEL" \
     -H "Authorization: Bearer $TOKEN" \
     https://slack.com/api/files.upload

