# Pilgrim Atlas design

A field map for a full day outside Santa Fe, Albuquerque, and northern New Mexico. The phone may be in sun, in a pocket, and offline. Chrome follows the LOJO Networks iOS app: system surfaces, one accent used sparingly, and sheets with a drag indicator. The map itself stays a topo field, cream and ink, and does not pick up the UI palette. onX, AllTrails, and Gaia are useful as outdoor products. This app does not copy their brands, colors, or paid symbology.

Appearance follows the iPhone setting: Light, Dark, or System. The app does not force a scheme. Cream and ink are map colors. They are not page or card fills.

## Type

System text styles only, so Dynamic Type applies. Map labels use the bundled Noto Sans Regular range, Latin-1 only.

| Role | Style | Use |
| --- | --- | --- |
| Sheet name | Title 2, semibold, wraps | Full place or trail name |
| Bar title | Headline, inline, 2 lines for a trail | “Catholic landmark”, “Skyline Trail” |
| Card title | Headline | “What you can do here” |
| Section | Footnote, semibold, uppercase, secondary | “About this land”, “Hours” |
| Support | Subheadline, secondary | Land sentence, closures, search subtitle, hours note |
| Numbers | The same style, monospaced digits | Distances and clock times |
| Attribution | Caption 2, `#1C1915` on cream | “© OpenStreetMap contributors”, because it sits on the map |

Text on a system surface uses primary, secondary, or tertiary. Text drawn on the cream map uses map ink so Dark Mode does not turn it white.

## Color

Map ground is `#EFE6D6`. Map ink is `#1C1915`. Catholic marker is burgundy `#8C2F39`. Landmark hexagon is terracotta `#C4622D`.

UI accent is that same burgundy, with a deeper partner: deep brown `#3A2218` in light appearance and terracotta `#C4622D` in dark. The adaptive control tint is burgundy in light and `#E7A8A0` in dark. The gradient runs top-leading to bottom-trailing and is only on icon tiles and the primary button. Status green is `#29B873`, amber `#F29E1A`, red `#E64540`.

Screens use `systemGroupedBackground`. Cards use `secondarySystemGroupedBackground`, an 18-point continuous corner, and a 0.06 hairline. No card shadow. Floating map controls use a material blur. Chips and icon washes are opacity steps of the accent: about 0.12 off, and a solid accent fill with white text when on.

Land fills are painted at 0.48 opacity so the hillshade reads through. The legend swatch uses that same opacity on cream. Private land is the light tan `#C4B49A` with a `#4A4036` outline. Forest is green `#1F7A3A`, national park blue `#1F6F8A`, tribal purple `#7A3E8C`, BLM gold `#C48A12`, State Trust orange `#E06A1F`. Fills stay at or above 0.45 opacity. A lower fill, or a beige layer painted over them, fails the render check.

Trail lines are a cream casing (`#F4EFE4`) and a `#6B4F3A` core.

## Spacing

16 points of screen padding and card padding. 18 points between license cards. 10 to 14 points between rows. Chips are capsules with at least a 44-point hit area. The primary button is about 50 points tall with a 14-point corner. The nearby card is a sheet: a short detent shows one summary row, and the next detent is 40 percent of the screen. The system drag indicator moves between them. The location control is 50 points. The trail-line well uses the same 18-point continuous radius as a card.

## Chrome

One top row: a Search pill and the layers button. Licenses live in that sheet, not on a second button. The filter chips are one horizontal row directly under that pill. They do not float over the middle of the map. Location is one floating control above the card. The MapLibre logo and the info button sit 16 points above the card, logo on the left and info button on the right. Their inset follows the short detent and the 40 percent detent. The OpenStreetMap caption and the location control are the next row up, clear of the wordmark and the info button. The short detent is only the summary sentence. Dragging the indicator to 40 percent shows the single status line and the rest, and that sheet scrolls inside the cap. There is not a stack of capsules. Load errors, a denied location, a public-land or open-now sentence, and the offline line take that one line, in that order. When the camera is outside the northern New Mexico pack, one banner under the chips, above the sheet, says “This view is outside the offline pack.” The short card uses that same sentence. “Show the nearest mapped area” recenters at zoom 12 on the nearest point inside the pack. `--debug-outside-coverage` opens that state on a point north of the pack and does not ask for location.

Filter chips scroll sideways, including past the trailing edge when Reset is showing. A fade on the trailing edge shows that the row continues. The row is a fixed height so it stays under Search. Off chips are a tint on material, with no stroke. On chips are accent fill and white text. A light haptic fires when a filter changes. Food and rest stays disabled and reads “Not in this pack yet.”

## Map

The camera opens at zoom 16 so the Cathedral and Loretto can sit apart. Offline pack layers stay on. OpenFreeMap streets are optional and do not replace land, trails, or places. The logical center sits above the card.

