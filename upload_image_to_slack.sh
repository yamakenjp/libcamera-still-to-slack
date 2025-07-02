#!/bin/bash
# upload_image_to_slack.sh
# vim: set filetype=sh
set -euo pipefail

# --------------------------------------------------
# 設定ファイルを絶対パスで読み込み
# （ここに CHANNEL, SLACK_TOKEN, LATITUDE, LONGITUDE を定義）
# --------------------------------------------------
source /home/pi/libcamera-still-to-slack/.slack_option

# --------------------------------------------------
# 定数定義
# --------------------------------------------------
IMAGE_PATH="/tmp/image.jpg"
COMMENT="Photo taken at $(date +'%Y-%m-%d %H:%M:%S')!"
CHANNEL_ID="$CHANNEL"
TOKEN="$SLACK_TOKEN"

# --------------------------------------------------
# 日の出・日の入り取得＆JST変換関数
# --------------------------------------------------
get_sun_times() {
  local date_iso lat lon resp
  date_iso=$(date +'%Y-%m-%d')
  lat=$LATITUDE; lon=$LONGITUDE
  resp=$(curl -sf "https://api.sunrise-sunset.org/json?lat=${lat}&lng=${lon}&date=${date_iso}&formatted=0")
  sunrise_iso=$(echo "$resp" | jq -r '.results.sunrise')
  sunset_iso =$(echo "$resp" | jq -r '.results.sunset')
  sunrise_jst=$(date -d "$sunrise_iso" +'%s')
  sunset_jst=$(date -d "$sunset_iso"  +'%s')
}

# --------------------------------------------------
# 撮影モード判定関数（日の出15分前～日の入り15分後を昼モードとする）
# --------------------------------------------------
determine_mode() {
  local now_ts pre_ts post_ts
  now_ts=$(date +%s)
  pre_ts=$(( sunrise_jst - 15*60 ))
  post_ts=$(( sunset_jst + 15*60 ))
  if (( now_ts >= pre_ts && now_ts < post_ts )); then
    MODE=day
  else
    MODE=night
  fi
}

# --------------------------------------------------
# 画像撮影関数
# --------------------------------------------------
capture_image() {
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

  # EXIF埋め込み
  TIMESTAMP=$(date +'%Y:%m:%d %H:%M:%S')
  exiftool -overwrite_original \
    -DateTimeOriginal="$TIMESTAMP" \
    -CreateDate="$TIMESTAMP" \
    -ModifyDate="$TIMESTAMP" \
    "$IMAGE_PATH" >/dev/null
}

# --------------------------------------------------
# Slack 外部アップロード関数
# 1) getUploadURLExternal
# 2) ファイル本体をアップロード
# 3) completeUploadExternal
# --------------------------------------------------
slack_external_upload() {
  local file_name file_size resp upload_url file_id complete_resp err

  file_name=$(basename "$IMAGE_PATH")
  file_size=$(stat -c%s "$IMAGE_PATH")

  # 1. アップロード URL と file_id を取得
  resp=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    -d "filename=${file_name}" \
    -d "length=${file_size}" \
    https://slack.com/api/files.getUploadURLExternal)

  upload_url=$(echo "$resp" | jq -r '.upload_url')
  file_id=$(echo "$resp"    | jq -r '.file_id')
  ok=$(echo "$resp"         | jq -r '.ok')

  if [[ "$ok" != "true" ]]; then
    echo "Error in getUploadURLExternal: $(echo "$resp" | jq -r '.error')" >&2
    exit 1
  fi

  # 2. 取得した URL へファイルを POST
  curl -sf -F "file=@${IMAGE_PATH}" "$upload_url"

  # 3. completeUploadExternal で投稿完了
  complete_resp=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
          "files":[{"id":"'"${file_id}"'"}],
          "channels":"'"${CHANNEL_ID}"'",
          "initial_comment":"'"${COMMENT}"'"
        }' \
    https://slack.com/api/files.completeUploadExternal)

  ok=$(echo "$complete_resp" | jq -r '.ok')
  if [[ "$ok" != "true" ]]; then
    echo "Error in completeUploadExternal: $(echo "$complete_resp" | jq -r '.error')" >&2
    exit 1
  fi

  echo "アップロードに成功しました！ file_id: ${file_id}"
}

# --------------------------------------------------
# メイン処理
# --------------------------------------------------
get_sun_times
determine_mode
echo "${MODE}モードで撮影します"
capture_image
slack_external_upload
