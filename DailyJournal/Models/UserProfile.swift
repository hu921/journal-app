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

    init() {}

    var gender: Gender? {
        get { Gender(rawValue: genderRaw) }
        set { genderRaw = newValue?.rawValue ?? "" }
    }

    var initials: String {
        let f = firstName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let l = lastName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
