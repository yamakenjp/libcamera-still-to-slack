#!/usr/bin/env bash
set -euo pipefail

# — 設定読み込み —
source /home/pi/libcamera-still-to-slack/.slack_option

# — 定数 —
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

# — 撮影モード判定 —
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

# — 撮影＋EXIF埋め込み —
capture_image() {
  if [[ $MODE == day ]]; then
      rpicam-jpeg -n \
          --quality 95 \
          --awb daylight \
          --exposure normal \
          --hdr auto \
          --autofocus-mode auto \
          --autofocus-range full \
          --autofocus-on-capture \
          --autofocus-speed normal \
          --lens-position default \
          --denoise auto \
          --immediate \
          -o "$IMAGE_PATH"
  else
      rpicam-jpeg -n \
          --quality 95 \
          --shutter 100000000 \
          --hdr auto \
          --autofocus-mode auto \
          --autofocus-range full \
          --autofocus-on-capture \
          --autofocus-speed normal \
          --lens-position default \
          --denoise auto \
          --immediate \
  -o "$IMAGE_PATH"
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

  # 1) アップロード URL と file_id を取得
  resp=$(curl -sf -H "Authorization: Bearer ${TOKEN}" \
    -d "filename=${file_name}" -d "length=${file_size}" \
    https://slack.com/api/files.getUploadURLExternal)
  upload_url=$(echo "$resp" | jq -r '.upload_url')
  file_id=$(echo "$resp"    | jq -r '.file_id')
  ok=$(echo "$resp"         | jq -r '.ok')
  if [[ "$ok" != "true" ]]; then
    echo "Error (getUploadURLExternal): $(echo "$resp" | jq -r '.error')" >&2
    exit 1
  fi

  # 2) 本体をアップロード
  curl -sf -F "file=@${IMAGE_PATH}" "$upload_url" \
    || { echo "Error: ファイル本体のアップロードに失敗"; exit 1; }

  # 3) completeUploadExternal で共有完了
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
    echo "Error (completeUploadExternal): $(echo "$complete_resp" | jq -r '.error')" >&2
    exit 1
  fi

  # 共有リンク出力
  permalink=$(echo "$complete_resp" | jq -r '.files[0].permalink')
  echo "アップロード成功！ file_id=${file_id}"
  echo "公開リンク: ${permalink}"
}

# — メイン処理 —
get_sun_times
determine_mode
echo "${MODE}モードで撮影します"
capture_image
slack_external_upload
