import Cocoa
import SwiftUI

let appID = "studio.jiayu.tokenfloat"
let defaultRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions").path
let fields = ["本轮 tokens", "美元/分钟", "人民币/分钟", "输出均速", "对话 tokens", "本轮美元", "对话美元", "项目 tokens", "项目美元", "全部 tokens", "全部美元", "项目美元/分钟", "全部美元/分钟", "项目人民币", "全部人民币", "全部人民币/分钟", "tokens/分钟", "项目 tokens/分钟", "全部 tokens/分钟"]
func num(_ n: Double) -> String { n >= 1_000_000_000 ? String(format:"%.2fB",n/1_000_000_000) : n >= 1_000_000 ? String(format:"%.2fM",n/1_000_000) : n >= 1000 ? String(format:"%.1fK",n/1000) : String(format:"%.0f",n) }
func money(_ n: Double?) -> String { n.map { String(format:"≈$%.2f",$0) } ?? "价格待配置" }
func uiFont(_ size: CGFloat) -> Font { .custom("FZJunHeiS-M-GB", size:size).weight(.medium) }

struct Snapshot: Identifiable, Codable {
    var project: String, parent: String?, fork: String?
    var id: String, path: String, name: String, model: String, tier: String, running: Bool, loading: Bool
    var started: Date, updated: Date, finished: Date?, total: Usage, current: Usage, ticks: [Tick], error: String?
}
struct Checkpoint: Codable { var snapshot:Snapshot; var offset:UInt64; var previous:Usage?; var turn:String }
let cacheFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/studio.jiayu.tokenfloat/accounting-v1.json")
final class Monitor: ObservableObject {
    @Published var sessions: [Snapshot] = []
    @Published var refreshRevision = 0
    @Published var selected = UserDefaults.standard.string(forKey:"selected") ?? "auto"
    @Published var scope = UserDefaults.standard.string(forKey:"scope") ?? "conversation"
    @Published var projectChoice = UserDefaults.standard.string(forKey:"projectChoice") ?? "auto"
    @Published var pinned = UserDefaults.standard.bool(forKey:"pinnedExpanded")
    @Published var expanded = UserDefaults.standard.bool(forKey:"pinnedExpanded")
    @Published var settings = false
    @Published var windowWidth:CGFloat = CGFloat(UserDefaults.standard.object(forKey:"panelWidth") as? Double ?? 370)
    @Published var expandedHeight:CGFloat = CGFloat(UserDefaults.standard.object(forKey:"expandedHeight") as? Double ?? 483)
    @Published var opensUp = false
    @Published var detailHeight: CGFloat = 424
    @Published var animateMoney = UserDefaults.standard.object(forKey:"animateMoney") as? Bool ?? true
    @Published var now = Date()
    @Published var message = "正在寻找本地对话…"
    @Published var first = UserDefaults.standard.string(forKey:"first") ?? fields[0]
    @Published var second = UserDefaults.standard.string(forKey:"second") ?? fields[1]
    @Published var fx = UserDefaults.standard.object(forKey:"fx") as? Double ?? 7.0
    @Published var top = UserDefaults.standard.object(forKey:"top") as? Bool ?? true
    @Published var root = UserDefaults.standard.string(forKey:"root") ?? defaultRoot
    @Published var prices: [String:Price] = [:]
    private let queue = DispatchQueue(label:"studio.jiayu.tokenfloat.reader",qos:.utility)
    private var cache: [String:Session] = [:]
    private var discovered: [String] = [], count = 0, busy = false
    private var cacheRestored = false
    private var wasLoading = true
    var timer: Timer?
    init(startMonitoring: Bool = true) {
        // Verified 2026-09-13. Other model prices can be configured explicitly.
        prices = ["gpt-6-astra":Price(input:10,cached:1,output:50,write:12.5,longContext:true),
          "gpt-5.6-sol":Price(input:4,cached:0.4,output:20,write:5,longContext:true),
          "gpt-5.6-terra":Price(input:2,cached:0.2,output:12,write:2.5,longContext:true),
          "gpt-5.6-luna":Price(input:0.2,cached:0.02,output:1.2,write:0.25,longContext:true)]
        if let data = UserDefaults.standard.data(forKey:"prices"), let saved = try? JSONDecoder().decode([String:Price].self,from:data) { prices.merge(saved) { _,new in new } }
        guard startMonitoring else { return }
        timer = Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.poll() }; poll()
    }
    var active: Snapshot? {
        if selected != "auto" { return sessions.first { $0.id == selected } }
        return sessions.filter { $0.running && $0.parent == nil }.max { $0.started < $1.started } ?? sessions.max { $0.updated < $1.updated }
    }
    func save() {
        let d = UserDefaults.standard
        d.set(Double(windowWidth),forKey:"panelWidth"); d.set(Double(expandedHeight),forKey:"expandedHeight")
        d.set(pinned,forKey:"pinnedExpanded")
        d.set(animateMoney,forKey:"animateMoney")
        d.set(scope,forKey:"scope"); d.set(projectChoice,forKey:"projectChoice"); d.set(selected,forKey:"selected"); d.set(first,forKey:"first"); d.set(second,forKey:"second")
        d.set(fx,forKey:"fx"); d.set(top,forKey:"top"); d.set(root,forKey:"root")
        d.set(try? JSONEncoder().encode(prices),forKey:"prices")
        (NSApp.delegate as? AppDelegate)?.panel.level = top ? .floating : .normal
    }
    func poll() {
        now = Date(); guard !busy else { return }; busy = true
        let directory = root
        let pinnedID = selected
        queue.async { [self] in
            if !cacheRestored {
                cacheRestored = true
                if let data = try? Data(contentsOf:cacheFile), let saved = try? JSONDecoder().decode([Checkpoint].self,from:data) {
                    for item in saved where item.snapshot.path.hasPrefix(directory+"/") || (directory == defaultRoot && item.snapshot.path.hasPrefix(URL(fileURLWithPath:directory).deletingLastPathComponent().appendingPathComponent("archived_sessions").path+"/")) {
                        let s = Session(path:item.snapshot.path), v = item.snapshot
                        guard let size = (try? FileManager.default.attributesOfItem(atPath:s.path)[.size]) as? NSNumber, size.uint64Value >= item.offset else { continue }
                        s.id = v.id; s.project = v.project; s.parent = v.parent; s.fork = v.fork; s.name = v.name; s.model = v.model; s.tier = v.tier
                        s.running = v.running; s.started = v.started; s.updated = v.updated; s.finished = v.finished; s.total = v.total; s.current = v.current; s.ticks = v.ticks
                        s.offset = item.offset; s.previous = item.previous; s.turn = item.turn; cache[s.path] = s
                    }
                }
            }
            if count % 10 == 0 {
                let url = URL(fileURLWithPath:directory)
                let roots = directory == defaultRoot ? [url,url.deletingLastPathComponent().appendingPathComponent("archived_sessions")] : [url]
                var files: [(String,Date)] = []
                for rootURL in roots { if let e = FileManager.default.enumerator(at:rootURL,includingPropertiesForKeys:[.contentModificationDateKey],options:[.skipsHiddenFiles]) {
                    for case let f as URL in e where f.pathExtension == "jsonl" {
                        files.append((f.path,(try? f.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast))
                    }
                }
                }
                discovered = Array(files.sorted { $0.1 > $1.1 }.map { $0.0 })
            }
            count += 1
            let pinned = cache.values.filter { $0.id == pinnedID }.map { $0.path }
            let wanted = Set(discovered + pinned)
            cache = cache.filter { wanted.contains($0.key) }
            for p in wanted { if cache[p] == nil { cache[p] = Session(path:p) }; cache[p]?.readMore() }
            let result = cache.values.map { s in Snapshot(project:s.project,parent:s.parent,fork:s.fork,id:s.id,path:s.path,name:s.name,model:s.model,tier:s.tier,running:s.running,loading:s.loading,started:s.started,updated:s.updated,finished:s.finished,total:s.total,current:s.current,ticks:s.ticks,error:s.error) }.sorted { $0.updated > $1.updated }
            let stillLoading = result.contains { $0.loading }
            if count % 30 == 0 || (wasLoading && !stillLoading) {
                let checkpoints = result.compactMap { v -> Checkpoint? in
                    guard let session = cache[v.path] else { return nil }
                    return Checkpoint(snapshot:v,offset:session.offset-UInt64(session.pending.count),previous:session.previous,turn:session.turn)
                }
                if let data = try? JSONEncoder().encode(checkpoints) {
                    try? FileManager.default.createDirectory(at:cacheFile.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                    try? data.write(to:cacheFile,options:.atomic)
                    try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:cacheFile.path)
                }
            }
            wasLoading = stillLoading
            DispatchQueue.main.async {
                self.sessions = result; self.refreshRevision += 1; self.busy = false
                self.message = result.isEmpty ? "未找到日志，请在设置中选择 sessions 目录" : ""
            }
        }
    }
    func cost(_ ticks: [Tick]) -> Double? {
        var sum = 0.0
        for t in ticks {
            guard let p = prices[t.model] else { return nil }
            sum += p.cost(t.usage,multiplier:["priority","fast"].contains(t.tier) ? 2 : 1)
        }
        return sum
    }
    var projects: [String] { Array(Set(sessions.map { $0.project })).sorted() }
    var chosenProject: String { projectChoice == "auto" ? (active?.project ?? "未归类") : projectChoice }
    var loadingCount: Int { sessions.filter { $0.loading }.count }
    // Only compare replayed prefixes against the actual parent, never unrelated sessions.
    func ownTicks(_ s: Snapshot) -> [Tick] {
        guard let fork = s.fork, let parent = sessions.first(where: { $0.id == fork }) else { return s.ticks }
        return removeInheritedPrefix(s.ticks,parent.ticks)
    }
    func projectTicks(_ project: String) -> [Tick] { sessions.filter { $0.project == project }.flatMap(ownTicks) }
    var allTicks: [Tick] { sessions.flatMap(ownTicks) }
    var displayTicks: [Tick] { scope == "all" ? allTicks : scope == "project" ? projectTicks(chosenProject) : active?.ticks ?? [] }
    // Display the priced subtotal; missing model prices remain visible in details.
    func costText(_ ticks: [Tick]) -> String {
        let known = ticks.filter { prices[$0.model] != nil }
        guard ticks.isEmpty || !known.isEmpty else { return "—" }
        return money(cost(known))
    }
    func cnyText(_ ticks:[Tick]) -> String {
        let known = ticks.filter { prices[$0.model] != nil }
        guard ticks.isEmpty || !known.isEmpty else { return "—" }
        return String(format:"≈¥%.2f",(cost(known) ?? 0)*fx)
    }
    func lastMinute(_ ticks:[Tick]) -> [Tick] { ticks.filter { $0.time > now.addingTimeInterval(-60) && $0.time <= now } }
    func currentTicks(_ s: Snapshot) -> [Tick] { s.ticks.filter { $0.time >= s.started } }
    func recent(_ s: Snapshot) -> [Tick] { s.ticks.filter { $0.time > now.addingTimeInterval(-60) && $0.time <= now && $0.time >= s.started } }
    func rate(_ s: Snapshot) -> Double? { cost(recent(s)) }
    func tokenValue(_ field:String) -> Double? {
        if field == "全部 tokens" { return loadingCount == 0 ? allTicks.reduce(0) { $0+$1.usage.total } : nil }
        if field == "项目 tokens" { return loadingCount == 0 ? projectTicks(chosenProject).reduce(0) { $0+$1.usage.total } : nil }
        guard let s = active, !s.loading else { return nil }
        if field == "本轮 tokens" { return s.current.total }
        if field == "对话 tokens" { return s.total.total }
        return nil
    }
    func value(_ field: String) -> String {
        switch field {
        case "全部 tokens/分钟": return String(format:"%.0f",lastMinute(allTicks).reduce(0) { $0+$1.usage.total })+" tokens/分"
        case "项目 tokens/分钟": return String(format:"%.0f",lastMinute(projectTicks(chosenProject)).reduce(0) { $0+$1.usage.total })+" tokens/分"
        case "项目 tokens": return num(projectTicks(chosenProject).reduce(0) { $0+$1.usage.total }) + (loadingCount > 0 ? " · 读取中" : " tokens")
        case "项目美元": return costText(projectTicks(chosenProject))
        case "全部 tokens": return num(allTicks.reduce(0) { $0+$1.usage.total }) + (loadingCount > 0 ? " · 读取中" : " tokens")
        case "全部美元": return costText(allTicks)
        case "项目美元/分钟": return costText(lastMinute(projectTicks(chosenProject)))+"/分"
        case "全部美元/分钟": return costText(lastMinute(allTicks))+"/分"
        case "项目人民币": return cnyText(projectTicks(chosenProject))
        case "全部人民币": return cnyText(allTicks)
        case "全部人民币/分钟": return cnyText(lastMinute(allTicks))+"/分"
        default: break
        }
        guard let s = active else { return "—" }
        if s.loading { return "读取中…" }
        switch field {
        case "tokens/分钟": return String(format:"%.0f",recent(s).reduce(0) { $0+$1.usage.total })+" tokens/分"
        case "本轮 tokens": return num(s.current.total)+" tokens"
        case "对话 tokens": return num(s.total.total)+" tokens"
        case "美元/分钟": return s.running ? money(rate(s))+"/分" : "已结束"
        case "人民币/分钟": return s.running ? rate(s).map { String(format:"≈¥%.2f/分",$0*fx) } ?? "价格待配置" : "已结束"
        case "输出均速": return s.running ? String(format:"%.1f tok/s",recent(s).reduce(0) { $0+$1.usage.output }/60) : "已结束"
        case "本轮美元": return costText(currentTicks(s))
        case "对话美元": return costText(s.ticks)
        default: return "—"
        }
    }
}

