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
# API で日の出・日の入りを取得（JSTローカル日付を明示）
# --------------------------------------------------
LOCAL_DATE="$(date +'%Y-%m-%d')"
response=$(curl -s "https://api.sunrise-sunset.org/json?lat=${LATITUDE}&lng=${LONGITUDE}&date=${LOCAL_DATE}&formatted=0")
sunrise_iso=$(echo "$response" | grep -oP '"sunrise":"\K[^"]+')
sunset_iso=$(echo "$response"  | grep -oP '"sunset":"\K[^"]+')

# UTC→JST に変換
sunrise_jst=$(date -d "$sunrise_iso" +"%Y-%m-%d %H:%M:%S")
sunset_jst=$(date -d "$sunset_iso"  +"%Y-%m-%d %H:%M:%S")

# --------------------------------------------------
# エポック秒に変換および9:00判定
# --------------------------------------------------
sunrise_ts=$(date -d "$sunrise_jst" +%s)
sunset_ts=$(date -d "$sunset_jst"  +%s)
sunrise_minus_15_ts=$(date -d "$sunrise_jst - 15 minutes" +%s)
sunset_plus_15_ts=$(date -d "$sunset_jst + 15 minutes" +%s)
nine_am_ts=$(date -d "${LOCAL_DATE} 09:00:00" +%s)
current_ts=$(date +%s)

# --------------------------------------------------
# 撮影モード判定
#  1) 日の出前 → 夜モード
#  2) 日の出～9:00 → 昼モード
#  3) 日の出15分前～日の入り15分後 → 昼モード
#  4) その他 → 夜モード
# --------------------------------------------------
if   [[ $current_ts -lt $sunrise_ts ]]; then
  echo "夜モードで撮影します（まだ日の出前）"
  MODE=night
elif [[ $current_ts -lt $nine_am_ts ]]; then
  echo "昼モードで撮影します（日の出～9:00）"
  MODE=day
elif [[ $current_ts -ge $sunrise_minus_15_ts && $current_ts -lt $sunset_plus_15_ts ]]; then
  echo "昼モードで撮影します（標準ウィンドウ内）"
  MODE=day
else
  echo "夜モードで撮影します（標準ウィンドウ外）"
  MODE=night
fi

# --------------------------------------------------
# 撮影コマンド実行
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
# Slack 非同期アップロード処理
# --------------------------------------------------
FILE_NAME=$(basename "$IMAGE_PATH")
FILE_SIZE=$(stat -c%s "$IMAGE_PATH")

# 1. ファイルアップロード URL と file_id を取得
res_url=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  -d "filename=${FILE_NAME}" \
  -d "length=${FILE_SIZE}" \
  https://slack.com/api/files.getUploadURLExternal)
UPLOAD_URL=$(echo "$res_url" | grep -oP '"upload_url":"\K[^"]+')
FILE_ID=$(echo "$res_url"    | grep -oP '"file_id":"\K[^"]+')
ok=$(echo "$res_url"        | grep -oP '"ok":\K(true|false)')

[[ "$ok" == "true" ]] || { echo "Error during getUploadURLExternal"; echo "$res_url"; exit 1; }

# 2. 取得した URL へファイル送信
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
  echo "Error during completeUploadExternal"
  echo "$res_complete"
  exit 1
fi

echo "アップロードに成功しました！ file_id: ${FILE_ID}"
