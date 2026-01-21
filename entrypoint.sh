#!/bin/sh

set -eu

# Telegram Bot API endpoint
TELEGRAM_API="https://api.telegram.org/bot${INPUT_TOKEN}"

# Default values
PARSE_MODE="${INPUT_FORMAT:-}"
DISABLE_WEB_PAGE_PREVIEW="${INPUT_DISABLE_WEB_PAGE_PREVIEW:-false}"
DISABLE_NOTIFICATION="${INPUT_DISABLE_NOTIFICATION:-false}"

# Build message content
if [ -n "${INPUT_MESSAGE_FILE:-}" ] && [ -f "${INPUT_MESSAGE_FILE}" ]; then
  MESSAGE=$(cat "${INPUT_MESSAGE_FILE}")
elif [ -n "${INPUT_MESSAGE:-}" ]; then
  MESSAGE="${INPUT_MESSAGE}"
else
  # Default message for GitHub Actions
  MESSAGE="🔔 *GitHub Actions*

📦 Repository: \`${GITHUB_REPOSITORY:-unknown}\`
🔀 Event: \`${GITHUB_EVENT_NAME:-unknown}\`
👤 Actor: \`${GITHUB_ACTOR:-unknown}\`
🔗 [View Workflow](${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-})"
fi

# Trim leading/trailing spaces
trim_spaces() {
  value="$1"

  while [ "${value# }" != "$value" ]; do
    value="${value# }"
  done

  while [ "${value% }" != "$value" ]; do
    value="${value% }"
  done

  printf '%s' "$value"
}

# Normalize comma/newline-separated lists
normalize_list() {
  local value="$1"
  local item
  local old_ifs="$IFS"

  IFS='
'
  for item in $(printf '%s' "$value" | tr ',' '\n'); do
    item=$(trim_spaces "$item")
    if [ -n "$item" ]; then
      printf '%s\n' "$item"
    fi
  done

  IFS="$old_ifs"
}

# Function to send text message
send_message() {
  local chat_id="$1"
  local message="$2"
  local thread_id="${3:-}"
  
  # Build JSON payload
  JSON_PAYLOAD=$(cat <<EOF
{
  "chat_id": "${chat_id}",
  "text": $(echo "$message" | jq -Rs .),
  "disable_web_page_preview": ${DISABLE_WEB_PAGE_PREVIEW},
  "disable_notification": ${DISABLE_NOTIFICATION}
EOF
)


  # Add parse_mode if set
  if [ -n "${PARSE_MODE}" ]; then
    JSON_PAYLOAD="${JSON_PAYLOAD}, \"parse_mode\": \"${PARSE_MODE}\""
  fi

  # Add message_thread_id if set (for topic support)
  if [ -n "${thread_id}" ]; then
    JSON_PAYLOAD="${JSON_PAYLOAD}, \"message_thread_id\": ${thread_id}"
  fi

  JSON_PAYLOAD="${JSON_PAYLOAD}}"

  # Send request
  RESPONSE=$(curl -s -X POST "${TELEGRAM_API}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}")

  # Check response
  OK=$(echo "$RESPONSE" | jq -r '.ok')
  if [ "$OK" != "true" ]; then
    ERROR_DESC=$(echo "$RESPONSE" | jq -r '.description // "Unknown error"')
    echo "Error sending message: ${ERROR_DESC}"
    exit 1
  fi

  echo "Message sent successfully!"
}

# Function to send photo
send_photo() {
  local chat_id="$1"
  local photo="$2"
  local caption="${3:-}"
  local thread_id="${4:-}"

  set -- -s -X POST "${TELEGRAM_API}/sendPhoto" \
    -F "chat_id=${chat_id}" \
    -F "photo=@${photo}"

  if [ -n "${caption}" ]; then
    set -- "$@" -F "caption=${caption}"
  fi

  if [ -n "${PARSE_MODE}" ]; then
    set -- "$@" -F "parse_mode=${PARSE_MODE}"
  fi

  if [ -n "${thread_id}" ]; then
    set -- "$@" -F "message_thread_id=${thread_id}"
  fi

  RESPONSE=$(curl "$@")


  OK=$(echo "$RESPONSE" | jq -r '.ok')
  if [ "$OK" != "true" ]; then
    ERROR_DESC=$(echo "$RESPONSE" | jq -r '.description // "Unknown error"')
    echo "Error sending photo: ${ERROR_DESC}"
    exit 1
  fi

  echo "Photo sent successfully!"
}

# Function to send media group
send_media_group() {
  local chat_id="$1"
  local media_type="$2"
  local media_list="$3"
  local caption="$4"
  local thread_id="$5"

  local index=0
  local entries=""
  local file_path
  local entry
  local total
  local last_index

  total=$(printf '%s\n' "$media_list" | awk 'NF{count++} END{print count+0}')
  last_index=$((total - 1))

  set -- -s -X POST "${TELEGRAM_API}/sendMediaGroup" \
    -F "chat_id=${chat_id}"

  while IFS= read -r file_path; do
    if [ -z "$file_path" ]; then
      continue
    fi

    if [ $index -eq $last_index ] && [ -n "$caption" ]; then
      entry=$(jq -n \
        --arg type "$media_type" \
        --arg media "attach://file${index}" \
        --arg caption "$caption" \
        --arg parse_mode "$PARSE_MODE" \
        'if $parse_mode != "" then
            {type:$type, media:$media, caption:$caption, parse_mode:$parse_mode}
          else
            {type:$type, media:$media, caption:$caption}
          end'
      )
    else
      entry=$(jq -n \
        --arg type "$media_type" \
        --arg media "attach://file${index}" \
        '{type:$type, media:$media}'
      )
    fi

    if [ $index -gt 0 ]; then
      entries="${entries}
"
    fi
    entries="${entries}${entry}"

    set -- "$@" -F "file${index}=@${file_path}"
    index=$((index + 1))
  done <<EOF
${media_list}
EOF

  if [ $index -eq 0 ]; then
    return
  fi

  media_payload=$(printf '%s
' "$entries" | jq -s '.')
  set -- "$@" -F "media=${media_payload}"

  if [ -n "$thread_id" ]; then
    set -- "$@" -F "message_thread_id=${thread_id}"
  fi

  RESPONSE=$(curl "$@")

  OK=$(echo "$RESPONSE" | jq -r '.ok')
  if [ "$OK" != "true" ]; then
    ERROR_DESC=$(echo "$RESPONSE" | jq -r '.description // "Unknown error"')
    echo "Error sending media group: ${ERROR_DESC}"
    exit 1
  fi

  echo "Media group sent successfully!"
}


# Function to send document
send_document() {
  local chat_id="$1"
  local document="$2"
  local caption="${3:-}"
  local thread_id="${4:-}"

  set -- -s -X POST "${TELEGRAM_API}/sendDocument" \
    -F "chat_id=${chat_id}" \
    -F "document=@${document}"

  if [ -n "${caption}" ]; then
    set -- "$@" -F "caption=${caption}"
  fi

  if [ -n "${PARSE_MODE}" ]; then
    set -- "$@" -F "parse_mode=${PARSE_MODE}"
  fi

  if [ -n "${thread_id}" ]; then
    set -- "$@" -F "message_thread_id=${thread_id}"
  fi

  RESPONSE=$(curl "$@")


  OK=$(echo "$RESPONSE" | jq -r '.ok')
  if [ "$OK" != "true" ]; then
    ERROR_DESC=$(echo "$RESPONSE" | jq -r '.description // "Unknown error"')
    echo "Error sending document: ${ERROR_DESC}"
    exit 1
  fi

  echo "Document sent successfully!"
}

# Main execution
echo "🚀 Telegram GitHub Action"
echo "========================="

# Validate required inputs
if [ -z "${INPUT_TOKEN:-}" ]; then
  echo "Error: Telegram bot token is required"
  exit 1
fi

if [ -z "${INPUT_TO:-}" ]; then
  echo "Error: Telegram chat ID is required"
  exit 1
fi

THREAD_ID="${INPUT_MESSAGE_THREAD_ID:-}"

# Send text message (skip when documents are provided)
if [ -n "${MESSAGE}" ] && [ -z "${INPUT_DOCUMENT:-}" ]; then
  echo "📤 Sending message to chat: ${INPUT_TO}"
  if [ -n "${THREAD_ID}" ]; then
    echo "📌 Topic/Thread ID: ${THREAD_ID}"
  fi
  send_message "${INPUT_TO}" "${MESSAGE}" "${THREAD_ID}"
fi

# Send photo(s) if provided
if [ -n "${INPUT_PHOTO:-}" ]; then
  PHOTO_LIST=$(normalize_list "${INPUT_PHOTO}")
  PHOTO_COUNT=$(printf '%s\n' "$PHOTO_LIST" | awk 'NF{count++} END{print count+0}')

  if [ "$PHOTO_COUNT" -gt 1 ]; then
    echo "📷 Sending ${PHOTO_COUNT} photos as media group"
    send_media_group "${INPUT_TO}" "photo" "${PHOTO_LIST}" "${MESSAGE}" "${THREAD_ID}"
  elif [ "$PHOTO_COUNT" -eq 1 ]; then
    photo_path=$(printf '%s\n' "$PHOTO_LIST" | awk 'NF{print; exit}')
    echo "📷 Sending photo: ${photo_path}"
    send_photo "${INPUT_TO}" "${photo_path}" "${MESSAGE}" "${THREAD_ID}"
  fi
fi

# Send document(s) if provided
if [ -n "${INPUT_DOCUMENT:-}" ]; then
  DOCUMENT_LIST=$(normalize_list "${INPUT_DOCUMENT}")
  DOCUMENT_COUNT=$(printf '%s\n' "$DOCUMENT_LIST" | awk 'NF{count++} END{print count+0}')

  if [ "$DOCUMENT_COUNT" -gt 1 ]; then
    echo "📄 Sending ${DOCUMENT_COUNT} documents as media group"
    send_media_group "${INPUT_TO}" "document" "${DOCUMENT_LIST}" "${MESSAGE}" "${THREAD_ID}"
  elif [ "$DOCUMENT_COUNT" -eq 1 ]; then
    document_path=$(printf '%s\n' "$DOCUMENT_LIST" | awk 'NF{print; exit}')
    echo "📄 Sending document: ${document_path}"
    send_document "${INPUT_TO}" "${document_path}" "${MESSAGE}" "${THREAD_ID}"
  fi
fi


echo "✅ Done!"
