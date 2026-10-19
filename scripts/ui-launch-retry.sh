#!/usr/bin/env bash
# Decides whether a UI test log is only the simulator launch timeout.
# Sourced by scripts/ui-test.sh. An assertion failure is never a retry.

launch_timeout_only() {
  local log="$1"
  [[ -f "${log}" ]] || return 1
  grep -q "Timed out while launching application via Xcode" "${log}" || return 1
  if grep -E ": error:" "${log}" | grep -v "Timed out while launching application via Xcode" | grep -q .; then
    return 1
  fi
  return 0
}

# One XCTest method name per line, for tests whose only error is the launch timeout.
failed_launch_tests() {
  local log="$1"
  grep "Timed out while launching application via Xcode" "${log}" \
    | sed -n 's/.*AtlasUITests \([A-Za-z0-9_]*\)\].*/\1/p' \
    | sort -u
}
