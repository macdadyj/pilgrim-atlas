import Foundation

/// Hand-verified weekly schedules for Albuquerque Catholic churches.
/// Read from parish sites, with the Archdiocese of Santa Fe directory used only
/// where a line says so. Verified 15 Oct 2026. MassTimes.org and Discover Mass
/// are not a source.
package struct AlbuquerqueParish: Equatable, Sendable {
    package var name: String
    package var phone: String
    package var website: String
    package var directory: String
    package var sourceName: String
    package var lines: [String]
    package var confirm: String
    package var nameTokens: [String]
    package var rejectTokens: [String]
    package var latitude: Double
    package var longitude: Double
    /// Zero matches the name anywhere. Used when the pack has no pin yet.
    package var radiusMeters: Double
}

package enum AlbuquerqueParishes {
    package static let verified = "2026-10-15"

    package static let all: [AlbuquerqueParish] = [
        AlbuquerqueParish(
            name: "Church of the Ascension",
            phone: "505-877-8550",
            website: "https://www.ascensionabq.org/sacraments/eucharist",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass, Bilingual, from the Archdiocese directory",
            "Sun 10:00 AM Mass",
            "Tue 8:00 AM Mass",
            "Wed 8:00 AM Mass",
            "Fri 8:00 AM Mass",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["ascension"],
            rejectTokens: [],
            latitude: 34.97854,
            longitude: -106.701373,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Holy Family",
            phone: "505-842-5426",
            website: "https://www.holyfamilynm.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 10:00 AM Mass, Spanish",
            "Sun 12:00 PM Mass",
            "Mon 7:00 AM Mass",
            "Tue 7:00 AM Mass",
            "Wed 7:00 AM Mass, Spanish",
            "Thu 7:00 AM Mass",
            "Fri 7:00 AM Mass",
            "Sat 4:30 PM Vigil",
            "Sat 6:30 PM Vigil, Spanish"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["holy family"],
            rejectTokens: [],
            latitude: 35.074517,
            longitude: -106.686561,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Holy Ghost",
            phone: "505-265-5957",
            website: "https://holyghost.weconnect.com/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 9:30 AM Mass, Spanish",
            "Sun 11:00 AM Mass",
            "Sun 1:00 PM Mass, Spanish",
            "Tue 8:00 AM Mass",
            "Wed 8:00 AM Mass",
            "Thu 8:00 AM Mass",
            "Fri 8:00 AM Mass",
            "Sat 8:00 AM Mass, 1st Saturday only",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["holy ghost"],
            rejectTokens: [],
            latitude: 35.064256,
            longitude: -106.576765,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Immaculate Conception",
            phone: "505-247-4271",
            website: "http://www.iccabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 10:00 AM Mass",
            "Sun 12:30 PM Mass, Spanish",
            "Mon 12:10 PM Mass",
            "Tue 7:00 AM Mass",
            "Wed 12:10 PM Mass",
            "Thu 7:00 AM Mass",
            "Fri 7:00 AM Mass, 1st Friday only",
            "Fri 12:10 PM Mass",
            "Sat 7:00 AM Mass",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["immaculate conception"],
            rejectTokens: [],
            latitude: 35.086269,
            longitude: -106.654396,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Nativity of the BVM (Alameda)",
            phone: "505-898-5253",
            website: "https://www.n-bvm.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:00 AM Mass",
            "Sun 10:45 AM Mass, Spanish",
            "Sun 12:30 PM Mass",
            "Mon 9:00 AM Mass",
            "Tue 9:00 AM Mass",
            "Wed 9:00 AM Mass",
            "Thu 9:00 AM Mass",
            "Fri 9:00 AM Mass",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["nativity"],
            rejectTokens: [],
            latitude: 35.187728,
            longitude: -106.616475,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of Fatima",
            phone: "505-265-5868",
            website: "https://www.fatimabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 10:00 AM Mass",
            "Sun 12:00 PM Mass, Spanish",
            "Sun 5:00 PM Mass",
            "Mon 7:00 AM Mass",
            "Tue 5:15 PM Mass",
            "Wed 7:00 AM Mass",
            "Thu 5:15 PM Mass",
            "Fri 7:00 AM Mass",
            "Sat 8:00 AM Mass",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["fatima"],
            rejectTokens: [],
            latitude: 35.087085,
            longitude: -106.599198,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of Guadalupe",
            phone: "505-345-4596",
            website: "http://www.guadalupeabq.com/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:30 AM Mass",
            "Sun 12:00 PM Mass, Spanish",
            "Mon 9:00 AM Mass, Bilingual",
            "Tue 9:00 AM Mass, Bilingual",
            "Wed 9:00 AM Mass, Bilingual",
            "Fri 9:00 AM Mass, Bilingual",
            "Sat 4:00 PM Vigil, Bilingual"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["guadalupe"],
            rejectTokens: ["fransiscan", "franciscan", "province"],
            latitude: 35.132775,
            longitude: -106.665829,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of La Vang",
            phone: "505-508-2841",
            website: "https://www.lavangabq.org/mass---prayer-time",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:00 AM Mass, Vietnamese",
            "Mon 8:30 AM Mass, Vietnamese (parish site; ASF directory instead lists Tue/Thu 6:30 PM)",
            "Tue 8:30 AM Mass, Vietnamese (parish site; ASF directory instead lists Tue/Thu 6:30 PM)",
            "Wed 8:30 AM Mass, Vietnamese (parish site; ASF directory instead lists Tue/Thu 6:30 PM)",
            "Thu 8:30 AM Mass, Vietnamese (parish site; ASF directory instead lists Tue/Thu 6:30 PM)",
            "Fri 8:30 AM Mass, Vietnamese (parish site; ASF directory instead lists Tue/Thu 6:30 PM)",
            "Sat 6:00 PM Vigil, Vietnamese"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["lavang"],
            rejectTokens: [],
            latitude: 35.088218,
            longitude: -106.506804,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of Mt. Carmel Chapel (mission of Nativity)",
            phone: "505-898-5253",
            website: "https://www.n-bvm.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Tue 5:30 PM Mass"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["mount carmel"],
            rejectTokens: [],
            latitude: 35.168822,
            longitude: -106.618011,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of Perpetual Help Byzantine Catholic",
            phone: "505-256-1539",
            website: "https://www.olphnm.org/",
            directory: "Holy Protection Byzantine Catholic Eparchy of Phoenix",
            sourceName: "Parish website",
            lines: [
            "Sun 8:30 AM Rosary",
            "Sun 9:00 AM Matins",
            "Sun 10:00 AM Divine Liturgy",
            "Mon 9:00 AM Divine Liturgy",
            "Fri 6:00 PM Divine Liturgy",
            "Sat 4:00 PM Great Vespers",
            "Sat 5:00 PM Divine Liturgy"
            ],
            confirm: "Call to confirm. Liturgy times vary.",
            nameTokens: ["perpetual help"],
            rejectTokens: ["tears"],
            latitude: 35.096452,
            longitude: -106.582347,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of the Annunciation",
            phone: "505-298-7553",
            website: "https://www.annunciationparishabq.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:00 AM Mass",
            "Sun 9:00 AM Mass",
            "Sun 10:30 AM Mass",
            "Sun 12:00 PM Mass",
            "Mon 8:30 AM Mass",
            "Mon 5:30 PM Mass",
            "Tue 8:30 AM Mass",
            "Tue 5:30 PM Mass",
            "Wed 8:30 AM Mass",
            "Wed 5:30 PM Mass",
            "Thu 8:30 AM Mass",
            "Thu 5:30 PM Mass",
            "Fri 8:30 AM Mass",
            "Fri 5:30 PM Mass",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["annunciation"],
            rejectTokens: [],
            latitude: 35.112508,
            longitude: -106.554997,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of the Assumption",
            phone: "505-256-9818",
            website: "https://olacs.org/church",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:00 AM Mass",
            "Sun 10:30 AM Mass",
            "Mon 8:30 AM Mass, Archdiocese directory only",
            "Tue 8:30 AM Mass, Archdiocese directory only",
            "Wed 8:30 AM Mass, Archdiocese directory only",
            "Thu 8:30 AM Mass, Archdiocese directory only",
            "Fri 8:30 AM Mass, Archdiocese directory only",
            "Sat 8:30 AM Mass, Archdiocese directory only",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times. Weekday 8:30 AM is listed only in the Archdiocese directory.",
            nameTokens: ["assumption"],
            rejectTokens: [],
            latitude: 35.086732,
            longitude: -106.557555,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Our Lady of the Most Holy Rosary",
            phone: "505-836-5011",
            website: "https://www.holyrosaryabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 10:00 AM Mass",
            "Sun 12:00 PM Mass, Spanish",
            "Mon 9:00 AM Mass",
            "Wed 9:00 AM Mass",
            "Fri 9:00 AM Mass",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["most holy rosary"],
            rejectTokens: [],
            latitude: 35.095306,
            longitude: -106.701689,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Prince of Peace",
            phone: "505-856-7657",
            website: "https://www.popabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:00 AM Mass",
            "Sun 11:00 AM Mass",
            "Sun 5:00 PM Mass",
            "Wed 9:00 AM Mass",
            "Fri 9:00 AM Mass",
            "Sat 9:00 AM Mass",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["prince of peace"],
            rejectTokens: ["lutheran"],
            latitude: 35.176379,
            longitude: -106.499495,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Queen of Heaven",
            phone: "505-881-1772",
            website: "https://qofhabq.com/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:30 AM Mass, Bilingual (Spanish/English)",
            "Sun 11:30 AM Mass",
            "Sun 6:00 PM Mass",
            "Mon 7:30 AM Mass",
            "Tue 7:30 AM Mass, only when Chesterton Academy is in session",
            "Tue 5:30 PM Mass",
            "Wed 7:30 AM Mass",
            "Thu 7:30 AM Mass",
            "Fri 7:30 AM Mass",
            "Sat 7:30 AM Mass, Latin/English (bilingual)",
            "Sat 4:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["queen of heaven"],
            rejectTokens: [],
            latitude: 35.112393,
            longitude: -106.584821,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Risen Savior",
            phone: "505-821-1571",
            website: "http://www.risensaviorcc.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:00 AM Mass",
            "Sun 9:00 AM Mass",
            "Sun 11:00 AM Mass",
            "Tue 11:30 AM Mass",
            "Wed 7:00 AM Mass",
            "Thu 11:30 AM Mass",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["risen savior"],
            rejectTokens: [],
            latitude: 35.168637,
            longitude: -106.560928,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Sacred Heart",
            phone: "505-242-0561",
            website: "https://www.sacredheartabq.com/liturgy",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:45 AM Mass, Spanish",
            "Sun 10:00 AM Mass",
            "Mon 6:45 AM Mass",
            "Mon 11:00 AM Mass",
            "Tue 6:45 AM Mass",
            "Tue 11:00 AM Mass",
            "Thu 6:45 AM Mass",
            "Thu 11:00 AM Mass",
            "Fri 6:45 AM Mass",
            "Fri 11:00 AM Mass",
            "Sat 8:00 AM Mass, 1st Saturday only",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["sacred heart"],
            rejectTokens: [],
            latitude: 35.079026,
            longitude: -106.652094,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "San Felipe de Neri (Old Town)",
            phone: "505-243-4628",
            website: "https://www.sanfelipedeneri.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:00 AM Mass",
            "Sun 9:00 AM Mass, Spanish",
            "Sun 11:00 AM Mass",
            "Mon 7:00 AM Mass",
            "Tue 7:00 AM Mass",
            "Wed 7:00 AM Mass",
            "Fri 7:00 AM Mass",
            "Sat 7:00 AM Mass, 1st Saturday only",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["san felipe", "neri"],
            rejectTokens: [],
            latitude: 35.096828,
            longitude: -106.669784,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "San Ignacio",
            phone: "505-243-4287",
            website: "https://www.sanignacioabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:30 AM Mass",
            "Sun 12:00 PM Traditional Latin Mass",
            "Sun 2:00 PM Mass, Filipino/English bilingual; last Sunday of month only",
            "Mon 12:15 PM Mass",
            "Wed 12:15 PM Mass",
            "Fri 12:15 PM Mass, Spanish"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["san ignacio"],
            rejectTokens: ["capilla"],
            latitude: 35.095316,
            longitude: -106.638057,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "San Jose",
            phone: "505-242-3658",
            website: "https://www.sanjoseabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass, Spanish",
            "Sun 9:00 AM Mass",
            "Sun 10:30 AM Mass, Spanish",
            "Sun 12:30 PM Mass, Spanish",
            "Thu 5:00 PM Mass, Spanish",
            "Fri 6:00 AM Mass, Spanish; 1st Friday only (Sacred Heart Mass)",
            "Sat 5:00 PM Vigil, Spanish"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["san jose"],
            rejectTokens: ["duranes", "gracia", "chama"],
            latitude: 35.057749,
            longitude: -106.646798,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "San Jose de los Duranes (mission of San Felipe)",
            phone: "505-243-4628",
            website: "https://www.sanfelipedeneri.org/san-jose-de-los-duranes-mission",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sat 6:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["duranes"],
            rejectTokens: [],
            latitude: 0,
            longitude: 0,
            radiusMeters: 0
        ),
        AlbuquerqueParish(
            name: "Sangre de Cristo",
            phone: "505-292-6477",
            website: "https://sangredecristoabq.com/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:30 AM Mass",
            "Sun 10:30 AM Mass",
            "Sun 6:00 PM Mass",
            "Mon 9:15 AM Mass",
            "Tue 9:15 AM Mass",
            "Wed 9:15 AM Mass",
            "Thu 9:15 AM Mass",
            "Fri 9:15 AM Mass",
            "Sat 9:15 AM Mass, 1st Saturday only",
            "Sat 5:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["sangre", "cristo"],
            rejectTokens: ["novitiate"],
            latitude: 35.116809,
            longitude: -106.544193,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Santuario San Martin de Porres",
            phone: "505-836-4676",
            website: "https://santuariosanmartin.org/mass-confession",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 9:30 AM Mass, Spanish",
            "Sun 11:30 AM Mass",
            "Sun 1:30 PM Mass, Spanish",
            "Sun 5:15 PM Mass, Bilingual",
            "Mon 9:00 AM Mass, Bilingual",
            "Tue 9:00 AM Mass, Bilingual",
            "Wed 9:00 AM Mass, Bilingual",
            "Thu 9:00 AM Mass, Bilingual",
            "Fri 9:00 AM Mass, Bilingual",
            "Sat 9:00 AM Mass, Bilingual; 1st Saturday only",
            "Sat 4:00 PM Vigil",
            "Sat 5:30 PM Vigil, Spanish"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["san martin"],
            rejectTokens: [],
            latitude: 35.046153,
            longitude: -106.726735,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "Shrine of St. Bernadette",
            phone: "505-298-7557",
            website: "https://www.ssbnm.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:30 AM Mass",
            "Sun 11:30 AM Mass",
            "Mon 7:00 AM Mass",
            "Tue 7:00 AM Mass",
            "Wed 7:00 AM Mass",
            "Thu 7:00 AM Mass",
            "Fri 7:00 AM Mass",
            "Sat 8:00 AM Mass",
            "Sat 4:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["bernadette"],
            rejectTokens: [],
            latitude: 35.101983,
            longitude: -106.520475,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Anne",
            phone: "505-877-3121",
            website: "https://stannechurchabq.com/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 10:00 AM Mass, Spanish",
            "Sun 12:00 PM Mass",
            "Tue 9:00 AM Mass",
            "Wed 9:00 AM Mass",
            "Thu 9:00 AM Mass",
            "Fri 9:00 AM Mass",
            "Sat 4:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["saint anne"],
            rejectTokens: [],
            latitude: 35.05246,
            longitude: -106.675622,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Charles Borromeo",
            phone: "505-242-3462",
            website: "https://stcharlesnm.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:00 AM Mass",
            "Sun 11:00 AM Mass",
            "Mon 12:15 PM Mass",
            "Tue 12:15 PM Mass",
            "Wed 12:15 PM Mass",
            "Fri 12:15 PM Mass",
            "Sat 5:00 PM Vigil",
            "Sat 7:00 PM Vigil, Vietnamese"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["borromeo"],
            rejectTokens: [],
            latitude: 35.076907,
            longitude: -106.627045,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Edwin",
            phone: "505-877-2967",
            website: "https://archdiosf.org/parishfinder",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Archdiocese of Santa Fe directory",
            lines: [
            "Sun 9:00 AM Mass, Archdiocese directory only",
            "Sun 11:00 AM Mass, Archdiocese directory only",
            "Sun 1:00 PM Mass, Spanish, Archdiocese directory only",
            "Mon 8:00 AM Mass, Archdiocese directory only",
            "Wed 8:00 AM Mass, Archdiocese directory only",
            "Fri 8:00 AM Mass, Archdiocese directory only",
            "Sat 4:00 PM Vigil, Archdiocese directory only"
            ],
            confirm: "Call to confirm. The parish site does not post a schedule. These times are from the Archdiocese of Santa Fe directory.",
            nameTokens: ["edwin"],
            rejectTokens: [],
            latitude: 35.031311,
            longitude: -106.69052,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Francis Xavier",
            phone: "505-243-5201",
            website: "http://www.stfrancisxavierparishabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:30 AM Mass",
            "Sun 11:30 AM Mass, Spanish",
            "Mon 8:00 AM Mass, English & Spanish",
            "Tue 8:00 AM Mass, English & Spanish",
            "Wed 8:00 AM Mass, English & Spanish",
            "Thu 8:00 AM Mass, English & Spanish",
            "Fri 8:00 AM Mass, English & Spanish"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["xavier"],
            rejectTokens: [],
            latitude: 35.074976,
            longitude: -106.645301,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. John XXIII",
            phone: "505-293-0088",
            website: "http://www.johnxxiiicc.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:30 AM Mass",
            "Sun 9:30 AM Mass",
            "Sun 11:30 AM Mass",
            "Mon 8:00 AM Mass",
            "Tue 8:00 AM Mass",
            "Thu 8:00 AM Mass",
            "Fri 8:00 AM Mass",
            "Sat 5:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["xxiii"],
            rejectTokens: [],
            latitude: 35.135031,
            longitude: -106.500248,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Joseph on the Rio Grande",
            phone: "505-839-7952",
            website: "https://sjrgcc.org/mass-times",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass, Spanish",
            "Sun 10:00 AM Mass",
            "Sun 12:00 PM Mass",
            "Mon 9:00 AM Mass",
            "Tue 9:00 AM Mass",
            "Wed 9:00 AM Mass",
            "Thu 9:00 AM Mass",
            "Fri 9:00 AM Mass",
            "Sat 5:00 PM Vigil, Archdiocese lists 4:00 PM in Mountain Standard Time, Nov–Mar"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["joseph", "rio grande"],
            rejectTokens: [],
            latitude: 35.129563,
            longitude: -106.70625,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Jude Thaddeus",
            phone: "505-898-0826",
            website: "https://www.stjudenm.org/mass-and-confession-schedule",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 7:00 AM Mass",
            "Sun 9:00 AM Mass",
            "Sun 11:00 AM Mass",
            "Sun 1:00 PM Mass, Bilingual (English/Spanish)",
            "Sun 5:00 PM Mass",
            "Mon 8:00 AM Mass",
            "Mon 6:00 PM Mass",
            "Tue 8:00 AM Mass",
            "Tue 6:00 PM Mass",
            "Wed 8:00 AM Mass",
            "Wed 6:00 PM Mass",
            "Thu 8:00 AM Mass",
            "Thu 6:00 PM Mass",
            "Fri 8:00 AM Mass",
            "Fri 6:00 PM Mass",
            "Sat 5:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["jude"],
            rejectTokens: [],
            latitude: 35.194239,
            longitude: -106.707791,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Therese / Shrine of the Little Flower",
            phone: "505-344-8050",
            website: "https://www.littleflowerabq.org/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 8:00 AM Mass",
            "Sun 10:00 AM Mass",
            "Sun 12:00 PM Mass, Spanish",
            "Tue 8:00 AM Mass",
            "Wed 8:00 AM Mass",
            "Thu 8:00 AM Mass",
            "Fri 8:00 AM Mass",
            "Sat 8:00 AM Mass",
            "Sat 4:00 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["therese"],
            rejectTokens: [],
            latitude: 35.117092,
            longitude: -106.643808,
            radiusMeters: 900
        ),
        AlbuquerqueParish(
            name: "St. Thomas Aquinas Univ. Parish (Newman Ctr)",
            phone: "505-247-1094",
            website: "https://lobocatholic.org/mass-sacraments/",
            directory: "Archdiocese of Santa Fe",
            sourceName: "Parish website",
            lines: [
            "Sun 9:00 AM Mass",
            "Sun 11:00 AM Mass",
            "Sun 5:00 PM Mass, Student Mass; schedule may shift during university breaks",
            "Mon 8:15 AM Mass",
            "Mon 5:15 PM Mass",
            "Tue 12:10 PM Mass",
            "Tue 5:15 PM Mass",
            "Wed 8:15 AM Mass",
            "Wed 5:15 PM Mass",
            "Thu 12:10 PM Mass",
            "Thu 5:15 PM Mass",
            "Fri 8:15 AM Mass",
            "Fri 5:15 PM Mass",
            "Sat 8:30 AM Mass",
            "Sat 4:30 PM Vigil"
            ],
            confirm: "Call to confirm. Holy days, holidays, and school breaks can change these times.",
            nameTokens: ["aquinas", "university"],
            rejectTokens: [],
            latitude: 35.087149,
            longitude: -106.623074,
            radiusMeters: 900
        )
    ]

    package static func match(_ place: PlaceRecord) -> AlbuquerqueParish? {
        all.first { matches($0, place) }
    }

    package static func listing(for place: PlaceRecord) -> LiturgyListing? {
        guard let parish = match(place) else { return nil }
        return LiturgyListing(
            lines: parish.lines,
            confession: "",
            verified: verified,
            sourceName: parish.sourceName,
            sourceURL: parish.website,
            phone: parish.phone,
            website: parish.website,
            directory: parish.directory,
            confirm: parish.confirm
        )
    }

    package static func contact(for place: PlaceRecord) -> ParishContact? {
        guard let parish = match(place) else { return nil }
        return ParishContact(
            name: parish.name,
            phone: parish.phone,
            website: parish.website,
            directory: parish.directory
        )
    }

    private static func matches(_ parish: AlbuquerqueParish, _ place: PlaceRecord) -> Bool {
        let name = AtlasQuery.fold(place.name)
        guard parish.nameTokens.allSatisfy({ name.contains($0) }) else { return false }
        if parish.rejectTokens.contains(where: { name.contains($0) }) { return false }
        guard parish.radiusMeters > 0 else { return true }
        let meters = Geometry.haversineMeters(
            place.coordinate,
            LonLat(lon: parish.longitude, lat: parish.latitude)
        )
        return meters <= parish.radiusMeters
    }
}
