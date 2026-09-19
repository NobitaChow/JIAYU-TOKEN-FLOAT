import Foundation

enum FollowAction: Equatable { case none, launch, stop }
struct FollowPolicy {
    private var previous:Bool?
    mutating func update(clientRunning:Bool) -> FollowAction {
        defer { previous = clientRunning }
        guard previous != clientRunning else { return .none }
        return clientRunning ? .launch : .stop
    }
}
