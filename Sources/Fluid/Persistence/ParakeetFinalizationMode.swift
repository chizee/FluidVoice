import Foundation

enum ParakeetFinalizationMode: String, CaseIterable, Codable, Identifiable {
    case stableFullFinal
    case tokenTimedChunkMerge

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .stableFullFinal:
            return "Normal"
        case .tokenTimedChunkMerge:
            return "Fast"
        }
    }

    var detailText: String {
        switch self {
        case .stableFullFinal:
            return "Very reliable. This uses the default FluidVoice processing after you stop dictating."
        case .tokenTimedChunkMerge:
            return "Tries to finish faster using live transcription, but it is still experimental and can be less consistent."
        }
    }
}
