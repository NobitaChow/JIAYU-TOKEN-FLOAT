import Foundation

/// A per-user launch agent keeps the lifecycle observer available while the panel is closed.
enum FollowSettings {
    static let label = "studio.jiayu.tokenfloat.follow-codex"
    static let clientID = "com.openai.codex"
    static var plist:URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    static var enabled:Bool { FileManager.default.fileExists(atPath:plist.path) }
    static var domain:String { "gui/\(getuid())" }
    @discardableResult static func launchctl(_ args:[String]) throws -> Int32 {
        let p = Process();p.executableURL = URL(fileURLWithPath:"/bin/launchctl");p.arguments = args
        p.standardOutput = FileHandle.nullDevice;p.standardError = FileHandle.nullDevice
        try p.run();p.waitUntilExit();return p.terminationStatus
    }
    static func setEnabled(_ enabled:Bool) throws {
        if !enabled {
            let status = try launchctl(["bootout",domain+"/"+label])
            let stillLoaded = try launchctl(["print",domain+"/"+label]) == 0
            guard status == 0 || !stillLoaded else {
                throw NSError(domain:label,code:1,userInfo:[NSLocalizedDescriptionKey:"无法关闭跟随助手，请稍后重试"])
            }
            if FileManager.default.fileExists(atPath:plist.path) { try FileManager.default.removeItem(at:plist) }
            return
        }
        let app = Bundle.main.bundleURL
        guard app.path.hasPrefix("/Applications/"), app.pathExtension == "app" else {
            throw NSError(domain:label,code:2,userInfo:[NSLocalizedDescriptionKey:"请先把应用移入“应用程序”，再开启跟随"])
        }
        let executable = app.appendingPathComponent("Contents/Helpers/ClientFollower").path
        guard FileManager.default.isExecutableFile(atPath:executable) else {
            throw NSError(domain:label,code:3,userInfo:[NSLocalizedDescriptionKey:"缺少跟随助手，请重新安装"])
        }
        let config:[String:Any] = ["Label":label,"ProgramArguments":[executable,clientID,app.path],"RunAtLoad":true,"KeepAlive":true,"ThrottleInterval":10,"ProcessType":"Background"]
        let data = try PropertyListSerialization.data(fromPropertyList:config,format:.xml,options:0)
        try FileManager.default.createDirectory(at:plist.deletingLastPathComponent(),withIntermediateDirectories:true)
        _ = try launchctl(["bootout",domain+"/"+label])
        try data.write(to:plist,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:plist.path)
        guard try launchctl(["bootstrap",domain,plist.path]) == 0 else {
            try? FileManager.default.removeItem(at:plist)
            throw NSError(domain:label,code:4,userInfo:[NSLocalizedDescriptionKey:"无法启动跟随助手，请稍后重试"])
        }
    }
}
