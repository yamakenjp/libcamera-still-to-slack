#!/bin/bash

# 設定ファイルを読み込む
source /home/pi/libcamera-still-to-slack/.slack_option

# 画像の保存先を /tmp に設定
IMAGE_PATH="/tmp/image.jpg"

# 撮影時刻をコメントに含める
COMMENT="Photo taken at $(date)!"

# 石狩の緯度と経度
LATITUDE=43.1703
LONGITUDE=141.3544

# Sunrise-Sunset APIを使用して日の出と日の入りを取得
response=$(curl -s "https://api.sunrise-sunset.org/json?lat=$LATITUDE&lng=$LONGITUDE&formatted=0")

# 日の出と日の入り時刻をJSONから抽出
sunrise=$(echo "$response" | grep -oP '"sunrise":"\K[^"]+')
sunset=$(echo "$response" | grep -oP '"sunset":"\K[^"]+')

# 日の出と日の入り時刻を日本標準時に変換
sunrise_jst=$(date -d "$sunrise" +"%Y-%m-%d %H:%M:%S")
sunset_jst=$(date -d "$sunset" +"%Y-%m-%d %H:%M:%S")

# 日の出30分前と日没30分後の時間を計算
sunrise_minus_30=$(date -d "$sunrise - 30 minutes" +"%Y-%m-%d %H:%M:%S")
sunset_plus_30=$(date -d "$sunset + 30 minutes" +"%Y-%m-%d %H:%M:%S")

# 現在の時刻を取得
current_time=$(date +"%Y-%m-%d %H:%M:%S")

# 日の出30分前から日没後30分までの間かどうかを確認
if [[ "$current_time" > "$sunrise_minus_30" ]] && [[ "$current_time" < "$sunset_plus_30" ]]; then
  echo "昼モードで撮影します（日の出30分前から日没後30分まで）"
  # rpicam-jpeg コマンドを実行
  rpicam-jpeg -n --lens-position default --hdr auto --autofocus-mode auto --autofocus-speed fast --metering average -o "$IMAGE_PATH"
else
  echo "夜モードで撮影します（日没後30分から日の出30分前まで）"
  # rpicam-jpeg コマンドを実行
  rpicam-jpeg -n --lens-position default --shutter 100000000 --hdr auto --autofocus-mode auto --autofocus-speed fast --metering average -o "$IMAGE_PATH"
fi

# Slackに画像をアップロードするAPIリクエスト
curl -F file=@"$IMAGE_PATH" \
     -F "initial_comment=$COMMENT" \
     -F "channels=$CHANNEL" \
     -H "Authorization: Bearer $TOKEN" \
     https://slack.com/api/files.upload

