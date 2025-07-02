#!/usr/bin/env bash
set -xeuo pipefail

# 設定読み込み
# vim: set filetype=sh
source /home/pi/libcamera-still-to-slack/.slack_option

IMAGE_PATH="/tmp/image.jpg"
COMMENT="Photo taken at $(date +'%Y-%m-%d %H:%M:%S')!"
CHANNEL_ID="$CHANNEL"
TOKEN="$SLACK_TOKEN"

# — 日の出・日の入り取得＆JST変換 —
get_sun_times() {
  local date_iso lat lon resp
  date_iso=$(date +'%Y-%m-%d')
  lat=$LATITUDE; lon=$LONGITUDE
  resp=$(curl -sf \
    "https://api.sunrise-sunset.org/json?lat=${lat}&lng=${lon}&date=${date_iso}&formatted=0")
  sunrise_iso=$(echo "$resp" | jq -r '.results.sunrise')
  sunset_iso=$(echo "$resp" | jq -r '.results.sunset')
  sunrise_jst=$(date -d "$sunrise_iso" +'%s')
  sunset_jst=$(date -d "$sunset_iso"  +'%s')
}

# — 撮影モード判定（日の出15分前 ～ 日の入り15分後を昼モードとする） —
determine_mode() {
  local now_ts pre_ts post_ts
  now_ts=$(date +%s)
  pre_ts=$(( sunrise_jst - 15*60 ))
  post_ts=$(( sunset_jst  + 15*60 ))
  if (( now_ts >= pre_ts && now_ts < post_ts )); then
    MODE=day
  else
    MODE=night
  fi
}

# — 画像撮影＆EXIF埋め込み —
capture_image() {
  if [[ $MODE == day ]]; then
    rpicam-jpeg -n --lens-position default --hdr auto \
      --autofocus-mode auto --autofocus-speed fast \
      --metering average -o "$IMAGE_PATH"
  else
    rpicam-jpeg -n --lens-position default --shutter 100000000 \
      --hdr auto --autofocus-mode auto --autofocus-speed fast \
      --metering average -o "$IMAGE_PATH"
  fi

  TIMESTAMP=$(date +'%Y:%m:%d %H:%M:%S')
  exiftool -overwrite_original \
    -DateTimeOriginal="$TIMESTAMP" \
    -CreateDate="$TIMESTAMP" \
    -ModifyDate="$TIMESTAMP" \
    "$IMAGE_PATH" >/dev/null
}

# — Slack 外部アップロード処理 —
slack_external_upload() {
  local file_name file_size resp upload_url file_id complete_resp ok

  file_name=$(basename "$IMAGE_PATH")
  file_size=$(stat -c%s "$IMAGE_PATH")

  # 1) getUploadURLExternal で URL と file_id を取得
  resp=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    -d "filename=${file_name}" -d "length=${file_size}" \
    https://slack.com/api/files.getUploadURLExternal)
  upload_url=$(echo "$resp" | jq -r '.upload_url')
  file_id=$(echo "$resp"    | jq -r '.file_id')
  ok=$(echo "$resp"         | jq -r '.ok')

  if [[ "$ok" != "true" ]]; then
    echo "Error in getUploadURLExternal: $(echo "$resp" | jq -r '.error')" >&2
    exit 1
  fi

  # 2) 取得した URL にファイルを POST
  curl -sf -F "file=@${IMAGE_PATH}" "$upload_url"

  # 3) completeUploadExternal でチャンネルへ共有
  complete_resp=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
          "files":[{"id":"'"${file_id}"'"}],
          "channel_id":"'"${CHANNEL_ID}"'",
          "initial_comment":"'"${COMMENT}"'"
        }' \
    https://slack.com/api/files.completeUploadExternal)
  ok=$(echo "$complete_resp" | jq -r '.ok')

  if [[ "$ok" != "true" ]]; then
    echo "Error in completeUploadExternal: $(echo "$complete_resp" | jq -r '.error')" >&2
    exit 1
  fi

  # 共有後のパーマリンクを出力
  permalink=$(echo "$complete_resp" | jq -r '.files[0].permalink')
  echo "アップロードに成功しました！ file_id: ${file_id}"
  echo "Slack での公開リンク: ${permalink}"
}

# — メイン処理 —
get_sun_times
determine_mode
echo "${MODE}モードで撮影します"
capture_image
slack_external_upload
