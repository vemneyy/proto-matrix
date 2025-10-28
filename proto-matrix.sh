#!/bin/bash

DOMAINS_FILE="domains.txt"

if [ ! -f "$DOMAINS_FILE" ]; then
  echo "$DOMAINS_FILE don't exist"
  exit 1
fi

printf "%-50s  %-7s  %-7s  |  %-7s  %-7s  %-7s  |  %-8s  %-7s  |  %s\n" \
  "Domain" "TLSv1.2" "TLSv1.3" "HTTP1.1" "HTTP2" "QUIC" "Time(ms)" "HSTS" "Status"
printf "%-50s  %-7s  %-7s  |  %-7s  %-7s  %-7s  |  %-8s  %-7s  |  %s\n" \
  "----------------------------------------" "-------" "-------" "-------" "-------" "-------" "--------" "-------" "------"

TOTAL_OK=0
NO_TLS13=0
NO_HTTP2_QUIC=0

check_domain() {
  DOMAIN=$1

  try_curl() {
    local URL=$1
    shift
    local OPTS=("$@")
    local HTTP_CODE=000
    local HTTP_VER=""
    local TIME_TOTAL=0
    for i in 1 2 3; do
      OUTPUT=$(curl -s --max-time 1 "${OPTS[@]}" -o /dev/null -w "%{http_code} %{http_version} %{time_total}" "$URL" 2>/dev/null)
      HTTP_CODE=$(echo "$OUTPUT" | awk '{print $1}')
      HTTP_VER=$(echo "$OUTPUT" | awk '{print $2}')
      TIME_TOTAL=$(echo "$OUTPUT" | awk '{print $3}')
      if [ "$HTTP_CODE" != "000" ]; then
        break
      fi
    done
    echo "$HTTP_CODE $HTTP_VER $TIME_TOTAL"
  }

  OUTPUT_TLS12=$(try_curl "$DOMAIN" --tls-max 1.2)
  RESPONSE_TLS12=$(echo "$OUTPUT_TLS12" | awk '{print $1}')
  TLS12_OK="N"
  [ "$RESPONSE_TLS12" -ge 200 ] && [ "$RESPONSE_TLS12" -lt 600 ] && TLS12_OK="Y"

  # TLS 1.3
  OUTPUT_TLS13=$(try_curl "$DOMAIN" --tlsv1.3 --tls-max 1.3)
  RESPONSE_TLS13=$(echo "$OUTPUT_TLS13" | awk '{print $1}')
  TLS13_OK="N"
  [ "$RESPONSE_TLS13" -ge 200 ] && [ "$RESPONSE_TLS13" -lt 600 ] && TLS13_OK="Y"

  OUTPUT_HTTP1=$(try_curl "$DOMAIN" --http1.1)
  RESPONSE_HTTP1=$(echo "$OUTPUT_HTTP1" | awk '{print $1}')
  VERSION_HTTP1=$(echo "$OUTPUT_HTTP1" | awk '{print $2}')
  HTTP1_OK="N"
  if [[ "$RESPONSE_HTTP1" -ge 200 && "$RESPONSE_HTTP1" -lt 600 && "$VERSION_HTTP1" == "1.1" ]]; then
    HTTP1_OK="Y"
  fi

  OUTPUT_HTTP2=$(try_curl "$DOMAIN" --http2)
  RESPONSE_HTTP2=$(echo "$OUTPUT_HTTP2" | awk '{print $1}')
  VERSION_HTTP2=$(echo "$OUTPUT_HTTP2" | awk '{print $2}')
  HTTP2_OK="N"
  if [[ "$RESPONSE_HTTP2" -ge 200 && "$RESPONSE_HTTP2" -lt 600 && "$VERSION_HTTP2" == "2" ]]; then
    HTTP2_OK="Y"
  fi

  OUTPUT_QUIC=$(try_curl "$DOMAIN" --http3-only)
  RESPONSE_QUIC=$(echo "$OUTPUT_QUIC" | awk '{print $1}')
  QUIC_OK="N"
  [ "$RESPONSE_QUIC" -ge 200 ] && [ "$RESPONSE_QUIC" -lt 600 ] && QUIC_OK="Y"

  RESPONSE_MAIN=$RESPONSE_TLS13
  TIME_MAIN=$(echo "$OUTPUT_TLS13" | awk '{print $3}')
  [ "$RESPONSE_MAIN" -eq 000 ] && RESPONSE_MAIN=$RESPONSE_TLS12 && TIME_MAIN=$(echo "$OUTPUT_TLS12" | awk '{print $3}')
  TIME_MS=$(awk "BEGIN {printf \"%.0f\", $TIME_MAIN * 1000}")

  HSTS_HEADER=$(curl -s -I --max-time 1 "$DOMAIN" 2>/dev/null | grep -i "Strict-Transport-Security")
  HSTS_OK="N"
  [ -n "$HSTS_HEADER" ] && HSTS_OK="Y"

  STATUS="FAIL"
  [ "$RESPONSE_MAIN" -ge 200 ] && [ "$RESPONSE_MAIN" -lt 500 ] && STATUS="OK"

  LINE=$(printf "%-50s  %-7s  %-7s  |  %-7s  %-7s  %-7s  |  %-8s  %-7s  |  %s" \
    "$DOMAIN" "$TLS12_OK" "$TLS13_OK" "$HTTP1_OK" "$HTTP2_OK" "$QUIC_OK" "$TIME_MS" "$HSTS_OK" "$STATUS")

  LINE=$(echo "$LINE" \
    | sed -E "s/ Y / \x1b[32mY\x1b[0m /g; s/ N / \x1b[31mN\x1b[0m /g; s/ OK$/ \x1b[32mOK\x1b[0m/; s/ FAIL$/ \x1b[31mFAIL\x1b[0m/")

  echo -e "$LINE"

  if [ "$STATUS" == "OK" ]; then
    ((TOTAL_OK++))
  fi
  if [ "$TLS13_OK" == "N" ]; then
    ((NO_TLS13++))
  fi
  if [ "$HTTP2_OK" == "N" ] && [ "$QUIC_OK" == "N" ]; then
    ((NO_HTTP2_QUIC++))
  fi
}

export -f check_domain
export TOTAL_OK
export NO_TLS13
export NO_HTTP2_QUIC

cat "$DOMAINS_FILE" | xargs -I{} -P "$(nproc)" bash -c '
DOMAIN=$(echo "{}" | xargs)
[ -z "$DOMAIN" ] && exit 0
echo "$DOMAIN" | grep -qE "^https?://" || DOMAIN="https://$DOMAIN"
check_domain "$DOMAIN"
'