Place symbols use those same layers. The features are the pack places after the near-duplicate drop, so a second record at the same site is not drawn. Catholic worship is the last symbol layer, drawn larger (icon size 1), allowed to overlap, and sorted first so the cross keeps the slot. Its label prefers the top. Chapels, cathedrals, basilicas, and santuarios are a slightly smaller pin and do not force an overlap; their labels prefer the bottom. Other roles do not overlap. Labels may drop instead of colliding. A name that contains “untitled” or “unnamed” is not drawn. A second pin within about 80 meters is dropped when the names are the same site, including an exact repeat and a historic-site alias, so Chimayó draws one santuario. Every badge has a white halo. The marker legend uses those same images. Landmarks stay a terracotta hexagon. Other roles keep their own shape and color. Sheet and list rows use a rounded-square gradient icon tile with that role’s symbol, and the name uses the primary text color. A gallery, a monument, or a saint that is only tagged landmark gets that category’s tile and label instead of a generic landmark row. Those tiles are not the map badges.

A Catholic search recenters on the nearest hit, or on the hits within about 2.5 km when that cluster is under about 8 km. It does not fit the whole region. While the query is non-empty, pins and trails stay visible even if a chip would hide them.

Trails-only mode fades the marker to 0.55 and leaves the name at full opacity, with a white halo.

Land polygons for the plaza come from `northern-new-mexico-land.pmtiles`, zoom 8–14, with a short round buffer so the fills are less angular. The main pack still stops land at zoom 11. Its zoom 14 tiles are places, plus Albuquerque parcels. Trails stay on the main pack and overzoom from zoom 12. Pointing the land source back at the main pack at zoom 14 fails the render check, because that tile has no land.

## Chips

Catholic sites, Churches and shrines, Trails, Public land, Parks, Food and rest, Open now. No chip means the full map. Place chips intersect. Trails leave the map when any chip is on and Trails is off. Public land is forest, BLM, national park, other federal, local protected areas, and Albuquerque Open Space. State Trust is not public land. Parks are national parks, Albuquerque Open Space, and local protected areas whose name contains “park.” Open now uses a parsed weekday clock in the device time zone. It filters lists and search. It does not hide a pin, because visitor hours are not on the tile. A reset clears chips only.

## Sheets

Sheets open at medium, and can still move to large or a shorter height. The drag indicator is visible, and the sheet scrolls instead of only resizing. The place sheet’s source line can scroll clear of the bottom. The bar title is inline. The first row is the full name. Denomination reads “Roman Catholic.” Wikipedia links use the article title.

Hours are a shape plus words, never color alone. A filled green dot is “Open now.” A hollow red ring is “Closed now.” A half ring is “Hours disagree” when the hours are not one clock, and “Unknown” when the pack has no hours. The longer pack sentence stays as the subtitle.

Access `private` reads “The map tag says private. That is how OpenStreetMap recorded it, not a ruling about your visit.” It does not grant entry.

The first-launch disclaimer keeps the warning, the details, and the full-width gradient button, “I understand,” together at the top. The button is not pinned under an empty middle.

More map options holds Terrain, lot lines, online tiles, “Hide places with no hours,” the terrain legend, the marker legend, land colors, and licenses. Terrain is on by default. The layers button shows a badge when parcels are on, online tiles are on, places without hours are hidden, or terrain is off.

## Icons

Badges are drawn at 72 points. On the map, Catholic sites are about full size and chapels about 0.92. Other roles are about 0.78. Catholic sites and chapels are a map pin and a cross. Chapel is cream with a burgundy cross. Catholic is burgundy with a cream cross. The halo is white. Landmark is a terracotta hexagon. Viewpoint is a triangle. Shrine and trailhead are diamonds. Worship and water are circles. Museum and parking are rounded rectangles.

## Terrain

Hillshade and foot contours ship in the app. They are derived from Mapzen Terrain Tiles on AWS Open Data, Terrarium RGB elevation, licensed CC BY 4.0 and ODbL. The phone does not request those tiles. `pipeline/pilgrim/terrain.py` writes the terrain archives. `pipeline/pilgrim/land_detail.py` writes the smoothed land archive.

| Archive | What | Zooms | Bytes |
| --- | --- | --- | --- |
| `northern-new-mexico-hillshade.pmtiles` | JPEG hillshade, cooler gray, stronger contrast | 7–12 | 24100131 |
| `northern-new-mexico-contours.pmtiles` | 100 ft lines, 500 ft index labeled in feet | 12 | 9998933 |
| `northern-new-mexico-land.pmtiles` | land fills, corners rounded | 8–14 | 4743402 |

The camera is zoom 16, so hillshade and contours overzoom from 12. The hillshade raster uses extra contrast and a lifted shadow floor so the highlights stay light under the 0.48 land fills, in light and dark appearance. The map ground stays cream either way. Every contour has a white casing. Intermediate lines are a darker tan at nearly full opacity. Index lines are map ink, heavier, and labeled “N ft.” The label halo grows from 1.5 points at zoom 12 to 3.5 points at plaza zoom. The layers sheet has a terrain legend for those three. Flat ground stays even. Turning Terrain off hides hillshade, the casing, both contour weights, and the labels. `--debug-terrain` opens that sheet with Terrain on.

Trails in the pack are 2D. A single way, or a short chain of ways with no junction, shows its measured length. A branched record hides the summed length. A multiline whose parts add up to 50 km or more does too: the packed Skyline Trail is a network of ways, and the sheet does not show that total.

**Still to do.** Per-pin hour captions. Clustering below zoom 13. Food and rest rows when a later extract has those amenities. Map glyphs beyond Latin-1. Trail difficulty if a source actually has it.
