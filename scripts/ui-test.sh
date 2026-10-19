#!/usr/bin/env bash
# UI tests that tap every screen and control. TestFlight waits on this script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
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
fi
export PIN_SCREENSHOT_DIR="${ROOT}/build/layer-screenshots"
mkdir -p "${PIN_SCREENSHOT_DIR}" /tmp/layer-screenshots
set +e
xcodebuild test \
  -project PilgrimAtlas.xcodeproj \
  -scheme PilgrimAtlasUI \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -derivedDataPath build/UIDerivedData \
  -resultBundlePath build/PilgrimAtlasUITests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM=""
status=$?
if [[ "${status}" -eq 0 && -n "${SECOND}" ]]; then
  xcodebuild test \
    -project PilgrimAtlas.xcodeproj \
    -scheme PilgrimAtlasUI \
    -destination "platform=iOS Simulator,id=${SECOND}" \
    -clonedSourcePackagesDirPath build/SourcePackages \
    -derivedDataPath build/UIDerivedDataSmall \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testFilterSwitchesStayWhereTheyAreSet \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testAlbuquerqueSSPXChapelAndOrthodox \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testNearbyListNextMassAndShare \
    -only-testing:PilgrimAtlasUITests/AtlasUITests/testCitySearchAndOfflineFallback \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM=""
  status=$?
fi
set -e
cp -f /tmp/layer-screenshots/*.png "${PIN_SCREENSHOT_DIR}/" 2>/dev/null || true
exit "${status}"
