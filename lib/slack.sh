#!/bin/zsh

# Prevent duplicate sourcing
if [[ -n "${_LIB_SLACK_LOADED:-}" ]]; then return; fi
_LIB_SLACK_LOADED=true

# Source supporting libraries
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/logging.sh"
. "$SCRIPT_DIR/preflight.sh"

# Preflight check for Slack webhook URL
check_slack_webhook_url() {
  if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
    log_error "SLACK_WEBHOOK_URL environment variable not set."
    return 1
  fi

  # Basic URL format validation
  if [[ ! "$SLACK_WEBHOOK_URL" =~ ^https://hooks\.slack\.com/services/ ]]; then
    log_error "SLACK_WEBHOOK_URL doesn't appear to be a valid Slack webhook URL."
    return 1
  fi

  return 0
}

# Register the preflight check
register_preflight "check_slack_webhook_url"

# Send a Slack message with retries
send_slack_message() {
  local message="$1"
  local max_attempts=3
  local payload="{\"message\": \"${message//\"/\\\"}\", \"source\": \"Terminal\"}"
  
  for attempt in $(seq 1 "$max_attempts"); do
    local slack_response
    slack_response=$(curl -s -o /dev/null -w "%{http_code}" \
      -X POST \
      -H "Content-Type: application/json" \
      --data "$payload" \
      "$SLACK_WEBHOOK_URL" || echo "000")

    if [[ "$slack_response" -eq 200 ]]; then
      return 0
    else
      log_error "Slack notification attempt #$attempt failed (status code: $slack_response)."
      # Sleep 1s before retry, unless it's the last attempt
      if [[ "$attempt" -lt "$max_attempts" ]]; then
        sleep 1
      else
        log_error "Slack notification failed after $max_attempts attempts."
      fi
    fi
  done

  return 1
}
