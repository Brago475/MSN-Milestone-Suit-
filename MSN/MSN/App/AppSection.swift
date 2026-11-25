import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case files
    case runner
    case graph
    case secrets
    case diagrams
    case milestones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: "Files"
        case .runner: "Code Runner"
        case .graph: "Graph"
        case .secrets: "Secrets"
        case .diagrams: "Diagrams"
        case .milestones: "Milestones"
        }
    }

    /// SF Symbol used when the section has no custom icon.
    var symbol: String {
        switch self {
        case .files: "folder"
        case .runner: "apple.terminal"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .secrets: "key"
        case .diagrams: "pencil"
        case .milestones: "chart.bar"
        }
    }

    /// Custom icon from the asset catalog, if any.
    var assetName: String? {
        switch self {
        case .secrets: "RailSecrets"
        case .diagrams: "RailDiagrams"
        case .milestones: "RailMilestones"
        default: nil
        }
    }
}