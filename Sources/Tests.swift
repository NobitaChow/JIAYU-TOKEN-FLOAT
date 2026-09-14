import Cocoa
func selfTests() {
    var checks = 0
    func check(_ value:Bool,_ message:String) { if !value { fputs("FAIL: \(message)\n",stderr); exit(1) }; checks += 1 }
    let s = Session(path:"/tmp/test.jsonl")
    func emit(_ type:String,_ payload:[String:Any],_ seconds:Int = 0) {
        let date = Date(timeIntervalSince1970:1_780_000_000+Double(seconds))
        let data = try! JSONSerialization.data(withJSONObject:["type":type,"timestamp":Session.iso.string(from:date),"payload":payload]); s.consume(data)
    }
    func usage(_ i:Int,_ c:Int,_ o:Int) -> [String:Any] { ["input_tokens":i,"cached_input_tokens":c,"output_tokens":o,"reasoning_output_tokens":o/2] }
    func token(_ total:[String:Any],_ last:[String:Any]? = nil) {
        var info:[String:Any] = ["total_token_usage":total]; if let last { info["last_token_usage"] = last }
        emit("event_msg",["type":"token_count","info":info],10)
    }
    emit("turn_context",["model":"gpt-6-astra"])
    emit("event_msg",["type":"task_started","turn_id":"A"])
    token(usage(1000,800,100),usage(1000,800,100))
    check(s.current.total == 1100,"initial usage")
    token(usage(1000,800,100),usage(1000,800,100))
    check(s.ticks.count == 1,"duplicate cumulative must not double count")
    token(usage(1500,1100,200),usage(500,300,100))
    check(s.total.total == 1700,"cumulative increments")
    check(s.total.reasoning == 100,"reasoning already included in output")
    emit("event_msg",["type":"task_complete","turn_id":"wrong"])
    check(s.running,"unrelated completion ignored")
    emit("event_msg",["type":"task_complete","turn_id":"A"])
    check(!s.running,"completion")
    emit("event_msg",["type":"task_started","turn_id":"B"],20)
    check(s.current.total == 0 && s.total.total == 1700,"new turn reset only current")
    token(usage(1600,1100,210))
    check(s.current.total == 110,"cumulative-only fallback")
    token(usage(50,0,5),usage(50,0,5))
    check(s.current.total == 165,"counter reset")
    let normalized = Usage(["input_tokens":100,"cached_input_tokens":150,"cache_write_input_tokens":50,"output_tokens":10,"reasoning_output_tokens":25])
    check(normalized.cached == 100 && normalized.write == 0 && normalized.reasoning == 10,"normalization")
    let p = Price(input:10,cached:1,output:50,write:12.5,longContext:true)
    let u = Usage(usage(1000,800,100))
    check(abs(p.cost(u)-0.0078)<0.00000001,"cached cost split")
    check(abs(p.cost(u,multiplier:2)-0.0156)<0.00000001,"priority multiplier")
    let long = Usage(usage(300000,100000,1000))
    check(abs(p.cost(long)-4.275)<0.00000001,"long context per request pricing")
    let tmp = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let row = try! JSONSerialization.data(withJSONObject:["type":"event_msg","timestamp":"2026-06-01T00:00:00.000Z","payload":["type":"token_count","info":["total_token_usage":usage(5,0,3)]]])
    try! row.prefix(row.count/2).write(to:tmp)
    let fileSession = Session(path:tmp.path); fileSession.readMore()
    check(fileSession.total.total == 0,"partial line not consumed")
    let h = try! FileHandle(forWritingTo:tmp); try! h.seekToEnd(); try! h.write(contentsOf:row.suffix(row.count-row.count/2)+Data([10])); try! h.close()
    fileSession.readMore(); check(fileSession.total.total == 8,"partial line completed")
    fileSession.readMore(); check(fileSession.total.total == 8,"poll does not duplicate")
    try! FileManager.default.removeItem(at:tmp)
    let t1 = Tick(time:Date(),usage:u,model:"gpt-6-astra",tier:"default",turn:"parent")
    let t2 = Tick(time:Date(),usage:long,model:"gpt-6-astra",tier:"default",turn:"child")
    check(removeInheritedPrefix([t1,t2],[t1]).count == 1,"fork history stripped")
    check(removeInheritedPrefix([t2],[t1]).count == 1,"fresh fork usage preserved")
    check(removeInheritedPrefix([t1,t2],[t1]).reduce(0){$0+$1.usage.total} + t1.usage.total == long.total + u.total,"project aggregate no replay double count")
    let monitor = Monitor(startMonitoring:false)
    monitor.prices = ["gpt-6-astra":p]; monitor.fx = 7
    monitor.now = Date(timeIntervalSince1970:1_800_000_000)
    func sample(_ offset:Double, _ model:String = "gpt-6-astra") -> Tick {
        Tick(time:monitor.now.addingTimeInterval(offset),usage:u,model:model,tier:"default",turn:"test")
    }
    func snapshot(_ id:String,_ ticks:[Tick]) -> Snapshot {
        Snapshot(project:id,parent:nil,fork:nil,id:id,path:id,name:id,model:"gpt-6-astra",tier:"default",running:true,loading:false,started:monitor.now.addingTimeInterval(-120),updated:monitor.now,finished:nil,total:ticks.reduce(Usage()) { acc,t in var v = acc; v.add(t.usage); return v },current:Usage(),ticks:ticks,error:nil)
    }
    monitor.sessions = [snapshot("A",[sample(-59),sample(-60),sample(1)]),snapshot("B",[sample(0),sample(-10,"unknown")])]
    check(monitor.value("全部人民币/分钟") == "≈¥0.11/分", "all-project CNY minute uses both projects, excludes expired and future ticks")
    check(monitor.costText([sample(0),sample(0,"unknown")]) == "≈$0.01", "mixed-price subtotal has no pending suffix")
    check(monitor.cnyText([sample(0,"unknown")]) == "—", "unknown-only cost is not shown as zero")
    monitor.sessions = []
    check(monitor.value("全部人民币/分钟") == "≈¥0.00/分", "empty minute is zero without active conversation")
    monitor.fx = 10; monitor.sessions = [snapshot("A",[sample(0)])]
    check(monitor.value("全部人民币/分钟") == "≈¥0.08/分", "CNY minute follows configured exchange rate")
    monitor.selected = "A"; monitor.projectChoice = "A"
    let baseline = snapshot("A",[sample(0)])
    monitor.sessions = [baseline]
    let stableFields = ["全部 tokens","项目 tokens","对话 tokens","全部美元","项目美元","对话美元","全部人民币","项目人民币"]
    let beforeRefresh = stableFields.map { monitor.value($0) }
    for _ in 0..<5 { monitor.sessions = [baseline]; monitor.refreshRevision += 1 }
    check(stableFields.map { monitor.value($0) } == beforeRefresh,"identical refreshed snapshots never accumulate tokens or money in any scope")
    monitor.sessions = [snapshot("A",[sample(0),sample(0)])]
    check(monitor.tokenValue("全部 tokens") == 2200 && monitor.tokenValue("项目 tokens") == 2200 && monitor.tokenValue("对话 tokens") == 2200,"fresh snapshot replaces all and project totals")
    check(monitor.value("全部美元") == "≈$0.02" && monitor.value("项目美元") == "≈$0.02" && monitor.value("对话美元") == "≈$0.02","all project and conversation cost recomputed from latest snapshot")
    monitor.sessions = [baseline]
    check(stableFields.map { monitor.value($0) } == beforeRefresh,"reduced snapshot lowers totals instead of adding previous display")
    let screen = NSRect(x:0,y:0,width:1440,height:900)
    let low = NSRect(x:100,y:20,width:370,height:58)
    let high = NSRect(x:100,y:800,width:370,height:58)
    let up = PanelGeometry.expanded(anchor:low,height:483,screen:screen)
    check(up.up && up.frame.minY == low.minY && up.frame.height == 483,"bottom-edge panel expands upward with fixed anchor")
    let down = PanelGeometry.expanded(anchor:high,height:483,screen:screen)
    check(!down.up && down.frame.maxY == high.maxY,"top-edge panel expands downward with fixed anchor")
    check(PanelGeometry.expanded(anchor:low,height:579,screen:screen).frame.minY == low.minY,"settings resize preserves anchor")
    check(PanelGeometry.clamp(low,to:screen) == low,"collapse restores original anchor")
    let small = NSRect(x:-800,y:0,width:800,height:400)
    let compact = PanelGeometry.expanded(anchor:NSRect(x:-700,y:170,width:370,height:58),height:579,screen:small)
    check(small.contains(compact.frame),"small secondary screen keeps panel visible")
    check(CurrencyParts("≈¥12.34/分")?.amount == 12.34,"animation parses observed rate")
    check(CurrencyParts("≈$1.20")?.suffix == "","animation distinguishes cumulative cost")
    check(CurrencyParts("—") == nil && CurrencyParts("12 tokens") == nil,"animation excludes non-currency values")
    let pair = NumericParts("12.5K / 3.0K")
    check(pair.vector.values == [12.5,3] && pair.render(pair.vector) == "12.5K / 3.0K","animate multiple token counters without changing units")
    check(NumericParts("42 tokens").render(NumberVector(values:[43])) == "43 tokens","animate integer tokens")
    check((NumberVector(values:[4,8])-NumberVector(values:[1,2])).values == [3,6],"numeric animation vector differences")
    var change = TokenDelta()
    change.observe(3_440_000_000)
    check(change.increase == 0,"initial total is not an increment")
    change.observe(3_440_001_234)
    check(change.label == "↑ +1234","exact delta remains visible even when B abbreviation is unchanged")
    change.observe(3_440_001_234)
    check(change.increase == 0,"unchanged refresh clears the previous delta")
    change.observe(3_440_001_250)
    check(change.increase == 16,"each refresh replaces rather than accumulates the delta")
    change.observe(20)
    check(change.increase == 0,"counter reset does not show positive growth")
    change.observe(nil); change.observe(3_440_001_234)
    check(change.increase == 0,"loading completion starts a fresh baseline")
    check(shouldAutoCollapse(expanded:true,pinned:false,inside:false,modal:false),"outside click collapses unpinned panel")
    check(!shouldAutoCollapse(expanded:true,pinned:true,inside:false,modal:false),"pin retains details")
    check(!shouldAutoCollapse(expanded:true,pinned:false,inside:true,modal:false),"inside click preserves panel")
    check(!shouldAutoCollapse(expanded:true,pinned:false,inside:false,modal:true),"native dialog preserves panel")
    monitor.sessions = [snapshot("A",[sample(-59),sample(-60),sample(1)]),snapshot("B",[sample(0)])]
    check(monitor.value("全部 tokens/分钟") == "2200 tokens/分","minute token total excludes expired and future events across projects")
    monitor.now = monitor.now.addingTimeInterval(62)
    check(monitor.value("全部 tokens/分钟") == "0 tokens/分","rolling token rate can decrease without reducing cumulative usage")
    let dockEdge = NSRect(x:100,y:0,width:370,height:58)
    let aboveDock = NSRect(x:0,y:80,width:1440,height:800)
    let temporary = PanelGeometry.clamp(dockEdge,to:aboveDock)
    _ = PanelGeometry.expanded(anchor:temporary,height:650,screen:aboveDock)
    check(dockEdge.minY == 0 && temporary.minY == 80,"temporary Dock avoidance never mutates collapsed anchor")
    print("PASS: \(checks) accounting and incremental-read checks")
}