struct DragHandle: NSViewRepresentable {
    class Handle: NSView {
        private var startMouse = NSPoint.zero
        private var startOrigin = NSPoint.zero
        override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
        override func mouseDown(with event:NSEvent) { startMouse = window?.convertPoint(toScreen:event.locationInWindow) ?? .zero; startOrigin = window?.frame.origin ?? .zero }
        override func mouseDragged(with event:NSEvent) {
            let p = window?.convertPoint(toScreen:event.locationInWindow) ?? startMouse
            window?.setFrameOrigin(NSPoint(x:startOrigin.x+p.x-startMouse.x,y:startOrigin.y+p.y-startMouse.y))
        }
        override func resetCursorRects() { addCursorRect(bounds,cursor:.openHand) }
    }
    func makeNSView(context:Context) -> NSView { let v = Handle(); v.setAccessibilityLabel("拖动悬浮窗"); return v }
    func updateNSView(_ nsView:NSView,context:Context) {}
}
struct MainView: View {
    @ObservedObject var m: Monitor
    let accent = Color(red:0.45,green:0.91,blue:0.78)
    var body: some View {
        VStack(spacing:0) {
            if m.expanded && m.opensUp { expandedContent }
            header
            if m.expanded && !m.opensUp { expandedContent }
        }.frame(width:m.windowWidth).background(GlassSurface(radius:22))
         .clipShape(RoundedRectangle(cornerRadius:22))
         .overlay(alignment:.bottomTrailing) {
             ResizeHandle().frame(width:16,height:16).padding(2).help("拖动调整窗口大小")
         }

         .environment(\.refreshRevision,m.refreshRevision)
         .foregroundStyle(Color.white).preferredColorScheme(.dark).font(uiFont(12))
    }
    var header: some View {
            HStack(spacing:10) {
                Image(systemName:"circle.grid.2x2.fill").foregroundStyle(.secondary).frame(width:20,height:34).overlay(DragHandle()).help("按住这里拖动位置")
                Button { toggleDetails() } label: {
                    HStack(spacing:12) {
                        Circle().fill(m.active?.running == true ? accent : Color.gray).frame(width:7,height:7)
                        VStack(alignment:.leading,spacing:3) { Text(m.first).font(.system(size:9)).foregroundStyle(.secondary); fieldValue(m.first).id(m.first + m.selected + m.chosenProject).font(.system(size:14,weight:.semibold,design:.monospaced)) }
                        Rectangle().fill(.white.opacity(0.12)).frame(width:1,height:24)
                        VStack(alignment:.leading,spacing:3) { Text(m.second).font(.system(size:9)).foregroundStyle(.secondary); fieldValue(m.second).id(m.second + m.selected + m.chosenProject).font(.system(size:13,weight:.medium,design:.monospaced)).foregroundStyle(accent) }
                        Spacer(minLength:0)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).frame(maxWidth:.infinity).accessibilityLabel("点击数值切换明细")
                DisclosureControl(expanded:m.expanded,action:toggleDetails)
                    .frame(width:36,height:42).background(GlassSurface(radius:12))
            }.padding(.horizontal,12).frame(height:58)
    }
    func toggleDetails() {
        m.expanded.toggle()
        if !m.expanded { m.pinned = false; m.save() }
        m.settings = false; resize()
    }
    @ViewBuilder func fieldValue(_ field:String) -> some View {
        if field.hasSuffix("tokens") {
            TokenCounter(value:m.tokenValue(field),fallback:m.value(field),animated:m.animateMoney)
                .id(field + (field == "全部 tokens" ? "all" : field == "项目 tokens" ? m.chosenProject : (m.active?.id ?? "none") + (field == "本轮 tokens" ? String(m.active?.started.timeIntervalSince1970 ?? 0) : "")))
        } else { MoneyTicker(text:m.value(field),enabled:m.animateMoney) }
    }
    var expandedContent: some View {
        Group {
                Divider().overlay(.white.opacity(0.07))
                ScrollView {
                    VStack(alignment:.leading,spacing:15) {
                        HStack {
                            Image(nsImage:NSImage(contentsOfFile:Bundle.main.path(forResource:"logo",ofType:"png") ?? "") ?? NSImage()).resizable().frame(width:22,height:22)
                            Text("JIAYU · TOKEN FLOAT").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(1.2).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                m.pinned.toggle(); m.expanded = true; m.settings = false; m.save(); resize()
                            } label: { Image(systemName:m.pinned ? "pin.fill" : "pin").foregroundStyle(m.pinned ? Color.mint : Color.white) }
                            .buttonStyle(GlassButtonStyle()).help(m.pinned ? "取消固定，点击外部自动收起" : "固定展开，保持详细信息")
                            .accessibilityLabel(m.pinned ? "取消固定展开" : "固定展开")
                            Button { m.settings.toggle(); resize() } label:{ Image(systemName:"slider.horizontal.3") }.buttonStyle(GlassButtonStyle()).help("显示与计价设置").accessibilityLabel("设置")
                            Button { NSApp.terminate(nil) } label:{ Image(systemName:"xmark") }.buttonStyle(GlassButtonStyle()).help("退出悬浮窗").accessibilityLabel("退出")
                        }
                        if m.settings { SettingsView(m:m) }
                        else { details }
                    }.padding(18)
                }.frame(height:m.detailHeight)
            }
    }
    func resize() { DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.resize() } }
    var details: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:6) {
                ForEach([("conversation","对话"),("project","分项目"),("all","全部项目")],id:\.0) { key,label in
                    Button { m.scope = key; m.save() } label: {
                        Text(label).frame(maxWidth:.infinity).foregroundStyle(m.scope == key ? Color.mint : Color.white.opacity(0.7))
                    }.buttonStyle(GlassButtonStyle())
                     .overlay(RoundedRectangle(cornerRadius:12).stroke(m.scope == key ? Color.mint.opacity(0.55) : .clear,lineWidth:1).allowsHitTesting(false))
                     .accessibilityLabel(label).accessibilityAddTraits(m.scope == key ? .isSelected : [])
                }
            }
            if m.scope != "conversation" { projectDetails }
            else { conversationDetails }
        }
    }
    var conversationDetails: some View {
        VStack(alignment:.leading,spacing:14) {
            Picker("监测",selection:$m.selected) {
                Text("自动 · 最近运行的任务").tag("auto")
                ForEach(m.sessions) { s in Text("\(s.name) · \(s.id.prefix(8))\(s.running ? " · 运行" : "")").tag(s.id) }
            }.onChange(of:m.selected) { _ in m.save() }
            if let s = m.active {
                HStack { Text(s.model).font(.system(size:12,weight:.semibold,design:.monospaced)); Spacer(); Text(s.loading ? "读取中" : s.running ? "运行中" : "已结束").foregroundStyle(accent) }
                if let e = s.error { Text(e).foregroundStyle(.orange) }
                HStack(spacing:12) {
                    tile("本轮累计",num(s.current.total),"tokens · 输入 + 输出",rawTokens:s.loading ? nil : s.current.total)
                    tile("近 60 秒输出均速",String(format:"%.1f",m.recent(s).reduce(0){$0+$1.usage.output}/60),"tok/s · 按日志批次统计")
                }
                row("对话累计 tokens",String(format:"%.0f",s.total.total))
                row("本轮输入 / 缓存命中",num(s.current.input)+" / "+num(s.current.cached))
                row("本轮输出 / 其中推理",num(s.current.output)+" / "+num(s.current.reasoning))
                row("本轮 API 等价",money(m.cost(m.currentTicks(s))))
                row("对话 API 等价",money(m.cost(s.ticks)))
                row("本轮人民币等价",m.cost(m.currentTicks(s)).map { String(format:"≈¥%.2f",$0*m.fx) } ?? "价格待配置")
                row("近 60 秒费用",money(m.rate(s))+"/分钟")
                Text("仅统计所选对话，不合并子任务。用量按日志批次更新；费用为模型 token 的 API 等价估算，不含工具费用。人民币采用手动参考汇率 \(m.fx, specifier:"%.4f")。").font(.system(size:10)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Text("日志更新：\(s.updated == .distantPast ? "等待数据" : s.updated.formatted(date:.omitted,time:.standard)) · v2.1.0").font(.system(size:10)).foregroundStyle(.secondary)
            } else { Text(m.message).foregroundStyle(.secondary) }
        }
    }
    var projectDetails: some View {
        VStack(alignment:.leading,spacing:14) {
            if m.scope == "project" {
                Picker("项目",selection:$m.projectChoice) {
                    Text("跟随当前任务").tag("auto")
                    ForEach(m.projects,id:\.self) { p in Text(p.replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")).tag(p) }
                }.onChange(of:m.projectChoice) { _ in m.save() }
                Text(m.chosenProject).font(.system(size:10)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            let ticks = m.displayTicks
            let u = ticks.reduce(Usage()) { acc,t in var v = acc; v.add(t.usage); return v }
            tile(m.scope == "all" ? "全部项目累计" : "项目累计",num(u.total),"tokens · 已记录的输入 + 输出",rawTokens:m.loadingCount == 0 ? u.total : nil)
            row("API 等价累计",m.costText(ticks))
            row("人民币等价",m.cnyText(ticks))
            row("输入 / 缓存",num(u.input)+" / "+num(u.cached))
            row("输出 / 其中推理",num(u.output)+" / "+num(u.reasoning))
            let recent = ticks.filter { $0.time > m.now.addingTimeInterval(-60) && $0.time <= m.now }
            row("近 60 秒 tokens",String(format:"%.0f",recent.reduce(0) { $0+$1.usage.total })+" tokens/分")
            row("近 60 秒费用",m.costText(recent)+"/分钟")
            row(m.scope == "all" ? "全部人民币/分钟" : "项目人民币/分钟",m.cnyText(recent)+"/分")
            row("项目 / 对话数", m.scope == "all" ? "\(m.projects.count) / \(m.sessions.count)" : "1 / \(m.sessions.filter { $0.project == m.chosenProject }.count)")
            if m.sessions.contains(where: { $0.error != nil }) { Text("部分日志无法读取，汇总不完整").foregroundStyle(.orange) }
            if m.loadingCount > 0 { Text("正在读取历史：还有 \(m.loadingCount) 份日志，当前为部分统计").foregroundStyle(.orange) }
            let missing = Array(Set(ticks.filter { m.prices[$0.model] == nil }.map { $0.model })).sorted()
            if !missing.isEmpty { Text("金额仅含已配置模型，未计入："+missing.joined(separator:"、")).font(.system(size:10)).foregroundStyle(.orange) }
            Text("按完整工作目录分项目，包含已记录用量的子任务；分叉历史前缀去重。仅覆盖本机可读取的日志，不等于账户账单。汇率为手动参考值。").font(.system(size:10)).foregroundStyle(.secondary)
        }
    }
    func row(_ title:String,_ value:String) -> some View { HStack { Text(title).foregroundStyle(.secondary); Spacer(); MoneyTicker(text:value,enabled:m.animateMoney).id(title + m.scope + m.selected + m.chosenProject).font(.system(size:12,weight:.medium,design:.monospaced)) } }
    func tile(_ title:String,_ value:String,_ foot:String,rawTokens:Double? = nil) -> some View {
        VStack(alignment:.leading,spacing:7) { Text(title).font(.system(size:10)).foregroundStyle(.secondary); Group { if foot.hasPrefix("tokens") { TokenCounter(value:rawTokens,fallback:value,animated:m.animateMoney) } else { MoneyTicker(text:value,enabled:m.animateMoney) } }.id(title + m.scope + (m.active?.id ?? "") + m.chosenProject).font(.system(size:27,weight:.medium,design:.rounded)).foregroundStyle(accent); Text(foot).font(.system(size:9)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(12).background(GlassSurface(radius:16))
    }
}
struct SettingsView: View {
    @ObservedObject var m:Monitor
    @State var followClient = FollowSettings.enabled
    @State var fxText = ""
    @State var priceModel = ""
    @State var input = ""
    @State var cached = ""
    @State var output = ""
    @State var write = ""
    @State var longContext = false
    @State var note = ""
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Toggle("跟随 Codex 客户端开启／退出",isOn:Binding(get:{ followClient },set:{ next in
                do { try FollowSettings.setEnabled(next); followClient = next; note = next ? "已开启客户端跟随" : "已关闭客户端跟随" }
                catch { note = error.localizedDescription }
            }))
            Text("客户端完全退出时关闭悬浮窗；仅关窗口不退出。手动退出悬浮窗后，下次启动客户端才重新打开。").font(.system(size:10)).foregroundStyle(.secondary)
            Text("折叠时显示").font(.headline)
            Picker("第一项",selection:$m.first) { ForEach(fields,id:\.self) { Text($0).tag($0) } }.onChange(of:m.first) { _ in m.save() }
            Picker("第二项",selection:$m.second) { ForEach(fields,id:\.self) { Text($0).tag($0) } }.onChange(of:m.second) { _ in m.save() }
            Toggle("数值变化动画",isOn:$m.animateMoney).onChange(of:m.animateMoney) { _ in m.save() }
            Toggle("始终置顶",isOn:$m.top).onChange(of:m.top) { _ in m.save() }
            HStack { Text("1 美元 = 人民币"); TextField("手动汇率",text:$fxText).frame(width:75); Button("保存") { if let v = Double(fxText), v > 0, v.isFinite { m.fx = v; m.save(); note = "参考汇率已保存" } else { note = "请输入大于 0 的汇率" } } }
            Divider()
            Text("模型价格 · 美元 / 百万 tokens").font(.headline)
            TextField("模型名称（精确匹配）",text:$priceModel)
            HStack { TextField("输入",text:$input); TextField("缓存读取",text:$cached) }
            HStack { TextField("输出",text:$output); TextField("缓存写入",text:$write) }
            Toggle("超过 272K：输入 ×2、输出 ×1.5",isOn:$longContext).font(.system(size:11))
            Button("保存此模型价格") {
                let values = [input,cached,output,write].compactMap(Double.init)
                guard !priceModel.trimmingCharacters(in:.whitespaces).isEmpty, values.count == 4, values.allSatisfy({$0 >= 0 && $0.isFinite}) else { note = "请填写有效的模型名称和四项非负价格"; return }
                m.prices[priceModel.trimmingCharacters(in:.whitespaces)] = Price(input:values[0],cached:values[1],output:values[2],write:values[3],longContext:longContext); m.save(); note = "价格已保存，历史估算已重算"
            }
            Text("内置 Astra / 5.6 标准价核对于 2026-09-13；日志标记 fast / priority 时乘 2。未知模型需填写价格。").font(.system(size:10)).foregroundStyle(.secondary)
            Divider()
            Button("选择本地 sessions 日志目录…") {
                let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.showsHiddenFiles = true
                if panel.runModal() == .OK, let u = panel.url { m.root = u.path; m.selected = "auto"; m.save(); note = "目录已保存，10 秒内重新扫描" }
            }
            Text(m.root).font(.system(size:9)).foregroundStyle(.secondary).lineLimit(2)
            Text(note).font(.system(size:10)).foregroundStyle(.green)
        }.buttonStyle(GlassButtonStyle()).textFieldStyle(.roundedBorder).onAppear {
            fxText = String(m.fx); priceModel = m.active?.model ?? "gpt-6-astra"
            if let p = m.prices[priceModel] { input = String(p.input); cached = String(p.cached); output = String(p.output); write = String(p.write); longContext = p.longContext }
        }
    }
}
final class FloatingPanel:NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey:Bool { acceptsKeyboard }
    override var canBecomeMain:Bool { false }
}
final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var panel:FloatingPanel!, monitor:Monitor!, status:NSStatusItem!
    var anchor = NSRect(x:120,y:200,width:370,height:58)
    var changingFrame = false
    var wasExpanded = false
    var lastOrigin = NSPoint.zero
    var passItem:NSMenuItem!
    var outsideMonitor:Any?
    var localMonitor:Any?

    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        monitor = Monitor()
        panel = FloatingPanel(contentRect:NSRect(x:120,y:200,width:370,height:58),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.appearance = NSAppearance(named:.darkAqua)
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.title = "JIAYU Token Float 2.1.0"; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.hidesOnDeactivate = false
        panel.level = monitor.top ? .floating : .normal; panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; panel.delegate = self
        panel.contentView = FirstClickHostingView(rootView:MainView(m:monitor)); panel.isMovableByWindowBackground = false
        let d = UserDefaults.standard
        if d.object(forKey:"windowX") != nil { panel.setFrameOrigin(NSPoint(x:d.double(forKey:"windowX"),y:d.double(forKey:"windowY"))) }
        panel.ignoresMouseEvents = false
        anchor = panel.frame; anchor.size.width = monitor.windowWidth; resize(); panel.orderFrontRegardless()
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength); status.button?.image = NSImage(systemSymbolName:"gauge.with.dots.needle.50percent",accessibilityDescription:"Token Float")
        let menu = NSMenu()
        menu.addItem(withTitle:"显示悬浮窗",action:#selector(show),keyEquivalent:"")
        passItem = menu.addItem(withTitle:"鼠标穿透（再次点击恢复）",action:#selector(togglePass),keyEquivalent:"")
        menu.addItem(withTitle:"重置窗口位置",action:#selector(resetPosition),keyEquivalent:"")
        menu.addItem(NSMenuItem.separator()); menu.addItem(withTitle:"退出 Token Float",action:#selector(quit),keyEquivalent:"q")
        for item in menu.items { item.target = self }; status.menu = menu
    }
    @objc func show() { panel.ignoresMouseEvents = false; passItem.state = .off; panel.orderFrontRegardless() }
    @objc func togglePass() {
        panel.ignoresMouseEvents.toggle(); passItem.state = panel.ignoresMouseEvents ? .on : .off
        if panel.ignoresMouseEvents { monitor.expanded = false; monitor.settings = false; resize() }
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func resetPosition() { anchor.origin = NSPoint(x:120,y:200); resize(); saveAnchor() }
    func resize() {
        guard let screen = NSScreen.screens.first(where:{$0.frame.intersects(anchor)}) ?? NSScreen.main else { return }
        if !wasExpanded && monitor.expanded { anchor = panel.frame }
        monitor.windowWidth = min(screen.visibleFrame.width,max(320,min(800,monitor.windowWidth)))
        anchor.size.width = monitor.windowWidth
        // Expansion may avoid Dock/menu bar, but never rewrite the user's collapsed position.
        if !NSScreen.screens.contains(where: { $0.frame.intersects(anchor) }) {
            anchor = PanelGeometry.clamp(anchor,to:screen.visibleFrame)
        }
        let expansionAnchor = PanelGeometry.clamp(anchor,to:screen.visibleFrame)
        let height:CGFloat = monitor.expanded ? (monitor.settings ? max(579,monitor.expandedHeight) : monitor.pinned ? max(650,monitor.expandedHeight) : monitor.expandedHeight) : 58
        let layout = PanelGeometry.expanded(anchor:expansionAnchor,height:height,screen:screen.visibleFrame)
        monitor.opensUp = layout.up
        monitor.detailHeight = max(0,layout.frame.height-59)
        let shouldRelease = panel.acceptsKeyboard && !monitor.settings
        panel.acceptsKeyboard = monitor.expanded && monitor.settings
        if shouldRelease { panel.makeFirstResponder(nil); panel.orderOut(nil) }
        changingFrame = true
        panel.setFrame(monitor.expanded ? layout.frame : anchor,display:true)
        lastOrigin = panel.frame.origin
        changingFrame = false; wasExpanded = monitor.expanded
        if shouldRelease { panel.orderFrontRegardless() }
        saveAnchor()
        updateOutsideMonitor()
    }
    func userResize(width:CGFloat,height:CGFloat) {
        monitor.windowWidth = max(320,min(800,width))
        if monitor.expanded { monitor.expandedHeight = max(300,min(1000,height)) }
        resize(); monitor.save()
    }
    func saveAnchor() {
        UserDefaults.standard.set(anchor.minX,forKey:"windowX")
        UserDefaults.standard.set(anchor.minY,forKey:"windowY")
    }
    func windowDidMove(_ notification:Notification) {
        guard !changingFrame else { return }
        let origin = panel.frame.origin
        anchor.origin.x += origin.x-lastOrigin.x; anchor.origin.y += origin.y-lastOrigin.y
        lastOrigin = origin; saveAnchor()
    }
    func stopOutsideMonitor() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }; outsideMonitor = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
    }
    func collapseOutside() {
        guard shouldAutoCollapse(expanded:monitor.expanded,pinned:monitor.pinned,inside:panel.frame.contains(NSEvent.mouseLocation),modal:NSApp.modalWindow != nil || panel.attachedSheet != nil) else { return }
        monitor.expanded = false; monitor.settings = false; resize()
    }
    func updateOutsideMonitor() {
        guard monitor.expanded && !monitor.pinned else { stopOutsideMonitor(); return }
        guard outsideMonitor == nil else { return }
        // Observe mouse clicks only. Never intercept or consume another app's input.
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown,.otherMouseDown]) { [weak self] _ in self?.collapseOutside() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown,.otherMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel, event.window?.level == .normal { self.collapseOutside() }
            return event
        }
    }
    func applicationWillTerminate(_ notification:Notification) { stopOutsideMonitor(); monitor?.timer?.invalidate(); monitor?.save() }
}
@main enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--enable-follow") || CommandLine.arguments.contains("--disable-follow") {
            do { try FollowSettings.setEnabled(CommandLine.arguments.contains("--enable-follow")) }
            catch { fputs(error.localizedDescription+"\n",stderr); exit(1) }; return
        }
        if CommandLine.arguments.contains("--self-test") { selfTests(); return }
        let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run()
    }
}
