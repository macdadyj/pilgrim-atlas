#!/usr/bin/env bash
# Decides whether a UI test log is only a simulator launch or terminate failure.
# Sourced by scripts/ui-test.sh. An assertion failure is never a retry.

lifecycle_pattern='Timed out while launching application via Xcode|Failed to terminate '

launch_timeout_only() {
  local log="$1"
  local lifecycle other
  [[ -f "${log}" ]] || return 1
  lifecycle="$(grep -E "${lifecycle_pattern}" "${log}" || true)"
  [[ -n "${lifecycle}" ]] || return 1
  other="$(grep -E ": error:" "${log}" | grep -v -E "${lifecycle_pattern}" || true)"
  [[ -z "${other}" ]]
}

# One XCTest method name per line, for tests whose only error is a launch or terminate failure.
failed_launch_tests() {
  local log="$1"
  grep -E "${lifecycle_pattern}" "${log}" \
    | sed -n 's/.*AtlasUITests \([A-Za-z0-9_]*\)\].*/\1/p' \
    | sort -u || true
}
