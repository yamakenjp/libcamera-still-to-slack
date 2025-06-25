#!/bin/bash
# upload_image_to_slack.sh
# vim: set filetype=sh
set -euo pipefail

# --------------------------------------------------
# 設定ファイルを相対パスで読み込み
# --------------------------------------------------
source ./.slack_option

# --------------------------------------------------
# 変数定義
# --------------------------------------------------
IMAGE_PATH="/tmp/image.jpg"
COMMENT="Photo taken at $(date +'%Y-%m-%d %H:%M:%S')!"
CHANNEL="$CHANNEL"
TOKEN="$SLACK_TOKEN"
LATITUDE=43.1703
LONGITUDE=141.3544

# --------------------------------------------------
# 当日のJST日付指定で日の出・日の入りを取得
# --------------------------------------------------
LOCAL_DATE="$(date +'%Y-%m-%d')"
response=$(curl -s \
  "https://api.sunrise-sunset.org/json?lat=${LATITUDE}&lng=${LONGITUDE}&date=${LOCAL_DATE}&formatted=0")
sunrise_iso=$(echo "$response" | grep -oP '"sunrise":"\K[^"]+')
sunset_iso=$(echo "$response"  | grep -oP '"sunset":"\K[^"]+')

# UTC→JST に変換
sunrise_jst=$(date -d "$sunrise_iso" +"%Y-%m-%d %H:%M:%S")
sunset_jst=$(date -d "$sunset_iso"  +"%Y-%m-%d %H:%M:%S")

# --------------------------------------------------
# エポック秒変換（撮影ウィンドウ：日の出15分前～日の入り15分後）
# --------------------------------------------------
sunrise_minus_15_ts=$(date -d "$sunrise_jst - 15 minutes" +%s)
sunset_plus_15_ts=$(date -d "$sunset_jst + 15 minutes" +%s)
current_ts=$(date +%s)

# --------------------------------------------------
# 撮影モード判定：  
#   日の出15分前～日の入り15分後 → 昼モード  
#   それ以外                   → 夜モード  
# --------------------------------------------------
if [[ $current_ts -ge $sunrise_minus_15_ts && $current_ts -lt $sunset_plus_15_ts ]]; then
  echo "昼モードで撮影します"
  MODE=day
else
  echo "夜モードで撮影します"
  MODE=night
fi

# --------------------------------------------------
# 撮影実行
# --------------------------------------------------
if [[ $MODE == day ]]; then
  rpicam-jpeg -n \
    --lens-position default \
    --hdr auto \
    --autofocus-mode auto \
    --autofocus-speed fast \
    --metering average \
    -o "$IMAGE_PATH"
else
  rpicam-jpeg -n \
    --lens-position default \
    --shutter 100000000 \
    --hdr auto \
    --autofocus-mode auto \
    --autofocus-speed fast \
    --metering average \
    -o "$IMAGE_PATH"
fi

# --------------------------------------------------
# EXIF に撮影時刻を埋め込む（ExifTool）
# --------------------------------------------------
# 事前に `sudo apt-get install libimage-exiftool-perl` しておくこと
TIMESTAMP="$(date +'%Y:%m:%d %H:%M:%S')"
exiftool -overwrite_original \
  -DateTimeOriginal="$TIMESTAMP" \
  -CreateDate="$TIMESTAMP" \
  -ModifyDate="$TIMESTAMP" \
  "$IMAGE_PATH"

# --------------------------------------------------
# Slack への非同期アップロード処理
# --------------------------------------------------
FILE_NAME=$(basename "$IMAGE_PATH")
FILE_SIZE=$(stat -c%s "$IMAGE_PATH")

# 1. アップロード URL と file_id を取得
res_url=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  -d "filename=${FILE_NAME}" \
  -d "length=${FILE_SIZE}" \
  https://slack.com/api/files.getUploadURLExternal)
UPLOAD_URL=$(echo "$res_url" | grep -oP '"upload_url":"\K[^"]+')
FILE_ID=$(echo "$res_url"    | grep -oP '"file_id":"\K[^"]+')
ok=$(echo "$res_url"        | grep -oP '"ok":\K(true|false)')

if [[ "$ok" != "true" ]]; then
  echo "Error: files.getUploadURLExternal failed" >&2
  echo "$res_url" >&2
  exit 1
fi

# 2. ファイルをアップロード
curl -s -X POST -F "file=@${IMAGE_PATH}" "$UPLOAD_URL"

# 3. completeUploadExternal で投稿完了
res_complete=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
        "files":[{"id":"'"${FILE_ID}"'"}],
        "channels":"'"${CHANNEL}"'",
        "initial_comment":"'"${COMMENT}"'"
      }' \
  https://slack.com/api/files.completeUploadExternal)

if [[ "$(echo "$res_complete" | grep -oP '"ok":\K(true|false)')" != "true" ]]; then
  echo "Error: files.completeUploadExternal failed" >&2
  echo "$res_complete" >&2
  exit 1
fi

echo "アップロードに成功しました！ file_id: ${FILE_ID}"
