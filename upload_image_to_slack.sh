# upload_image_to_slack.sh
#!/bin/bash
# vim: set filetype=sh
set -euo pipefail

# --------------------------------------------------
# 設定ファイルを読み込む（SLACK_TOKEN, CHANNEL などを定義）
# --------------------------------------------------
source /home/pi/libcamera-still-to-slack/.slack_option

# --------------------------------------------------
# 変数定義
# --------------------------------------------------
IMAGE_PATH="/tmp/image.jpg"
COMMENT="Photo taken at $(date +'%Y-%m-%d %H:%M:%S')!"
CHANNEL="$CHANNEL"
TOKEN="$SLACK_TOKEN"

# 撮影地：石狩市
LATITUDE=43.1703
LONGITUDE=141.3544

# --------------------------------------------------
# Sunrise-Sunset API を呼び出し、日の出・日の入りを取得
# --------------------------------------------------
response=$(curl -s "https://api.sunrise-sunset.org/json?lat=${LATITUDE}&lng=${LONGITUDE}&formatted=0")
sunrise=$(echo "$response" | grep -oP '"sunrise":"\K[^"]+')
sunset=$(echo "$response"  | grep -oP '"sunset":"\K[^"]+')

# UTC→JST に変換
sunrise_jst=$(date -d "$sunrise" +"%Y-%m-%d %H:%M:%S")
sunset_jst=$(date -d "$sunset"  +"%Y-%m-%d %H:%M:%S")

# --------------------------------------------------
# エポック秒に変換および9:00判定
# --------------------------------------------------
sunrise_ts=$(date --date="$sunrise_jst" +%s)
sunset_ts=$(date --date="$sunset_jst"  +%s)
sunrise_minus_15_ts=$(date --date="$sunrise_jst - 15 minutes" +%s)
sunset_plus_15_ts=$(date --date="$sunset_jst + 15 minutes" +%s)
nine_am_ts=$(date --date "$(date +'%Y-%m-%d') 09:00:00" +%s)
current_ts=$(date +%s)

# --------------------------------------------------
# 撮影モード判定および撮影
#  → 日の出〜9:00 は必ず昼モード
#    それ以外は日の出15分前〜日の入り15分後を昼モードとする
# --------------------------------------------------
if \
   [[ $current_ts -ge $sunrise_ts           && $current_ts -lt $nine_am_ts       ]] \
|| [[ $current_ts -ge $sunrise_minus_15_ts  && $current_ts -lt $sunset_plus_15_ts ]]; then
  echo "昼モードで撮影します"
  rpicam-jpeg -n \
    --lens-position default \
    --hdr auto \
    --autofocus-mode auto \
    --autofocus-speed fast \
    --metering average \
    -o "$IMAGE_PATH"
else
  echo "夜モードで撮影します"
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
# Slack 非同期アップロード処理
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

# 2. アップロード URL へファイルを送信
curl -s -X POST \
  -F "file=@${IMAGE_PATH}" \
  "$UPLOAD_URL"

# 3. completeUploadExternal でアップロード完了とチャンネル投稿
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
