#!/bin/bash

# 設定ファイルを読み込む
source .slack_option
source .libcamera_options

# libcamera_optionsを読み込む
LIBCAMERA_OPTIONS=()
while IFS= read -r line; do
    # コメント行を無視
    [[ $line == \#* ]] && continue
    LIBCAMERA_OPTIONS+=("$line")  # オプションを配列に追加
done < .libcamera_options

# 画像の保存先を /tmp に設定
IMAGE_PATH="/tmp/image.jpg"

# 撮影時刻をコメントに含める
COMMENT="Photo taken at $(date)!"

# 画像を撮影し、.libcamera_optionsに指定されたオプションを使って /tmp/image.jpg に保存
libcamera-still -o "$IMAGE_PATH" "${LIBCAMERA_OPTIONS[@]}"

# Slackに画像をアップロードするAPIリクエスト
curl -F file=@"$IMAGE_PATH" \
     -F "initial_comment=$COMMENT" \
     -F "channels=$CHANNEL" \
     -H "Authorization: Bearer $TOKEN" \
     https://slack.com/api/files.upload

