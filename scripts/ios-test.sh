#!/usr/bin/env bash
# Run unit tests on an available iPhone simulator.
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
echo "udid=${UDID}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "udid=${UDID}" >> "${GITHUB_OUTPUT}"
fi
xcodebuild test \
  -project PilgrimAtlas.xcodeproj \
  -scheme PilgrimAtlasTests \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -clonedSourcePackagesDirPath build/SourcePackages \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/PilgrimAtlasTests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM=""
