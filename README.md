# Pilgrim Atlas

Pilgrim Atlas is an open-source iOS app for walking Santa Fe, Albuquerque, and northern New Mexico with the phone offline. It shows your GPS position, public-land and protected-area boundaries, trails, and landmarks. Catholic places of worship are drawn differently from other places of worship. Other worship stays on the map.

A polygon is not permission to enter. New Mexico State Trust land is not federal public land. If no dataset covers a point, the app says the status is unknown.

The Swift code is [MIT](LICENSE). The pack is a database of other people's data and is not MIT. OpenStreetMap data is © OpenStreetMap contributors, [ODbL](https://opendatacommons.org/licenses/odbl/).

## What the map shows

One offline pack covers Santa Fe, Albuquerque, Española, Chimayó, Los Alamos, Taos, and the country around them (south 34.80, west -107.30, north 37.05, east -104.70).

| Layer | Source | Terms |
| --- | --- | --- |
| Landmarks and hiking routes | OpenStreetMap, via the Geofabrik New Mexico extract | ODbL. © OpenStreetMap contributors |
| Protected areas | USGS PAD-US 4.1, New Mexico | USGS marks PAD-US CC0. Cite the U.S. Geological Survey Gap Analysis Project, PAD-US 4.1, DOI [10.5066/P96WBCHS](https://doi.org/10.5066/P96WBCHS). GAP status is not a hiking permit. Easements are not in the pack. |
| Forest ownership | USDA Forest Service Basic Ownership (`EDW_BasicOwnership_01`) | Public USDA data. The administrative forest outline is not fee ownership. |
| Surface management | BLM Surface Management Agency, New Mexico | Public-domain federal work. Not a survey and not a deed. |
| Park outlines | NPS Land Resources Division boundary | The legislated line is not fee title. |
| State trust land | New Mexico State Land Office surface status, file dated 2026-07-31 | See the State Land Office notice below. Subsurface-only tracts are not drawn as walkable surface. |
| Albuquerque Open Space | City of Albuquerque Open Space shapefile | City disclaimer below. Status comes from the city's attribute, including units marked closed. |
| Albuquerque lot lines | City of Albuquerque parcels | Lot lines only, at close zoom. No owner names, subdivision names, or lot and block numbers. City disclaimer below. Not a survey and not a land-status layer. |
| Santa Fe County and City of Santa Fe parcels | not included | Link-out only, from the in-app licenses screen. Their parcel polygons are not copied. |

Mass times and confession times are shown only when OpenStreetMap already has `mass_times`, `confession_times`, `service_times`, or `opening_hours`. The value is copied raw. Parish websites are not scraped.

Location stays on the phone. The app has no account and no server of its own. Search runs on the pack. It does not call Nominatim. It does not use openstreetmap.org tile servers. Optional OpenFreeMap vector tiles are off until you accept that the tile host sees the phone's IP address and the tiles it requests.

## Notices that travel with the data

New Mexico State Land Office:

> These data are produced and maintained by the New Mexico State Land Office and are provided as is. The New Mexico State Land Office assumes no responsibility or liability for, or in connection with, the accuracy, reliability, or use of the information provided herein. Moreover, these data do not constitute an official record of title. Matters concerning land title should be directed to the Records Division of the New Mexico State Land Office.

City of Albuquerque, required with the Open Space and parcel data:

> This site provides applications using data that has been modified for use from its original source, www.cabq.gov, the official website of the City of Albuquerque. The City of Albuquerque makes no claims as to the content, accuracy, timeliness, or completeness of any of the data provided at this site. The data provided at this site is subject to change at any time. It is understood that the data provided at this site is being used at one’s own risk.

Boundaries are not a survey. Live fire restrictions and seasonal gates are not in the pack. Closures appear only when a source attribute says the unit is closed.

## Build the pack

Downloads are cached in `~/.cache/pilgrim-atlas/downloads`. The script sends one request per dataset, with a User-Agent, and pauses between ArcGIS pages. Re-runs use the cache.

```bash
python3 -m venv .venv
.venv/bin/pip install -r pipeline/requirements.txt
.venv/bin/python pipeline/build_pack.py
.venv/bin/pytest pipeline/tests -q
```

The repo already contains the pack from a successful build, so a checkout can compile without downloading the source data again. Re-running the script refreshes these files:

- `Sources/PilgrimAtlas/Resources/northern-new-mexico.sqlite` (places, trails, land, licenses)
- `Sources/PilgrimAtlas/Resources/northern-new-mexico.pmtiles` (vector tiles)
- `pack/manifest.json` (counts and byte sizes)

The app icon is `AppIcon.png`, drawn by `pipeline/make_icon.py`: a mesa, a path, and one cross. Marker art is a burgundy cross, a blue dot, and a brown diamond. Place-name labels use a bundled Noto Sans glyph range (SIL Open Font License). That font file is not part of the MIT code license.

## Run the app

The app targets iOS 17, Swift 6, and MapLibre Native. On this machine the Swift toolchain lives on the data drive, which is mounted at `/media/jon/LOJODESKDRIVE1` (the path in `~/.config/ios-dev/env` points at a different mount and will not start).

```bash
source ~/.config/ios-dev/env
export IOS_DEV_ROOT=/media/jon/LOJODESKDRIVE1/ios-dev
export SWIFT_ROOT="$IOS_DEV_ROOT/toolchains/swift-6.3.3-RELEASE-ubuntu24.04"
export PATH="$SWIFT_ROOT/usr/bin:$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$IOS_DEV_ROOT/libs/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XTL_TMPDIR="${XDG_CACHE_HOME:-$HOME/.cache}/xtool-tmp"
export TMPDIR="$XTL_TMPDIR"
cd /home/jon/pilgrim-atlas
swift test --filter PilgrimAtlasCoreTests
xtool dev build
```

`xtool dev build` compiles. It does not install. `xtool dev run` installs; this README does not ask you to run it.

`xtool launch` treats a leading `--debug-…` as its own option and fails with `Unknown option`. Pass app arguments with pymobiledevice3. The argument after `--` is required, so every launch below includes at least one debug flag.

```bash
pymobiledevice3 developer core-device launch-application --userspace --kill-existing -- XTL-N9H4648NB9.com.lojo.PilgrimAtlas <args>
```

`--userspace` is the iOS 17 tunnel. Do not add `--tunnel` next to it. The attached iPhone 11 UDID is `00008030-001A4D340A93402E`.

These flags exist only in a debug build. A release build compiles them out and ignores the arguments. Any flag in the table skips the iOS location alert: the app does not create a `CLLocationManager` and does not call `requestWhenInUseAuthorization`. `--debug-santa-fe-plaza` also pins the camera to Santa Fe Plaza (35.6870, -105.9378). Map screenshots add that flag so the camera, the disclaimer skip, and the location skip travel together. The disclaimer flags force the first-launch gate for this process only and do not clear the saved acceptance.

`--debug-open-place` takes a name or numeric id and opens that sheet. It resolves Loretto Chapel, Cathedral Basilica of St. Francis, Santuario de Chimayo / Chimayó, and Skyline Trail. `--debug-search` opens search with the query and moves the map onto the first place or trail hit. `--debug-tap-at` takes `lat,lon` and uses the same 44-point hit radius as a map tap at zoom 15. More than one place opens the places-here picker.

| Screen | Arguments |
| --- | --- |
| Before you walk, details closed, permission line readable | `--debug-disclaimer` |
| Before you walk, details open | `--debug-disclaimer-details-open` |
| Map at the plaza: land fill, chapel and cathedral, nearby card. No location alert | `--debug-santa-fe-plaza` |
| Places-here picker when a tap covers more than one pin | `--debug-santa-fe-plaza --debug-tap-at 35.686504,-105.93624` |
| Loretto Chapel sheet | `--debug-santa-fe-plaza --debug-open-place "Loretto Chapel"` |
| Cathedral Basilica sheet | `--debug-santa-fe-plaza --debug-open-place "Cathedral Basilica of St. Francis"` |
| Search for Santuario de Chimayo, Catholic row first | `--debug-santa-fe-plaza --debug-search "Santuario de Chimayo"` |
| Search for Cathedral Basilica of St. Francis, map moved onto it | `--debug-santa-fe-plaza --debug-search "Cathedral Basilica of St. Francis"` |
| Chimayó sheet, with the source line | `--debug-santa-fe-plaza --debug-open-place "Santuario de Chimayo"` |
| Layers, lot lines off | `--debug-santa-fe-plaza --debug-show-layers` |
| Search with no matches | `--debug-santa-fe-plaza --debug-search zzzz-no-such-place` |
| Skyline Trail sheet | `--debug-santa-fe-plaza --debug-open-place "Skyline Trail"` |
| Catholic sites chip on, reset visible | `--debug-santa-fe-plaza --debug-filter=catholic` |
| Churches and shrines, including Loretto | `--debug-santa-fe-plaza --debug-filter=churches` |
| Trails on, other place symbols faded | `--debug-santa-fe-plaza --debug-filter=trails` |
| Public land drawn, State Trust and private faded | `--debug-santa-fe-plaza --debug-filter=public-land` |
| Parks only, not a place-name match | `--debug-santa-fe-plaza --debug-filter=parks` |
| Food and rest chip disabled | `--debug-santa-fe-plaza --debug-filter=food` |
| Open now, visitor-hours line visible | `--debug-santa-fe-plaza --debug-filter=open-now` |
| Catholic sites and Open now, map not emptied | `--debug-santa-fe-plaza --debug-filter=catholic,open-now` |
| Search chapel inside Catholic sites | `--debug-santa-fe-plaza --debug-filter=catholic --debug-search=chapel` |
| Layers sheet open, Terrain on | `--debug-terrain` |
| Outside the pack, banner and jump button, no location prompt | `--debug-outside-coverage` |
| Dark appearance | `--debug-santa-fe-plaza --debug-appearance=dark` |
| Light appearance | `--debug-santa-fe-plaza --debug-appearance=light` |
| Nearby card at the 40 percent detent, no drag | `--debug-santa-fe-plaza --debug-card=full` |

`--debug-filter=food` does not clear the map. The chip stays disabled and reads “Not in this pack yet.” `--debug-show-layers` opens More map options, including licenses, and does not turn a chip on. Terrain is on by default. The Layers switch turns hillshade and the 100 ft and 500 ft contours off, and the layers badge counts that. `--debug-terrain` opens More map options with the Terrain switch on, and stays on the plaza without asking for location. Terrain is already on for a normal launch; the flag is what opens the sheet. `--debug-outside-coverage` opens north of the pack, shows the out-of-coverage banner, and does not ask for location. `--debug-appearance=light` and `--debug-appearance=dark` force that appearance for a screenshot. Pass either with `--debug-santa-fe-plaza` when the screenshot should also stay on the plaza. `--debug-card=full` opens the nearby card at the 40 percent detent without a drag, and does not ask for location. Any other value is ignored. Pass it with `--debug-santa-fe-plaza` when the screenshot should also stay on the plaza. `--debug-show-places-picker` opens the same picker for the basilica cluster when you do not pass a coordinate. Without a debug flag, the map opens on the plaza until the phone has a GPS fix, and the location button recenters on that fix. Search and chips stay on the device. The field-app design notes are in `docs/design.md`.

## Layout

- `Sources/PilgrimAtlasCore` is the query, land-status, and Catholic-classification code, with Linux tests in `Tests/PilgrimAtlasCoreTests`.
- `Sources/PilgrimAtlas` is the SwiftUI and MapLibre app.
- `pipeline/` builds the pack. `docs/feasibility.md` is the phase-1 report this app follows.
