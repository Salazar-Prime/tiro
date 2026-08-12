import Foundation

enum TranscriptionEngine: String, CaseIterable, Identifiable {
    case cloud
    case offline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloud: "OpenAI"
        case .offline: "On-device"
        }
    }

    var detail: String {
        switch self {
        case .cloud: "Fastest"
        case .offline: "Private"
        }
    }

    var icon: String {
        switch self {
        case .cloud: "cloud.fill"
        case .offline: "cpu"
        }
    }
}
