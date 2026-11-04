import Foundation

struct Deployment: Equatable, Identifiable {
    enum Status: String, Codable {
        case pending, building, ready, failed, canceled, unknown

        var isTerminal: Bool { self == .ready || self == .failed || self == .canceled }
        var label: String {
            switch self {
            case .pending: return L("Queued")
            case .building: return L("Building")
            case .ready: return L("Ready")
            case .failed: return L("Failed")
            case .canceled: return L("Canceled")
            case .unknown: return L("Unknown")
            }
        }
    }

    let id: String
    let project: String
    let repository: String?
    let commit: String?
    let author: String?
    let status: Status
}

/// Tracks terminal transitions without notifying for history loaded on the first successful poll.
struct DeploymentTracker: Codable {
    private var statuses: [String: Deployment.Status] = [:]
    private var initialized = false

    mutating func update(_ deployments: [Deployment]) -> [Deployment] {
        var finished: [Deployment] = []
        for deployment in deployments {
            let previous = statuses[deployment.id]
            if initialized && deployment.status.isTerminal && previous?.isTerminal != true {
                finished.append(deployment)
            }
            if previous?.isTerminal != true { statuses[deployment.id] = deployment.status }
        }
        initialized = true
        return finished
    }
}
