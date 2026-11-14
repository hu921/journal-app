import Foundation
import SwiftData

enum Gender: String, CaseIterable, Identifiable {
    case female, male, nonBinary = "nonbinary", preferNotToSay = "undisclosed"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .nonBinary: "Non-binary"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

/// The person who owns the journal. Stored in SwiftData, so it syncs with iCloud.
/// The app keeps one profile; if two devices create one before syncing, the oldest wins.
@Model
final class UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var genderRaw: String = ""
    var birthday: Date?
    var createdAt: Date = Date()

    // About Me. Every field is optional; empty fields are hidden on the page.
    var nickname: String = ""
    @Attribute(.externalStorage) var photo: Data?

    var favoriteFood: String = ""
    var favoriteColor: String = ""
    var favoriteSong: String = ""
    var favoriteMovie: String = ""
    var favoriteBook: String = ""
    var favoritePlace: String = ""
    var favoriteSeason: String = ""

    var threeWords: String = ""

    var mood: String = ""
    var intoNow: String = ""
    var goals: String = ""
    var rightNowUpdated: Date?
    /// Past "Right now" answers, as JSON. See `timeCapsule`.
    var timeCapsuleJSON: String = ""

    var quote: String = ""
    /// Signature drawn with a finger (PencilKit drawing data).
    @Attribute(.externalStorage) var signature: Data?

    init() {}

    struct Favorite: Hashable {
        let label: String
        let value: String
    }

    /// Filled-in favorites, in display order.
    var favorites: [Favorite] {
        [("Food", favoriteFood), ("Color", favoriteColor), ("Song", favoriteSong),
         ("Movie", favoriteMovie), ("Book", favoriteBook), ("Place", favoritePlace),
         ("Season", favoriteSeason)]
            .map { Favorite(label: $0.0, value: $0.1.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.value.isEmpty }
    }

    var hasRightNow: Bool {
        !(mood + intoNow + goals).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Western zodiac sign from the birthday.
    var zodiac: ZodiacSign? { birthday.map(ZodiacSign.init(date:)) }

    var timeCapsule: [CapsuleEntry] {
        get {
            guard let data = timeCapsuleJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CapsuleEntry].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            timeCapsuleJSON = String(data: data, encoding: .utf8) ?? ""
        }
    }

    /// Keeps the current "Right now" answers in the time capsule.
    func saveRightNowToCapsule() {
        guard hasRightNow else { return }
        var list = timeCapsule
        list.insert(CapsuleEntry(date: rightNowUpdated ?? .now, mood: mood, intoNow: intoNow, goals: goals), at: 0)
        timeCapsule = list
    }

    var gender: Gender? {
        get { Gender(rawValue: genderRaw) }
        set { genderRaw = newValue?.rawValue ?? "" }
    }

    /// True when "Right now" was last updated more than a year ago.
    var rightNowIsOld: Bool {
        guard hasRightNow, let updated = rightNowUpdated else { return false }
        return updated < Calendar.current.date(byAdding: .year, value: -1, to: .now)!
    }

    var initials: String {
        let f = firstName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let l = lastName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}

/// One saved set of "Right now" answers.
struct CapsuleEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var mood: String
    var intoNow: String
    var goals: String
}

enum ZodiacSign: String, CaseIterable {
    case capricorn = "Capricorn", aquarius = "Aquarius", pisces = "Pisces", aries = "Aries",
         taurus = "Taurus", gemini = "Gemini", cancer = "Cancer", leo = "Leo",
         virgo = "Virgo", libra = "Libra", scorpio = "Scorpio", sagittarius = "Sagittarius"

    init(date: Date) {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        switch md {
        case 120...218: self = .aquarius
        case 219...320: self = .pisces
        case 321...419: self = .aries
        case 420...520: self = .taurus
        case 521...620: self = .gemini
        case 621...722: self = .cancer
        case 723...822: self = .leo
        case 823...922: self = .virgo
        case 923...1022: self = .libra
        case 1023...1121: self = .scorpio
        case 1122...1221: self = .sagittarius
        default: self = .capricorn
        }
    }

    /// Zodiac symbol drawn as text, not emoji.
    var symbol: String {
        let order: [ZodiacSign] = [.aries, .taurus, .gemini, .cancer, .leo, .virgo,
                                   .libra, .scorpio, .sagittarius, .capricorn, .aquarius, .pisces]
        let index = order.firstIndex(of: self) ?? 0
        let scalar = Unicode.Scalar(0x2648 + UInt32(index))!
        return String(Character(scalar)) + "\u{FE0E}"
    }
}
