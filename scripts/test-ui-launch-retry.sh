#!/usr/bin/env bash
# Checks that a launch timeout can be retried and an assertion cannot.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/ui-launch-retry.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat >"${TMP}/launch.log" <<'EOF'
/Users/runner/Tests/PilgrimAtlasUITests/AtlasUITests.swift:717: error: -[PilgrimAtlasUITests.AtlasUITests testAlbuquerqueSSPXChapelAndOrthodox] : Failed to launch PilgrimAtlas.app via Xcode: Timed out while launching application via Xcode.
Failing tests:
	AtlasUITests.testAlbuquerqueSSPXChapelAndOrthodox
** TEST FAILED **
EOF
launch_timeout_only "${TMP}/launch.log"
names="$(failed_launch_tests "${TMP}/launch.log")"
[[ "${names}" == "testAlbuquerqueSSPXChapelAndOrthodox" ]]

cat >"${TMP}/assert.log" <<'EOF'
/Users/runner/Tests/PilgrimAtlasUITests/AtlasUITests.swift:207: error: -[PilgrimAtlasUITests.AtlasUITests testChurchPinsAndPerpetualHelpLiturgy] : XCTAssertTrue failed
** TEST FAILED **
EOF
if launch_timeout_only "${TMP}/assert.log"; then
  echo "assertion failure was treated as a launch timeout" >&2
  exit 1
fi

cat >"${TMP}/both.log" <<'EOF'
/Users/runner/Tests/PilgrimAtlasUITests/AtlasUITests.swift:169: error: -[PilgrimAtlasUITests.AtlasUITests testDenverSearchShowsCatholicPins] : XCTAssertTrue failed - Denver search row
/Users/runner/Tests/PilgrimAtlasUITests/AtlasUITests.swift:717: error: -[PilgrimAtlasUITests.AtlasUITests testAlbuquerqueSSPXChapelAndOrthodox] : Failed to launch PilgrimAtlas.app via Xcode: Timed out while launching application via Xcode.
EOF
if launch_timeout_only "${TMP}/both.log"; then
  echo "a mixed assertion and launch timeout was treated as retryable" >&2
  exit 1
fi

echo "ui launch retry checks passed"
