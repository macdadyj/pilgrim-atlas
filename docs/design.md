# Pilgrim Atlas design

A field map for a full day outside Santa Fe, Albuquerque, and northern New Mexico. The phone may be in sun, in a pocket, and offline. The reference for chrome is **Apple Maps**: a map with a short top bar, filter chips, a search sheet, and a bottom card that does not pretend to be the whole screen. Apple’s Human Interface Guidelines for maps (sheets, 44-point targets, one primary map, standard gestures) match that. onX, AllTrails, and Gaia are useful as outdoor products, and this app does not copy their brands, colors, or paid symbology.

## Type

Use the system font. Map labels use the bundled Noto Sans Regular range, Latin-1 only.

| Role | Style | Use |
| --- | --- | --- |
| Sheet name | Title 2, semibold, wraps, no line limit | Full place or trail name in the first row |
| Bar title | Headline, 2 lines for a trail, 1 line for a kind | “Catholic landmark”, “Skyline Trail” |
| Card title | Headline | “What you can do here” |
| Body | Body, primary | Permission line, open or closed |
| Support | Subheadline or body, primary | Land sentence, closures, hours note, search subtitle. Primary stays readable on a dark sheet. |
| Status | Caption | One capsule under the chips |
| Attribution | Caption 2, `#1C1915` on cream | “© OpenStreetMap contributors” |
| Footnote | Footnote, primary | License notes |

`#3A3228` on white is about 10:1. Do not use system secondary for text that has to be read in daylight.

## Color

Ground is `#EFE6D6`. Ink is `#1C1915`. Cream halo is `#F4EFE4`. Sheet and search support text uses the primary label color so a dark sheet does not turn it brown-on-black. Catholic marker is `#8C2F39`. Landmark hexagon is `#C4622D`.

Land fills are painted at 0.58 opacity so the hillshade reads through. The legend swatch uses that same opacity on cream. Private land is the light tan `#C4B49A` with a `#4A4036` outline. Forest is green `#1F7A3A`, national park blue `#1F6F8A`, tribal purple `#7A3E8C`, BLM gold `#C48A12`, State Trust orange `#E06A1F`. Those stay apart after the blend. Every kind the style paints has a legend row. Fills stay at or above 0.45 opacity. A lower fill, or a beige layer painted over them, fails the render check.

Trail lines are a cream casing (`#F4EFE4`, width about 3 to 7 by zoom) and a `#6B4F3A` core (about 1.6 to 4). The legend chip is that brown.

## Spacing

8 points between chips and between card rows. 12 points of card padding. 16 points of screen padding. The nearby card scrolls and stays near 40 percent of the screen height. Map controls are at least 44 points.

## Map

Offline pack layers stay on. OpenFreeMap streets are optional and do not replace land, trails, or places. One status capsule. Copyright sits at the lower leading edge, not next to the buttons.

Place symbols are layers on the pack vector tiles (`places`), with badges registered at launch. Catholic worship and chapels, cathedrals, basilicas, and santuarios are a map pin with a large cross, a cream halo, and may overlap. Landmarks are a terracotta hexagon with a cream dot, not a grey star. Other roles use a circle, diamond, triangle, or rounded square, each with its own color. Labels use a variable anchor (top, bottom, left, right), wrap to about 11 ems, and may drop instead of colliding or clipping the edge. A runtime GeoJSON pin source is not used. Clustering below zoom 13 is still planned. Open now filters lists and search. It does not hide a pin, because visitor hours are not on the tile.

Land and trails are separate vector sources on the same pack. Land stops at zoom 11 and trails at zoom 12. The camera is zoom 15, so those sources overzoom. The archive zoom 14 tiles contain places only, plus Albuquerque parcels. One source at zoom 14 leaves the cream background where the fills and trails should be.

Selected place: a burgundy ring.

## Chips

