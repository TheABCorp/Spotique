#!/usr/bin/env bash
#
# Smoke-test the auth endpoints (send-code, verify, complete-profile) against a
# running dev server. Codes are never read from logs: after each send-code, the
# latest code's digest is overwritten with a known value via `rails runner`.
#
# Usage (from Api/):
#   script/smoke_auth.sh                                   # local server on :3000
#   BASE_URL=http://localhost:3001 script/smoke_auth.sh    # different port
#   RUNNER="docker compose exec -T api bin/rails runner" script/smoke_auth.sh
#
# The runner must point at the same database as the server under test.

set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:3000}
RUNNER=${RUNNER:-bin/rails runner}
AUTH="$BASE_URL/api/v1/auth"
KNOWN_CODE=111111

# Fresh identities each run so the 3-sends-per-hour limit never interferes.
SUFFIX=$(printf '%04d' $((RANDOM % 10000)))
PHONE="+1718555$SUFFIX"
EMAIL="smoke-$SUFFIX-$$@example.com"
LOCK_PHONE="+1347555$SUFFIX"

failures=0
STATUS=""
BODY=""

# post PATH JSON [extra curl args...] — sets STATUS and BODY.
post() {
  local response
  response=$(curl -sS -w '\n%{http_code}' -H 'Content-Type: application/json' "${@:3}" -d "$2" "$AUTH/$1")
  STATUS=${response##*$'\n'}
  BODY=${response%$'\n'*}
}

expect() {
  local label=$1 want=$2
  if [[ $STATUS == "$want" ]]; then
    echo "  ok    $label ($STATUS)"
  else
    echo "  FAIL  $label: expected $want, got $STATUS — $BODY"
    failures=$((failures + 1))
  fi
}

# set_known_code MEDIUM VALUE — overwrite the latest unverified code with KNOWN_CODE.
set_known_code() {
  $RUNNER '
    abort "refusing to run outside development/test" unless Rails.env.local?
    medium, value, code = ARGV
    record = VerificationCode.for_medium(medium, value).unverified.recent.first
    abort "no verification code found for #{value}" unless record
    record.update!(code_digest: VerificationCode.digest_code(code))
  ' "$1" "$2" "$KNOWN_CODE"
}

json_field() {
  sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" <<<"$BODY"
}

echo "Smoke-testing $AUTH"

if ! curl -sf -o /dev/null "$BASE_URL/up"; then
  echo "Server not reachable at $BASE_URL" >&2
  exit 1
fi

echo "Phone flow ($PHONE)"
post send-code "{\"phone\":\"$PHONE\"}"
expect "send-code" 200
set_known_code phone "$PHONE"
post verify "{\"phone\":\"$PHONE\",\"code\":\"000000\"}"
expect "verify with wrong code" 401
post verify "{\"phone\":\"$PHONE\",\"code\":\"$KNOWN_CODE\"}"
expect "verify (new user)" 200
[[ $BODY == *'"is_new":true'* ]] || { echo "  FAIL  expected is_new true — $BODY"; failures=$((failures + 1)); }
TOKEN=$(json_field token)
post verify "{\"phone\":\"$PHONE\",\"code\":\"$KNOWN_CODE\"}"
expect "reuse verified code" 401
post complete-profile '{"user":{"first_name":"Smoke"}}'
expect "complete-profile without token" 401
post complete-profile '{}' -H "Authorization: Bearer garbage"
expect "complete-profile with bad token" 401
post complete-profile '{"user":{"first_name":"Smoke","last_name":"Driver","role":"driver","address":{"label":"home","street":"37-01 82nd St","city":"Jackson Heights","state":"NY","zip":"11372"}}}' \
  -H "Authorization: Bearer $TOKEN"
expect "complete-profile" 201
post complete-profile '{"user":{"first_name":"Again","last_name":"Driver","role":"driver"}}' -H "Authorization: Bearer $TOKEN"
expect "complete-profile twice" 409

echo "Returning user ($PHONE)"
post send-code "{\"phone\":\"$PHONE\"}"
expect "send-code" 200
set_known_code phone "$PHONE"
post verify "{\"phone\":\"$PHONE\",\"code\":\"$KNOWN_CODE\"}"
expect "verify (returning user)" 200
[[ $BODY == *'"is_new":false'* ]] || { echo "  FAIL  expected is_new false — $BODY"; failures=$((failures + 1)); }

echo "Email flow ($EMAIL)"
post send-code "{\"email\":\"$EMAIL\"}"
expect "send-code" 200
set_known_code email "$EMAIL"
post verify "{\"email\":\"$EMAIL\",\"code\":\"$KNOWN_CODE\"}"
expect "verify (new user)" 200

echo "Lockout and rate limit ($LOCK_PHONE)"
post send-code "{\"phone\":\"$LOCK_PHONE\"}"
expect "send-code 1" 200
for attempt in 1 2 3 4; do
  post verify "{\"phone\":\"$LOCK_PHONE\",\"code\":\"000000\"}"
  expect "wrong code attempt $attempt" 401
done
post verify "{\"phone\":\"$LOCK_PHONE\",\"code\":\"000000\"}"
expect "wrong code attempt 5 locks out" 429
post send-code "{\"phone\":\"$LOCK_PHONE\"}"
expect "send-code 2" 200
post send-code "{\"phone\":\"$LOCK_PHONE\"}"
expect "send-code 3" 200
post send-code "{\"phone\":\"$LOCK_PHONE\"}"
expect "send-code 4 is rate limited" 429

echo "Validation"
post send-code '{"phone":"+17185550123","email":"a@b.com"}'
expect "both phone and email" 400
post send-code '{"phone":"7185550123"}'
expect "phone without +1" 422
post send-code '{"email":"not-an-email"}'
expect "invalid email" 422

echo
if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All checks passed"
