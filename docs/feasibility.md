# Pilgrim Atlas feasibility

**Phase 1 only.** This report judges whether a free, open-source iOS exploring app can be built from public data. It does not design the Xcode project. It is not legal advice. A short review before any parcel file is shipped would still be wise.

Research date: 3 October 2026. Claims below were checked against the linked primary pages. Where a portal is ambiguous, the confidence is marked down.

Working name **Pilgrim Atlas** should stay. It says pilgrimage and map without pretending to be onX. Do not rename the repository. Do not put "OpenStreetMap" in the product name; that mark belongs to the OpenStreetMap Foundation ([copyright page](https://www.openstreetmap.org/copyright)).

The code license stays MIT. Data licenses are separate and are listed in [Licenses](#licenses).

## Recommendation

**Go, for a northern New Mexico exploring app. No-go, for an onX-style private-owner app.**

Confidence in that split: **high**.

What a phone can honestly do, offline, with free data:

- Show GPS position.
- Say which public agency or trust manages the ground under that point, when a public dataset covers it.
- Show that New Mexico State Trust land is not federal public land and that recreation there generally requires a State Land Office permit.
- Show Catholic and other places of worship, pilgrimage sites, and hiking routes that OpenStreetMap actually has.
- Attach a source and a date to every fact.
- Refuse to invent a private owner's name, a legal boundary, or permission to enter.

What it cannot honestly do:

- Name the private owner of an arbitrary parcel and redistribute that name.
- Tell the user they may cross a fence because a polygon says "private" or because no polygon is drawn.
- Show Mass or confession times for more than a handful of churches. On 3 October 2026, a New Mexico query found those fields almost empty.
- Use public Nominatim, or `tile.openstreetmap.org`, as the app's geocoder or offline map.

| Question | Verdict | Confidence |
| --- | --- | --- |
| Offline map, GPS, and on-device privacy, with no server of our own | Go | High |
| Public-land manager from PAD-US, BLM surface management, USFS ownership class, and NPS boundaries | Go, with strong disclaimers | High |
| New Mexico State Trust land, shown as permit-required trust land rather than "public" | Go | High |
| Catholic and other landmarks from OpenStreetMap, plus Wikipedia and Wikidata links | Go, coverage is uneven | High on churches existing; medium on completeness |
| Hiking routes from OpenStreetMap | Go, access tags are incomplete | Medium |
| Albuquerque parcel outlines and city open space, without owner names | Conditional go | Medium |
| Santa Fe parcel polygons or owner names inside the app | No-go until the county says yes in writing | High that today's terms forbid it |
| Private owner names, statewide or national | No-go | High |
| Mass and confession times as a feature people can trust | No-go as a directory; show an OSM tag only when one exists | High |
| Public Nominatim, or OSMF raster tiles, in the app | No-go | High |
| Treating any line as a survey, or as permission to enter | No-go | High |

### Decisions Jon needs to make

1. **Ship without private owner names.** Recommended: yes. The alternative is waiting on written county permission that may never allow an open-source redistribution.
2. **First map: Albuquerque, Santa Fe, and northern New Mexico** (Española, Chimayó, Los Alamos, Taos, and the public land between them). Recommended: yes.
3. **Albuquerque city parcel outlines and Open Space**, under the City's disclaimer, with no owner names. Recommended: yes for Open Space and trails; parcels only as lot lines and addresses.
4. **Santa Fe parcels.** Recommended: link out to the county or city map. Do not copy them.
5. **Show every place of worship, and highlight Catholic ones,** including a Ruthenian/Byzantine Catholic tag when it exists. A Catholic-only map would hide neighbors and still miss chapels tagged another way.
6. **Accept missing Mass and confession times** in the first build. A hand-kept note, with the date it was checked, can come later. Do not scrape parish sites.
7. **Keep the name Pilgrim Atlas.**

## What the product is asking

The useful question is: where am I, who manages this ground, and what must I not assume?

A good answer looks like this:

- "Bureau of Land Management surface. Not a survey. Check the local office before you rely on it."
- "Inside a national-forest administrative boundary, but mapped as non-Forest Service. Do not assume you may enter."
- "New Mexico State Trust land. Not federal public land. Recreational access generally needs a State Land Office permit, and the permit does not open every tract."
- "No open dataset covers this point. It may be private, tribal, or missing. This app is not permission to enter."

A bad answer looks like onX: a person's name, a lot line treated as a fence, and a green "you can go here."

Landmark cards should show only facts that have a source: name, description, address, hours, access, parking, photos, links, wheelchair tags. Mass times appear only when a source actually has them. Loretto Chapel is the worked example. Wikipedia describes it as a former Roman Catholic church, now a privately owned museum and wedding chapel, at 207 Old Santa Fe Trail ([Loretto Chapel](https://en.wikipedia.org/wiki/Loretto_Chapel)). In OpenStreetMap it is `tourism=museum` with Wikidata `Q2956557`, not `amenity=place_of_worship`, and its `opening_hours` value contains two different schedules. A filter that only looks for `denomination=roman_catholic` will miss it. The card should say the hours came from OSM, show the extract date, and not pretend the two schedules agree.

El Santuario de Chimayó and the Cathedral Basilica of St. Francis of Assisi are tagged as Catholic places of worship. That is enough to pin them on the map. It is not a Mass schedule.

## Sources

### OpenStreetMap and Overpass

OSM data is under the Open Database License (ODbL), from the OpenStreetMap Foundation. You may copy, distribute, and adapt it if you credit OpenStreetMap and its contributors. If you alter or build upon the data, you distribute the result only under the same license ([copyright](https://www.openstreetmap.org/copyright), [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)).

For this app that means:

- A GeoPackage or SQLite extract shipped in the app is a database. It stays ODbL. It does not become MIT.
- The Swift code stays MIT. Keep code and data in separate files, and say so.
- The map attribution has to be visible on the map, in the corner, without a tap. Preferred form: "© OpenStreetMap contributors", with the license explained on an in-app licenses screen that works offline. A link alone is a weak way to satisfy attribution when the phone has no signal ([OSMF attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines), [community attribution advice](https://wiki.openstreetmap.org/wiki/Community_attribution_advice)).

Places of worship use `amenity=place_of_worship`, usually with `religion=*` and `denomination=*`. Useful companions are `opening_hours`, `service_times`, `wheelchair`, `access`, and `wikipedia` ([tag page](https://wiki.openstreetmap.org/wiki/Tag:amenity%3Dplace_of_worship)). `service_times` is in use for worship times that differ from visitor hours ([key](https://wiki.openstreetmap.org/wiki/Key:service_times)). `mass_times` is only proposed ([key](https://wiki.openstreetmap.org/wiki/Key:mass_times)). `confession_times` is an undefined key ([key](https://wiki.openstreetmap.org/wiki/Key:confession_times)). `access=*` is legal access as signed or regulated, not a guess about how people actually behave ([key](https://wiki.openstreetmap.org/wiki/Key:access)). A missing access tag is not permission.

**Coverage check, 3 October 2026**, one read-only query to the public Overpass instance, tags only, New Mexico bounding box (31.3, −109.05, 37.0, −103.0), `amenity=place_of_worship` and a denomination matching `catholic` or `byzantine`:

| | Count |
| --- | --- |
| Objects | 512 |
| `denomination=catholic` | 260 |
| `denomination=roman_catholic` | 249 |
| `ruthenian_catholic` | 1 |
| `anglican_catholic` (not Roman Catholic) | 1 |
| mistyped `catholic1` | 1 |
| `opening_hours` | 3 |
| `service_times` | 10 |
| `mass_times` | 0 |
| `confession_times` | 0 |
| any address tag | 316 |
| website | 139 |
| Wikidata | 23 |
| Wikipedia | 10 |
| wheelchair | 1 |

No denomination value was a Byzantine-specific tag except that one Ruthenian Catholic church. Byzantine Catholic parishes tagged only as `catholic`, or not tagged, will be missed until someone maps them.

Same day, northern box (34.8, −107.3, 37.05, −104.7), covering Albuquerque through Taos and east to about Las Vegas:

- 140 places of worship matched the same denomination filter: 91 `roman_catholic`, 47 `catholic`, 1 `ruthenian_catholic`, 1 `anglican_catholic`.
- 358 relations tagged `route=hiking`.
- 0 objects tagged `place_of_worship=wayside_shrine`. Shrines can still exist under other tags. Chimayó is a place of worship, not that shrine tag.

These counts will move as volunteers edit. They are a snapshot, not a promise. One church in the state extract, Saint Edwin, stores confession and Mass inside `service_times`. The model can hold the fact. The map almost never has it.

**Do not call Overpass from the app.** The main public instance asks occasional users to stay under 10,000 queries and 1 GB a day, and regular apps to stay far below that, around 100 queries and 10 MB a day across all users. It also says the server is overloaded ([Overpass wiki](https://wiki.openstreetmap.org/wiki/Overpass_API)). The pipeline should use a regional extract instead.

Geofabrik's free New Mexico extract is ODbL. On 3 October 2026 the page listed `new-mexico-latest.osm.pbf` at **130 MB**, containing OSM data up to **2026-10-02T20:21:34Z**. Public extracts omit contributor user ids ([New Mexico extract](https://download.geofabrik.de/north-america/us/new-mexico.html), [Geofabrik license note](https://www.geofabrik.de/en/data/download.html)). That file is the right input for a local pipeline. It is small enough to process on a Mac.

Trails in OSM are `route=hiking` relations plus ways such as `highway=path`, `footway`, and `track`. `access`, `foot`, and `motor_vehicle` say who may use them when a mapper filled them in. They are often blank. A track drawn across private land is a known failure mode. The app should draw the trail and still refuse to say "you may leave the trail."

### Wikidata, Wikipedia, and Commons

- **Wikidata** structured data in the main entity namespaces is CC0 ([Wikidata:Licensing](https://www.wikidata.org/wiki/Wikidata:Licensing)). Good for identifiers, coordinates, and "instance of." It is not a Mass schedule.
- **English Wikipedia** text is CC BY-SA 4.0 (and some older text is also under the GFDL) ([copyright FAQ](https://en.wikipedia.org/wiki/Wikipedia:Copyright_FAQ), [dump legal page](https://dumps.wikimedia.org/legal.html)). Link to the article. Do not paste the article into the app. A short quotation, if any, needs attribution, and a rewritten guide that copies the substance can drag share-alike onto that text. Keep that text out of the MIT source tree.
- **Wikimedia Commons** media are licensed per file. Commons accepts public domain, CC0, CC BY, and CC BY-SA. It rejects CC BY-NC and CC BY-ND ([Commons:Licensing](https://commons.wikimedia.org/wiki/Commons:Licensing)). Ship a photo only when that file's license allows it, and keep the author, license, and title with the file. The default card should link out. Loading Commons at view time also tells Wikimedia the phone's IP.

### Federal and trust land

These layers answer "who manages this," not "who is the private owner," and not "this line is the fence."

**PAD-US 4.1** (USGS Gap Analysis Project) is the national inventory of public and other protected areas: fee ownership, designations, easements, proclamations, and marine areas. Download is by nation or by state ([download page](https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-data-download)). The USGS record for PAD-US 4 is marked **CC0 1.0**. The download page's current file is 4.1 and uses the same DOI, `10.5066/P96WBCHS` ([data record](https://www.usgs.gov/data/protected-areas-database-united-states-pad-us-4)). Cite USGS anyway.

Fields that matter: `Mang_Name` and `Mang_Type` (manager), `Own_Name` and `Own_Type` (holding agency, not a private person), `Pub_Access` (open, restricted, closed, or unknown), and `GAP_Sts` (a biodiversity-management code, not a hiking permit). USGS says public-access values have local-park gaps, and that comparing two PAD-US versions is a poor way to detect real acquisitions ([web services](https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-web-services), [data manual](https://www.usgs.gov/programs/gap-analysis-project/pad-us-data-manual)). `Own_Type` includes federal, tribal, state, and private protected lands. Tribal land in this layer is not an invitation to hike.

**BLM Surface Management Agency** shows which federal agency has surface jurisdiction. BLM's own text says the data are public domain, are not legal documents or surveys, and do not carry land-ownership details. Fees: none ([SMA item info](https://gis.blm.gov/arcgis/rest/services/lands/BLM_Natl_SMA_Cached_without_PriUnk/MapServer/info/iteminfo), [BLM GIS page](https://www.blm.gov/services/geospatial/GISData)). A separate view includes a "Private or Unknown" class. That class has no owner name. Hub entry point: [BLM National SMA polygons](https://gbp-blm-egis.hub.arcgis.com/datasets/blm-national-sma-surface-management-agency-area-polygons).

**USFS.** The administrative forest boundary is the wrong layer for "am I on Forest Service land." It encloses private and other inholdings. The clearinghouse publishes a simplified surface-ownership set for general mapping (listed at about 71 MB as a geodatabase and 164 MB as a shapefile when checked) and says it is for read-only display and analysis ([FSGeodata](https://data.fs.usda.gov/geodata/edw/datasets.php?xmlKeyword=basic+ownership)). The Basic Ownership map service classifies land as USDA Forest Service versus non-Forest Service ([service](https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_BasicOwnership_01/MapServer/0)). Use that classification inside the forest. Still not a survey.

**NPS.** The Land Resources boundary and tract service says land-status maps are the official acreage record inside a park's authorized boundary and are still not survey quality and not for engineering or legal use. The boundary polygon is the legislated line. NPS does not necessarily own every parcel inside it, and it may own parcels outside it. Tract polygons are required for a fuller picture. NPS points downloads at [IRMA](https://irma.nps.gov) ([feature service description](https://services1.arcgis.com/fBc8EJBxQRMcHlei/ArcGIS/rest/services/NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer)).

**Census TIGER/Line.** Free to obtain and free of U.S. copyright as a work of the federal government (17 U.S.C. § 105). The Bureau asks for a citation. Boundaries are for statistical collection only. They are not jurisdiction, ownership, or a legal land description. "TIGER/Line" is a Census trademark and must not be part of the product name ([2025 technical documentation](https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2025/TGRSHP2025_TechDoc.pdf)). TIGER is useful for place names, counties, and roads as a gazetteer. It is not a land-status layer.

**New Mexico State Trust land.** This is the layer northern New Mexico cannot skip. Trust land is checkerboarded through the region people want to walk. The State Land Office says these are trust lands for named beneficiaries, not public lands in the ordinary sense ([FAQ](https://www.nmstatelands.org/resources/resources-faqs/)). Rule 19.2.19.9 NMAC prohibits recreational access without a recreational access permit or other written authorization ([rule PDF](https://www.nmstatelands.org/wp-content/uploads/2019/10/Recreational-Access-Permit-10.17.2019.pdf)). On 3 October 2026 the outdoor-recreation page described a **$35** annual permit and said fees support public schools ([outdoor recreation](https://www.nmstatelands.org/outdoorrecreation/)). The permit does not open private land, federal land, or trust tracts that are leased, withdrawn, or closed. The app must say that. It must not sell permits or collect an application.

SLO publishes trust-land shapefiles for download, dissolved by surface, subsurface, or both ([download index](https://mapservice.nmstatelands.org/GISDataDownloads/), [metadata](https://mapservice.nmstatelands.org/GISDataDownloads/MetaData/SLO_STLCombined_Own_Metadata.htm)). The FAQ says this cadastre is posted for download ([GIS FAQ](https://www.nmstatelands.org/maps-gis/gis-faqs/)). The metadata disclaims accuracy, reliability, and completeness, and says the data may change without notice. There is no CC0-style grant on that page. Cite the State Land Office and show the disclaimer. Confidence that a downloaded public shapefile may be redrawn inside the app with attribution: **medium**. Confidence that the access rule is "permit required, and not every tract": **high**.

### Parcels and owner names

There is no free, national, redistributable private-owner layer. Owner names are a county assessor product. States differ, and "I can see it in a web map" is not "I may ship it in an open-source app."

**New Mexico, state.** The Taxation and Revenue Department says it does **not** distribute or publish county real-property parcel data. People who want a specific property are told to contact that county assessor. What TRD does publish (gross-receipts and property-tax **districts**) is described as public domain, citation expected, reference only, and not a substitute for the local boundary ([data download](https://www.tax.newmexico.gov/businesses/geographic-information-system-gis/data-download/)). Those districts are not ownership.

A statewide parcel service hosted for agency use carries a harder line: do not share the service URL without asking the TRD GIS coordinator, and TRD / Property Tax Division will not supply the data to any private-sector entity ([Bernalillo 2025 item info](https://gis.ose.nm.gov/server_s/rest/services/Parcels/County_Parcels_2025/MapServer/0/iteminfo), as an example of that layer). **Do not use that service.** The state parcel mapping manual also says tax parcels are not a land survey and not a legal record of boundaries ([policy manual](https://www.tax.newmexico.gov/businesses/wp-content/uploads/sites/4/2021/02/NMMapping_Policy_Manual_Final_2021.pdf)).

**Bernalillo County (Albuquerque).** The Assessor's GIS exists so staff and the public can research parcels, and the public map is tied to the assessment system ([GIS page](https://www.bernco.gov/assessor/geographic-information-system-gis/), [maps](https://www.bernco.gov/assessor/assessors-gis-maps/)). This report did not find a license that allows republishing owner names. A city map layer of assessor parcels says ownership is refreshed twice a year and tells users to contact the Assessor for current ownership. **Do not ship Bernalillo owner names.**

**City of Albuquerque** is the one local geometry source with a public download and written terms:

- [Parcel shapefile](https://www.cabq.gov/gis/geographic-information-systems-data), citywide. Metadata: lot lines as the City determines them, attributes include address and legal description, refreshed daily. Owner name is not what that metadata describes ([metadata](https://www.cabq.gov/gis/geographic-information-systems-metadata)).
- Open Space boundaries, described as **only areas accessible to the public**, plus Open Space trails, parks, and bikeways.
- Terms: data is "as is," the City disclaims accuracy, and a derivative app must show a specific disclaimer naming `www.cabq.gov`. The City may require the user to stop distributing the data ([disclaimer](https://www.cabq.gov/abq-data/abq-data-disclaimer-1)).

That is a conditional go for lot lines, addresses, and especially Open Space. It is not a survey and not owner names. Confidence: **medium**.

**Santa Fe County and City of Santa Fe.** The county's interactive-map disclaimer says the datasets are reference only, not a substitute for recorded deeds or plats ([disclaimer](https://www.santafecountynm.gov/growth-management/gis/gisconfirm)). The Assessor's 2025 GIS data-request form is stricter: no part of the GIS data may be copied, reproduced, or transmitted, including posting on the internet, without prior written permission. It also says the data is not a survey ([request form](https://www.santafecountynm.gov/assessor/uploads/documents/2025_GIS_Data_Request.pdf)).

The City's public download page is a gallery of PDF maps (parks, open space, trails, historic districts) with a no-warranty disclaimer ([map gallery](https://santafenm.gov/information-technology-telecommunications/gis/map-gallery)). The host `gis.santafenm.gov` also serves parcel layers whose display field is `OwnerName`. A field sitting on a public server is not permission to copy it into Pilgrim Atlas. **No-go for Santa Fe parcels and owner names** until there is a written yes. Link to the official map instead. Do not trace the city's PDF trail maps into the app; that would copy their cartography. Use OSM trails, and link the PDF for the person who wants the city's sheet.

**How this varies.** Massachusetts is a useful contrast, not a template. MassGIS publishes a statewide property-tax parcel dataset that includes `OWNER1`, and it still says assessors' maps are not the authoritative boundary. The authoritative record is the registry of deeds, and a legal map comes from a surveyor. Statewide files are requested from MassGIS rather than dropped on an anonymous open dump ([MassGIS parcels](https://www.mass.gov/info-details/massgis-data-property-tax-parcels)). New Mexico's state tax department publishes no county parcels at all. Some other counties charge a fee or forbid commercial redistribution. This report did not inventory all 50 states. The honest rule is: **one county, one reading, and owner names stay out until that reading is a clear grant.** Even a clear grant would not make the name a right to enter, and it would put private names into an open-source data file, which this project should not do by default.

Commercial parcel vendors exist. They are out of scope. No paid data.

### Map tiles and offline use

`tile.openstreetmap.org` is donated capacity for the OSM website. Bulk download and offline prefetch are prohibited. "Save this region" against that server is not allowed ([tile usage policy](https://operations.osmfoundation.org/policies/tiles/)). Do not use it.

**OpenFreeMap** is a free public vector-tile service for OSM data. The project says there is no API key, no registration, no cookie, and no stated cap on views. Attribution is required. The software is MIT; the map data is OSM. It does not offer geocoding, routing, or satellite imagery. There is no SLA. The operator funds servers with donations ([openfreemap.org](https://openfreemap.org/), [quick start](https://openfreemap.org/quick_start/)). Fine as an optional online basemap. Not fine as the only map, because the service can go away, and each tile request reveals the phone's approximate location to that host.

**Protomaps PMTiles** is the offline format to use. The PMTiles specification is public domain (CC0 where that applies). Reference code is BSD-3. The Protomaps basemap tiles are an ODbL produced work, so OSM attribution still applies ([downloads](https://docs.protomaps.com/basemaps/downloads/), [license notes](https://github.com/protomaps/basemaps)). A full-planet daily build is about **129 GiB** (the 3 October 2026 build was listed at 129.03 GiB) ([builds](https://maps.protomaps.com/builds/)). Do not download the planet for this MVP. Render a regional vector tileset from the 130 MB New Mexico PBF, or cut a bbox only after a planet file is already in hand. Protomaps asks people not to hotlink the build bucket.

**MapLibre Native for iOS** is BSD-2-Clause ([project](https://github.com/maplibre/maplibre-native)). Since iOS library 6.10.0, a style can read `pmtiles://file://` from the app bundle, which is the offline path. The PMTiles source does not use the older "download an offline pack from the network" API ([PMTiles docs](https://maplibre.org/maplibre-native/ios/latest/documentation/maplibre-native-for-ios/pmtiles/)). Ship the file. Do not prefetch someone else's tiles.

No Mapbox. No Google. No Apple basemap as the data source. Core Location for the GPS dot is fine; it stays on the phone.

### Geocoding

Public Nominatim exists to power the search box on openstreetmap.org. The policy is an absolute maximum of **1 request per second for the whole app**, not per user. Autocomplete is forbidden. Systematic queries and bulk geocoding are forbidden. Periodic requests from apps count as bulk. Apps must be able to switch away without an app-store update. The policy can change without notice ([Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/)).

Reverse-geocoding the GPS track would blow that limit as soon as more than a few people used the app, and it would send location to OSMF. **Do not call Nominatim from the app.** Search should be a local index of names from the OSM extract and TIGER places. If a typed query misses, say so. Do not fall through to the public API.

### Parish, Mass, and confession times

Feasible as an occasional OSM field. Not feasible as a schedule people can trust.

Allowed:

- Show `opening_hours`, `service_times`, `mass_times`, or `confession_times` when the OSM object has them, labeled as OSM, with the extract date, and a sentence that schedules change and the tag may be wrong. In the 3 October snapshot that is 12 New Mexico objects with any of those time fields, out of 512 Catholic-tagged places. One of the 12 has both visitor hours and service times.
- Link a `website` or Wikipedia article when the tag exists (139 websites, 10 Wikipedia links in that snapshot).
- Later, a tiny volunteer file in the repo: one row per fact, a human-readable source, the date a person checked it, and no bulk copy. Jon could type the Cathedral's Sunday times after reading the bulletin himself. That does not scale, and it goes stale.

Not allowed:

- Scraping MassTimes, diocesan directories, or parish sites. Terms differ and were not reviewed one by one because the project rule is not to scrape. A schedule copied off a parish site is not open data.
- Inferring a Sunday time because "most parishes have one."
- Presenting visitor hours at Loretto as Mass times. It is a museum.

Accuracy limit: even the 10 `service_times` values are only as good as the last mapper. One of them is just `Su`. Show the raw value. Do not tidy it into a confident "Sunday Mass."

## Legal and safety

Put these in the first-run screen and on every land card. They are part of the product, not a footer.

**Trespass.** The app does not grant access. Private land, Pueblo and other tribal land, leased or closed trust land, and posted trails are not opened by a polygon. If the dataset is silent, the answer is "unknown," not "probably fine."

**Not a survey.** PAD-US, BLM SMA, USFS ownership, NPS boundaries, SLO trust land, TIGER, city parcels, and OSM ways are all generalized. GPS error in a canyon or under a portal adds more. None of them replace a recorded plat or a surveyor. The New Mexico mapping manual says the same about tax parcels.

**Freshness.** Every layer needs a visible date: OSM extract timestamp, PAD-US version, SLO file revision, city refresh note. Closures, fire restrictions, and seasonal gates are not in these files. This report did not find a keyless open feed that is safe to depend on for live closures. Do not scrape agency alert pages. The card should say closures are not shown.

**Trust land and tribal land.** State trust land gets its own color and the permit warning. Tribal and Pueblo land gets its own color and "access is not implied." Do not style either as generic public land.

**Privacy.** Location stays on the device. Boundary tests run on local files. No account, no analytics, no location sent to a server this project runs, because this project runs no server. Optional online tiles are off by default. If a later build turns them on, the tile host sees the IP address and the tiles requested, which is an approximate location. Say that before the first request.

**Licenses.** MIT for code only. ODbL for anything derived from OSM, including a Protomaps-style basemap and the landmark database. CC0 for PAD-US as marked by USGS, and for Wikidata facts. City of Albuquerque disclaimer text if those shapefiles are included. SLO, BLM, USFS, NPS, and Census citations and their "not a legal document" lines. Commons photos keep their own licenses. Do not relicense code to match the data, and do not put data files under MIT.

**Names of private people.** Out of the app even if a future county letter allows geometry. A public-records lookup on a county website can stay a link.

## Architecture for a later build

Not this phase. When the MVP is built on a Mac:

- **SwiftUI** for the screens. **MapLibre Native** for the map (UIKit underneath; a thin SwiftUI wrapper is enough). BSD-2-Clause.
- **On-device files only** for the core map: a regional PMTiles basemap, plus a GeoPackage or SQLite database of land polygons and places. SQLite itself is public domain. GeoPackage is the OGC container.
- **A pipeline in the repo**, run locally, with no API keys and no paid services. Inputs: Geofabrik New Mexico PBF, PAD-US New Mexico extract, BLM SMA clipped to the state, USFS basic ownership clipped to the state, NPS boundaries clipped to the state, SLO surface trust land, City of Albuquerque open-space and parcel shapefiles, and TIGER place names if the OSM names are thin. Outputs: one northern New Mexico pack, a manifest of source dates, and a licenses file that the app can show offline.
- **No server.** No tile proxy. No account database. Packs can ship inside a development build. A GitHub release asset is a later distribution choice, still not an application server. Measure the pack size before assuming it fits comfortably on a phone. The state PBF is 130 MB; a styled regional PMTiles file will be larger than that and far smaller than the 129 GiB planet. The number has to be measured, not guessed.
- **Search** is a local index. **GPS** is Core Location. Tapping the map runs a point-in-polygon query on the device and returns the cautious sentence from the [product section](#what-the-product-is-asking).
- **Online OpenFreeMap** only as an explicit opt-in when no pack is installed, with the privacy sentence above.

Suggested draw order when polygons overlap, first match wins:

1. Tribal or Pueblo category from PAD-US.
2. NPS unit, with the legislated-boundary warning.
3. USFS ownership class, and a different warning when the point is inside the administrative forest but classed non-Forest Service.
4. BLM surface.
5. SLO surface trust.
6. Albuquerque Open Space, if included.
7. Otherwise unknown. Do not color unknown land as enterable.

## MVP

Santa Fe, Albuquerque, and northern New Mexico. One pack. Roughly the box used in the coverage check: from Albuquerque north through Santa Fe, Española, Chimayó, Los Alamos, and Taos, and east far enough to include Las Vegas, New Mexico.

In the first build:

- GPS dot and offline basemap.
- Land card with manager, trust-land warning, and "unknown means do not assume."
- Places of worship and `tourism` landmarks from OSM, with a Catholic highlight that includes `roman_catholic`, `catholic`, `greek_catholic`, `ruthenian_catholic`, and explicit Byzantine tags, and excludes `anglican_catholic`.
- A separate query so Loretto-style museums and named shrines are not dropped.
- Hiking routes, drawn as routes, not as permission.
- Place card: name, OSM address tags, website, wheelchair, access, Wikipedia or Wikidata link, raw hours if present, source, extract date.
- Albuquerque Open Space, and city parcel lines without owner names, if the City disclaimer is shown.
- Licenses and the trespass / survey / freshness text, available offline.
- Local name search.

Out of the first build:

- Owner names.
- Santa Fe parcel copies.
- Nominatim and OSMF tiles.
- A Mass-time directory.
- Live closures.
- The rest of the United States.
- Any server, key, or paid feed.

Worked pins for the first demo, all of which the source check already found: Santa Fe Plaza as a place in OSM if tagged (confirm during the build; do not invent the tags), Loretto Chapel, the Cathedral Basilica of St. Francis of Assisi, San Miguel, El Santuario de Chimayó, and at least one USFS or BLM tract outside town so the land card is doing real work.

## Roadmap

1. **This report.** Stop here for Phase 1.
2. **Pipeline on a Mac.** Produce the northern pack. Record byte size, source dates, and licenses. Drop any input whose terms are not a clear go.
3. **Map and GPS.** Offline PMTiles, location dot, attribution, licenses screen.
4. **Land card.** The overlap order above, including trust land and tribal land.
5. **Landmarks and the Catholic highlight.** Include the Loretto-style miss.
6. **Trails.** OSM hiking relations, with access tags shown only when present.
7. **Albuquerque Open Space and parcel lines.** City disclaimer in the licenses screen.
8. **Only then** consider a volunteer schedule note, more counties, or a written ask to Santa Fe County. Each new county repeats the license reading. There is no national shortcut.

## Risks

- **Someone treats the map as permission.** The wording has to stay dull and specific. "BLM" is not "walk anywhere inside the green."
- **Boundary error.** A road-width miss near a fence is enough to put someone on the wrong side. GPS in the Sangre de Cristo is worse than GPS on the Plaza.
- **Trust-land checkerboard.** Coloring it like BLM would be the serious mistake in this region.
- **Tribal land.** A wrong "public" color is both a trespass risk and a disrespect. Prefer silence to a guess.
- **OSM worship data.** Hundreds of churches are mapped. Hours, confession, wheelchair access, and Byzantine Catholic identity mostly are not. Tags lie sometimes, as Loretto's doubled hours show.
- **Trail access tags are sparse.** 358 hiking relations in the northern box does not mean 358 trails with a legal access review.
- **OpenFreeMap can disappear,** and OSMF tiles cannot replace it. The offline pack is the mitigation.
- **County terms can tighten.** Albuquerque's disclaimer already lets the City tell redistributors to stop. Build the pack so that layer can be removed without a rewrite.
- **Share-alike mix-up.** An OSM database committed beside MIT code needs its own license file. A future patch must not "clean up" by deleting that notice.
- **Stale schedules.** A hand-entered Mass time will eventually be wrong. Date it or do not ship it.
- **Pack size is unmeasured.** If a full-detail northern PMTiles file is too large, lower the max zoom outside towns rather than adding a server.
- **This report is not a survey of every county in the United States.** Expanding past the two counties above requires reading that county's terms again.

## Licenses

| Piece | License or terms | What the app must do |
| --- | --- | --- |
| Swift code in this repo | MIT, already in `LICENSE` | Leave it MIT |
| OpenStreetMap extracts, landmarks, trails, Protomaps basemap | ODbL | Credit OSM on the map; ship the ODbL notice offline; keep the database under ODbL |
| PAD-US | CC0 on the USGS record, plus a requested citation | Cite USGS; show the version |
| BLM SMA | Public domain, agency disclaimer | Cite BLM; say it is not a survey |
| USFS ownership | Public download, read-only, not a legal document | Cite USFS; do not use the administrative outline as ownership |
| NPS boundaries | Public download, not survey or legal use | Cite NPS; distinguish boundary from fee title |
| TIGER/Line | U.S. government work, citation requested | Cite Census; keep the trademark out of the name |
| SLO trust land | Posted for download; accuracy disclaimer; no CC grant found | Cite SLO; show the disclaimer; explain the permit rule |
| City of Albuquerque GIS | City terms, required disclaimer, revocable | Include their disclaimer if the data is in the app |
| Santa Fe assessor GIS | No copy or internet posting without written permission | Do not include |
| NM TRD county parcel service | Not for private-sector redistribution | Do not include |
| Wikidata facts | CC0 | No special notice required; citing is still good |
| Wikipedia text | CC BY-SA 4.0 | Link, do not copy the article into the repo |
| Commons photos | Per file | Ship only free licenses, with author and license |
| MapLibre Native | BSD-2-Clause | Keep the license notice with the binary |
| Nominatim and `tile.openstreetmap.org` | Use policies forbid this app's pattern | Do not call them |

## Sources

Primary pages consulted on 3 October 2026:

- [OpenStreetMap copyright](https://www.openstreetmap.org/copyright)
- [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)
- [OSMF attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines)
- [OSM community attribution advice](https://wiki.openstreetmap.org/wiki/Community_attribution_advice)
- [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)
- [Tag: amenity=place_of_worship](https://wiki.openstreetmap.org/wiki/Tag:amenity%3Dplace_of_worship)
- [Key: service_times](https://wiki.openstreetmap.org/wiki/Key:service_times)
- [Key: mass_times](https://wiki.openstreetmap.org/wiki/Key:mass_times)
- [Key: confession_times](https://wiki.openstreetmap.org/wiki/Key:confession_times)
- [Key: access](https://wiki.openstreetmap.org/wiki/Key:access)
- [Geofabrik downloads and license](https://www.geofabrik.de/en/data/download.html)
- [Geofabrik New Mexico extract](https://download.geofabrik.de/north-america/us/new-mexico.html)
- [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/)
- [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
- [OpenFreeMap](https://openfreemap.org/)
- [Protomaps basemap downloads](https://docs.protomaps.com/basemaps/downloads/)
- [Protomaps builds](https://maps.protomaps.com/builds/)
- [MapLibre Native](https://github.com/maplibre/maplibre-native)
- [MapLibre iOS PMTiles](https://maplibre.org/maplibre-native/ios/latest/documentation/maplibre-native-for-ios/pmtiles/)
- [Wikidata:Licensing](https://www.wikidata.org/wiki/Wikidata:Licensing)
- [Wikimedia dump licenses](https://dumps.wikimedia.org/legal.html)
- [Commons:Licensing](https://commons.wikimedia.org/wiki/Commons:Licensing)
- [Wikipedia copyright FAQ](https://en.wikipedia.org/wiki/Wikipedia:Copyright_FAQ)
- [Loretto Chapel](https://en.wikipedia.org/wiki/Loretto_Chapel)
- [PAD-US data record](https://www.usgs.gov/data/protected-areas-database-united-states-pad-us-4)
- [PAD-US download](https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-data-download)
- [PAD-US web services](https://www.usgs.gov/programs/gap-analysis-project/science/pad-us-web-services)
- [PAD-US data manual](https://www.usgs.gov/programs/gap-analysis-project/pad-us-data-manual)
- [BLM GIS data](https://www.blm.gov/services/geospatial/GISData)
- [BLM SMA item info](https://gis.blm.gov/arcgis/rest/services/lands/BLM_Natl_SMA_Cached_without_PriUnk/MapServer/info/iteminfo)
- [USFS FSGeodata, ownership](https://data.fs.usda.gov/geodata/edw/datasets.php?xmlKeyword=basic+ownership)
- [USFS Basic Ownership service](https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_BasicOwnership_01/MapServer/0)
- [NPS boundary and tract service](https://services1.arcgis.com/fBc8EJBxQRMcHlei/ArcGIS/rest/services/NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer)
- [TIGER/Line 2025 technical documentation](https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2025/TGRSHP2025_TechDoc.pdf)
- [NM TRD GIS data download](https://www.tax.newmexico.gov/businesses/geographic-information-system-gis/data-download/)
- [NM parcel mapping policy manual](https://www.tax.newmexico.gov/businesses/wp-content/uploads/sites/4/2021/02/NMMapping_Policy_Manual_Final_2021.pdf)
- [SLO outdoor recreation](https://www.nmstatelands.org/outdoorrecreation/)
- [SLO recreational access rule](https://www.nmstatelands.org/wp-content/uploads/2019/10/Recreational-Access-Permit-10.17.2019.pdf)
- [SLO GIS downloads](https://mapservice.nmstatelands.org/GISDataDownloads/)
- [SLO trust-land metadata](https://mapservice.nmstatelands.org/GISDataDownloads/MetaData/SLO_STLCombined_Own_Metadata.htm)
- [SLO GIS FAQ](https://www.nmstatelands.org/maps-gis/gis-faqs/)
- [SLO general FAQ](https://www.nmstatelands.org/resources/resources-faqs/)
- [Bernalillo County Assessor GIS](https://www.bernco.gov/assessor/geographic-information-system-gis/)
- [City of Albuquerque GIS downloads](https://www.cabq.gov/gis/geographic-information-systems-data)
- [City of Albuquerque GIS metadata](https://www.cabq.gov/gis/geographic-information-systems-metadata)
- [City of Albuquerque data disclaimer](https://www.cabq.gov/abq-data/abq-data-disclaimer-1)
- [Santa Fe County GIS disclaimer](https://www.santafecountynm.gov/growth-management/gis/gisconfirm)
- [Santa Fe County Assessor 2025 GIS data request](https://www.santafecountynm.gov/assessor/uploads/documents/2025_GIS_Data_Request.pdf)
- [City of Santa Fe map gallery](https://santafenm.gov/information-technology-telecommunications/gis/map-gallery)
- [MassGIS property tax parcels](https://www.mass.gov/info-details/massgis-data-property-tax-parcels)
