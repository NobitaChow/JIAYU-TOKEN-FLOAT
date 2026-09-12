import Foundation

// Usage normalization and saturating differences adapted from ccusage
// rust/adapters/codex/src/parser.rs (MIT, Copyright 2025 ryoppippi).
struct Usage: Equatable, Codable {
    var input = 0.0, cached = 0.0, write = 0.0, output = 0.0, reasoning = 0.0
    var total: Double { input + output }
    init() {}
    init(_ d: [String: Any]) {
        func n(_ k: String) -> Double { max(0, (d[k] as? NSNumber)?.doubleValue ?? 0) }
        input = n("input_tokens"); cached = min(input, n("cached_input_tokens"))
        write = min(input - cached, n("cache_write_input_tokens"))
        output = n("output_tokens"); reasoning = min(output, n("reasoning_output_tokens"))
    }
    func subtract(_ p: Usage) -> Usage {
        var u = Usage()
        u.input = max(0,input-p.input); u.cached = min(u.input,max(0,cached-p.cached))
        u.write = min(u.input-u.cached,max(0,write-p.write)); u.output = max(0,output-p.output)
        u.reasoning = min(u.output,max(0,reasoning-p.reasoning)); return u
    }
    mutating func add(_ u: Usage) { input += u.input; cached += u.cached; write += u.write; output += u.output; reasoning += u.reasoning }
}
struct Price: Codable {
    var input: Double, cached: Double, output: Double, write: Double
    var longContext: Bool = false
    func cost(_ u: Usage, multiplier: Double = 1) -> Double {
        let long = longContext && u.input > 272_000
        return ((max(0,u.input-u.cached-u.write)*input + u.cached*cached + u.write*write)*(long ? 2 : 1) + u.output*output*(long ? 1.5 : 1))*multiplier/1_000_000
    }
}
struct Tick: Codable {
    var time: Date, usage: Usage, model: String, tier: String, turn: String
}
final class Session {
    let path: String
    var project = "未归类", parent: String?, fork: String?
    var id: String, name = "对话", model = "未知模型", tier = "default", turn = ""
    var started = Date.distantPast, updated = Date.distantPast, finished: Date?
    var running = false, previous: Usage?, total = Usage(), current = Usage()
    var ticks: [Tick] = [], offset: UInt64 = 0, pending = Data(), loading = true, error: String?
    init(path: String) { self.path = path; self.id = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
    static let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime,.withFractionalSeconds]; return f }()
    func consume(_ data: Data) {
        guard let d = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any], let p = d["payload"] as? [String:Any] else { return }
        let stamp = (d["timestamp"] as? String).flatMap { Self.iso.date(from:$0) } ?? updated
        switch d["type"] as? String {
        case "session_meta":
            id = p["id"] as? String ?? id
            parent = p["parent_thread_id"] as? String; fork = p["forked_from_id"] as? String
            if let cwd = p["cwd"] as? String { project = URL(fileURLWithPath:cwd).standardized.path; name = URL(fileURLWithPath:cwd).lastPathComponent }
        case "turn_context":
            model = p["model"] as? String ?? model
            if let t = p["service_tier"] as? String { tier = t }
        case "event_msg":
            switch p["type"] as? String {
            case "thread_settings_applied":
                if let s = p["thread_settings"] as? [String:Any] { model = s["model"] as? String ?? model; tier = s["service_tier"] as? String ?? "default" }
            case "task_started":
                let next = p["turn_id"] as? String ?? stamp.description
                if next != turn { turn = next; current = Usage(); started = stamp; finished = nil }
                running = true; updated = stamp
            case "task_complete", "turn_aborted":
                if let t = p["turn_id"] as? String, !turn.isEmpty, t != turn { return }
                running = false; finished = stamp; updated = stamp
            case "token_count":
                guard let info = p["info"] as? [String:Any] else { return }
                let cumulative = (info["total_token_usage"] as? [String:Any]).map(Usage.init)
                let last = (info["last_token_usage"] as? [String:Any]).map(Usage.init)
                var delta: Usage
                if let c = cumulative {
                    if let old = previous {
                        if c == old { return }
                        // A reset starts a new counter series, not a negative charge.
                        delta = c.input < old.input || c.output < old.output ? (last ?? c) : c.subtract(old)
                    } else { delta = c }
                    previous = c
                } else if let l = last { delta = l; if var old = previous { old.add(l); previous = old } }
                else { return }
                guard delta.total > 0 else { return }
                total.add(delta); current.add(delta); updated = stamp
                ticks.append(Tick(time:stamp,usage:delta,model:model,tier:tier,turn:turn))
            default: break
            }
        default: break
        }
    }
    func readMore() {
        do {
            let h = try FileHandle(forReadingFrom:URL(fileURLWithPath:path)); defer { try? h.close() }
            let size = try h.seekToEnd()
            if size < offset { offset = 0; pending = Data(); previous = nil; total = Usage(); current = Usage(); ticks = []; turn = ""; running = false }
            try h.seek(toOffset:offset)
            let data = try h.read(upToCount:4*1024*1024) ?? Data(); offset += UInt64(data.count); pending.append(data)
            var begin = pending.startIndex
            while let end = pending[begin...].firstIndex(of:10) {
                let line = pending[begin..<end]
                // Ignore message bodies: only parse event records and model metadata.
                if line.prefix(180).range(of:Data("\"event_msg\"".utf8)) != nil || line.prefix(180).range(of:Data("\"turn_context\"".utf8)) != nil || line.prefix(180).range(of:Data("\"session_meta\"".utf8)) != nil { consume(Data(line)) }
                begin = end+1
            }
            pending = Data(pending[begin...]); loading = offset < size; error = nil
        } catch { self.error = "无法读取日志，请重新选择日志目录"; loading = false }
    }
}

func removeInheritedPrefix(_ child:[Tick], _ parent:[Tick]) -> [Tick] {
    var count = 0
    while count < min(child.count,parent.count), child[count].usage == parent[count].usage, child[count].model == parent[count].model { count += 1 }
    return Array(child.dropFirst(count))
}