Catholic sites, Churches and shrines, Trails, Public land, Parks, Food and rest, Open now. The row scrolls. The last chip can move fully into view. There is no fade mask over the trailing edge. No chip means the full map. Place chips intersect. Trails leave the map when any chip is on and Trails is off. Public land is forest, BLM, national park, other federal, local protected areas, and Albuquerque Open Space. State Trust is not public land. Parks are national parks, Albuquerque Open Space, and local protected areas whose name contains “park.” A place named “park” is not a park polygon. Food and rest stays disabled while the pack has no cafe, restaurant, fast food, or toilets. Open now uses a parsed weekday clock in the device time zone. Places with no hours stay visible. Places whose hours are not a single clock stay visible and say so. A reset clears chips only. It does not turn lot lines on, turn online tiles off, turn terrain off, or clear the search field.

Search covers places, trails, towns, and land names, then applies the same chips. While the query is non-empty the camera fits the first results and the pins and trails stay visible, including when a chip would have hidden them. The sheet opens at a medium height so the map is on screen. The nearby card and map taps use that predicate too. The nearby card and the place and trail sheets wrap their text and keep padding under the last row.

## Sheets

The bar title is the short kind, or the trail name up to two lines. The first row is the full name, wrapping. Denomination reads “Roman Catholic,” not `roman_catholic`. Wikipedia links use the article title, not an `en:` prefix. Empty hours are one line, “No visitor hours in the pack,” not a section that only says the pack is empty. A single clock can say “Open now” or “Closed now.” Conflicting or unparsed hours are one row per range plus “Hours listed, not a single clock.”

More map options holds Terrain, lot lines, online tiles, and “Hide places with no hours.” Terrain is on by default. The layers button shows a badge when parcels are on, online tiles are on, places without hours are hidden, or terrain is off.

## Icons

Badges are drawn at 72 points and shown larger on the map (about 0.88, and 1.05 for Catholic sites and chapels), with a thick cream halo so they read on hillshade. Catholic sites and chapels are a map pin and a cross. Chapel is cream with a burgundy cross. Catholic is burgundy with a cream cross. Landmark is a terracotta hexagon. Viewpoint is a triangle. Shrine and trailhead are diamonds. Worship and water are circles. Museum and parking are rounded rectangles. Trail difficulty is not in the pack, so there is no difficulty glyph yet.

## Terrain

Hillshade and 100 m contours ship in the app. They are derived from Mapzen Terrain Tiles on AWS Open Data, Terrarium RGB elevation, licensed CC BY 4.0 and ODbL. Elevation inputs include USGS and the other open sources named by that dataset. The phone does not request those tiles. `pipeline/pilgrim/terrain.py` writes two archives for the Northern New Mexico bbox:

| Archive | What | Zooms | Bytes |
| --- | --- | --- | --- |
| `northern-new-mexico-hillshade.pmtiles` | JPEG hillshade, warm gray | 7–11 | 2636117 |
| `northern-new-mexico-contours.pmtiles` | vector contours, 100 m, `elev` in meters | 10–11 | 2337002 |

The camera is zoom 15, so both overzoom from 11. Offline use is the copy in the app bundle. Turning Terrain off hides both layers and leaves land, trails, and places. OpenFreeMap is OpenStreetMap vector tiles (ODbL), not terrain, and stays optional. A trail elevation profile is not in this build. Trails in the pack are 2D. The trail sheet draws the 2D line. A single way, or a chain of ways with no junction, shows its measured length. A branched network hides the summed length and says the record is a network of ways, not one trail. Surface and difficulty are not in the pack.

**Still to do.** Per-pin “Hours not in the pack” captions (a status line and the sheet carry that sentence now, because a caption on every pin would cover the plaza). Supercluster styling beyond the zoom-13 split. Food and rest rows when a later extract has those amenities. Map glyphs beyond Latin-1. A few pixels of cream between the app-icon path and the cross at home-screen size. Trail difficulty if a source actually has it.
