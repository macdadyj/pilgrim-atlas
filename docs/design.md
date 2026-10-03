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
| Support | Subheadline or body, `#3A3228` | Land sentence, closures, hours note, search subtitle |
| Status | Caption | One capsule under the chips |
| Attribution | Caption 2, `#1C1915` on cream | “© OpenStreetMap contributors” |
| Footnote | Footnote, `#3A3228` | License notes |

`#3A3228` on white is about 10:1. Do not use system secondary for text that has to be read in daylight.

## Color

Ground is `#EFE6D6`. Ink is `#1C1915`. Cream halo is `#F4EFE4`. Brown support text is `#3A3228`. Catholic shield is `#8C2F39`.

Land fills are painted at 0.85 opacity on the cream so the legend swatch (the same hex at 0.85 on the same cream) matches the map. Private land is the light tan `#C4B49A` with a `#4A4036` outline. Forest is green `#1F7A3A`, national park blue `#1F6F8A`, tribal purple `#7A3E8C`, BLM gold `#C48A12`, State Trust orange `#E06A1F`. Those stay apart after the blend. Every kind the style paints has a legend row.

Trail lines are a cream casing (`#F4EFE4`, width about 3 to 7 by zoom) and a `#6B4F3A` core (about 1.6 to 4). The legend chip is that brown.

## Spacing

8 points between chips and between card rows. 12 points of card padding. 16 points of screen padding. The nearby card scrolls and stays near 40 percent of the screen height. Map controls are at least 44 points.

## Map

Offline pack layers stay on. OpenFreeMap streets are optional and do not replace land, trails, or places. One status capsule. Copyright sits at the lower leading edge, not next to the buttons.

Place symbols are drawn from the phone’s copy of the pack, not from a second icon font in the tiles. Catholic worship and chapels, cathedrals, basilicas, and santuarios use a shield and a cross, drawn above other pins and allowed to overlap. Other roles use a circle, diamond, or rounded square, an SF Symbol, and a cream halo. Ordinary landmarks do not overlap, so a gallery does not paint over the basilica. Labels use a short name (`Cathedral Basilica`); the sheet keeps the full name. Catholic labels are not optional. Other labels can drop when they collide. Points cluster below zoom 13 and separate at the plaza zoom.

Selected place: a burgundy ring.

## Chips

Catholic sites, Churches and shrines, Trails, Public land, Parks, Food and rest, Open now. No chip means the full map. Place chips intersect. Trails leave the map when any chip is on and Trails is off. Public land is forest, BLM, national park, other federal, local protected areas, and Albuquerque Open Space. State Trust is not public land. Parks are national parks, Albuquerque Open Space, and local protected areas whose name contains “park.” A place named “park” is not a park polygon. Food and rest stays disabled while the pack has no cafe, restaurant, fast food, or toilets. Open now uses a parsed weekday clock in the device time zone. Places with no hours stay visible. Places whose hours are not a single clock stay visible and say so. A reset clears chips only. It does not turn lot lines on, turn online tiles off, or clear the search field.

Search covers places, trails, towns, and land names, then applies the same chips. The nearby card and map taps use that predicate too.

## Sheets

The bar title is the short kind, or the trail name up to two lines. The first row is the full name, wrapping. Denomination reads “Roman Catholic,” not `roman_catholic`. Wikipedia links use the article title, not an `en:` prefix. Empty hours are one line, “No visitor hours in the pack,” not a section that only says the pack is empty. A single clock can say “Open now” or “Closed now.” Conflicting or unparsed hours are one row per range plus “Hours listed, not a single clock.”

More map options holds lot lines, online tiles, “Hide places with no hours,” and Terrain. The layers button shows a badge only when one of those differs from the default.

## Icons

SF Symbols drawn into a 72-point badge at runtime, shown near 44 points on the map and at 44 points in the legend. Categories: Catholic shield and cross, chapel shield and cross, other worship, shrine or statue, viewpoint, museum, parking, water, trailhead, landmark. Trail difficulty is not in the pack, so there is no difficulty glyph yet.

## Planned

**Terrain.** The Terrain toggle is in the app and tells the truth: hillshade and contours are not in this pack. OpenFreeMap is OpenStreetMap vector tiles (ODbL). It is not a terrain service, and it is not licensed here as an offline elevation copy. OpenTopoMap’s rendered tiles are not a good offline source: the project’s tile policy does not allow bulk downloading their tiles for redistribution. The pack should grow its own hillshade and contours from open elevation, USGS 3DEP or Copernicus GLO-30, written into the Northern New Mexico PMTiles with attribution. AWS Terrain Tiles and Protomaps are build inputs to check for license and coverage before a pipeline job, not something to ship by hotlinking. A trail elevation profile waits on that 3D geometry. Trails in the pack are 2D.

**Still to do.** Per-pin “Hours not in the pack” captions (a status line and the sheet carry that sentence now, because a caption on every pin would cover the plaza). Supercluster styling beyond the zoom-13 split. Food and rest rows when a later extract has those amenities. Map glyphs beyond Latin-1. A few pixels of cream between the app-icon path and the cross at home-screen size. Trail difficulty if a source actually has it.
