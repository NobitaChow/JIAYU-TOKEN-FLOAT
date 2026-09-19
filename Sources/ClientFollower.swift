// Application lifecycle notification registration adapted from LyricsXHelper/AppDelegate.swift.
// Copyright the LyricsX contributors. This file is subject to Mozilla Public License 2.0.
// A copy of the license is included in ThirdParty/MPL-2.0.txt.
import Cocoa

final class ClientFollower {
    let clientID:String
    let appURL:URL
    let appID:String
    var policy = FollowPolicy()
    var opening = false
    var observers:[NSObjectProtocol] = []
    init(clientID:String,appURL:URL) throws {
        self.clientID = clientID; self.appURL = appURL
        guard let id = Bundle(url:appURL)?.bundleIdentifier, id != clientID else {
            throw NSError(domain:"ClientFollower",code:1,userInfo:[NSLocalizedDescriptionKey:"Invalid companion application"])
        }
        appID = id
    }
    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName:event,object:nil,queue:.main) { [weak self] _ in self?.reconcile() })
        }
        observers.append(center.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in self?.reconcile() })
        reconcile()
    }
    func companionApps() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier:appID).filter {
            $0.bundleURL?.standardizedFileURL == appURL.standardizedFileURL
        }
    }
    func reconcile() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier:clientID).contains { !$0.isTerminated }
        switch policy.update(clientRunning:running) {
        case .none: break // Respect manual Quit until the next client launch.
        case .stop: companionApps().forEach { _ = $0.terminate() }
        case .launch:
            guard !opening, companionApps().isEmpty else { return }
            opening = true
            let config = NSWorkspace.OpenConfiguration(); config.activates = false
            NSWorkspace.shared.openApplication(at:appURL,configuration:config) { [weak self] app,error in
                DispatchQueue.main.async {
                    guard let self else { return }; self.opening = false
                    if let error { NSLog("Token Float launch failed: %@",error.localizedDescription) }
                    // The client may have exited while Launch Services was opening the companion.
                    if NSRunningApplication.runningApplications(withBundleIdentifier:self.clientID).isEmpty { _ = app?.terminate() }
                }
            }
        }
    }
}
@main enum FollowerEntry {
    static func main() {
        let args = CommandLine.arguments
        guard args.count == 3 else { exit(2) }
        do {
            let follower = try ClientFollower(clientID:args[1],appURL:URL(fileURLWithPath:args[2]))
            follower.start()
            withExtendedLifetime(follower) { RunLoop.main.run() }
        } catch { fputs("Invalid follower configuration\n",stderr); exit(2) }
    }
}
