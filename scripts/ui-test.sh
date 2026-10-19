#!/usr/bin/env bash
# UI tests that tap every screen and control. TestFlight waits on this script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
# shellcheck disable=SC1091
source "${ROOT}/scripts/ui-launch-retry.sh"

# XCUIApplication's "Timed out while launching application via Xcode" waiter has
# no xcodebuild flag. Pre-booting the second simulator and retrying that
# failure once are the fix. The documented test execution allowance is still
# set so a slow launch is not also killed as a hung test. Assertion failures
# are not retried.
preboot_simulator() {
  local udid="$1"
  echo "Pre-booting simulator ${udid}"
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b
  echo "Simulator ${udid} is booted"
}

xcodebuild_status=0
run_xcodebuild() {
  local log="$1"
  shift
  mkdir -p "$(dirname "${log}")"
  set +e
  xcodebuild "$@" 2>&1 | tee "${log}"
  xcodebuild_status=${PIPESTATUS[0]}
  set -e
}

# Re-runs only tests that failed to launch. Returns 0 when there is nothing to retry.
retry_launch_failures() {
  local log="$1"
  local udid="$2"
  local derived="$3"
  local retry_log="$4"
  if [[ "${xcodebuild_status}" -eq 0 ]]; then
    return 0
  fi
  if ! launch_timeout_only "${log}"; then
    echo "Not retrying. The log has a failure other than a simulator launch or terminate error."
    return 0
  fi
  local names=()
  local name
  while IFS= read -r name; do
    [[ -n "${name}" ]] && names+=("${name}")
  done < <(failed_launch_tests "${log}")
  if [[ "${#names[@]}" -eq 0 ]]; then
    echo "Not retrying. The simulator failure did not name a test."
    return 0
  fi
  local only=()
  for name in "${names[@]}"; do
    echo "UI_TEST_RETRY simulator launch or terminate failure: PilgrimAtlasUITests/AtlasUITests/${name}"
    only+=("-only-testing:PilgrimAtlasUITests/AtlasUITests/${name}")
  done
  preboot_simulator "${udid}"
  run_xcodebuild "${retry_log}" test \
    -project PilgrimAtlas.xcodeproj \
    -scheme PilgrimAtlasUI \
    -destination "platform=iOS Simulator,id=${udid}" \
    -clonedSourcePackagesDirPath build/SourcePackages \
    -derivedDataPath "${derived}" \
    "${only[@]}" \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 600 \
    -maximum-test-execution-time-allowance 600 \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM=""
}
if [[ ! -d PilgrimAtlas.xcodeproj ]]; then
  xcodegen generate
fi
UDID="$(python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(raw)
chosen = ""
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("name", "").startswith("iPhone") and device.get("isAvailable", True):
            chosen = device["udid"]
if not chosen:
    raise SystemExit("No available iPhone simulator")
print(chosen)
PY
)"
SECOND="$(PRIMARY="${UDID}" python3 - <<'PY'
import json, os, subprocess
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
data = json.loads(raw)
phones = []
pads = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        name = device.get("name", "")
        if name.startswith("iPhone"):
            phones.append((name, device["udid"]))
        elif name.startswith("iPad"):
            pads.append((name, device["udid"]))
primary = os.environ.get("PRIMARY", "")
def prefer(rows, needles):
    for needle in needles:
        for name, udid in rows:
            if needle in name and udid != primary:
                return udid
    for name, udid in rows:
        if udid != primary:
            return udid
    return ""
chosen = prefer(phones, ["SE", "mini", "Pro Max", "Plus"])
if not chosen:
    chosen = prefer(pads, ["iPad"])
print(chosen)
PY
)"
if [[ -z "${SECOND}" ]]; then
  CREATED="$(python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"], text=True)
runtimes = [item for item in json.loads(raw).get("runtimes", []) if item.get("isAvailable") and "iOS" in item.get("name", "")]
if not runtimes:
    print("")
    raise SystemExit
runtime = runtimes[-1]["identifier"]
types = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "-j"], text=True)).get("devicetypes", [])
wanted = ""
for name in ("iPhone SE (3rd generation)", "iPhone 16 Pro Max", "iPad Pro 13-inch (M4)"):
    if any(item.get("name") == name for item in types):
        wanted = name
        break
if not wanted:
    print("")
    raise SystemExit
udid = subprocess.check_output(["xcrun", "simctl", "create", "Pilgrim second size", wanted, runtime], text=True).strip()
print(udid)
PY
)" || CREATED=""
  SECOND="${CREATED}"
fi
echo "UI tests on ${UDID}"
if [[ -n "${SECOND}" ]]; then
  echo "Journey tests also on ${SECOND}"
  preboot_simulator "${SECOND}"
fi
export PIN_SCREENSHOT_DIR="${ROOT}/build/layer-screenshots"
mkdir -p "${PIN_SCREENSHOT_DIR}" /tmp/layer-screenshots build/ui-logs
run_xcodebuild build/ui-logs/primary.log test \
  -project PilgrimAtlas.xcodeproj \
  -scheme PilgrimAtlasUI \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -derivedDataPath build/UIDerivedData \
  -resultBundlePath build/PilgrimAtlasUITests.xcresult \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 600 \
  -maximum-test-execution-time-allowance 600 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM=""
retry_launch_failures build/ui-logs/primary.log "${UDID}" build/UIDerivedData build/ui-logs/primary-retry.log
status="${xcodebuild_status}"
if [[ "${status}" -eq 0 && -n "${SECOND}" ]]; then
  preboot_simulator "${SECOND}"
  run_xcodebuild build/ui-logs/second.log test \
    -project PilgrimAtlas.xcodeproj \
    -scheme PilgrimAtlasUI \
    -destination "platform=iOS Simulator,id=${SECOND}" \
    -clonedSourcePackagesDirPath build/SourcePackages \
    -derivedDataPath build/UIDerivedDataSmall \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testFilterSwitchesStayWhereTheyAreSet \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testAlbuquerqueSSPXChapelAndOrthodox \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testNearbyListNextMassAndShare \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testCitySearchAndOfflineFallback \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 600 \
    -maximum-test-execution-time-allowance 600 \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM=""
  retry_launch_failures build/ui-logs/second.log "${SECOND}" build/UIDerivedDataSmall build/ui-logs/second-retry.log
  status="${xcodebuild_status}"
fi
cp -f /tmp/layer-screenshots/*.png "${PIN_SCREENSHOT_DIR}/" 2>/dev/null || true
exit "${status}"
