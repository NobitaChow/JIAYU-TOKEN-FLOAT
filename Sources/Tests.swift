import Foundation
func selfTests() {
    var checks = 0
    func check(_ value:Bool,_ message:String) { precondition(value,message); checks += 1 }
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
        Snapshot(project:id,parent:nil,fork:nil,id:id,path:id,name:id,model:"gpt-6-astra",tier:"default",running:true,loading:false,started:monitor.now.addingTimeInterval(-120),updated:monitor.now,finished:nil,total:Usage(),current:Usage(),ticks:ticks,error:nil)
    }
    monitor.sessions = [snapshot("A",[sample(-59),sample(-60),sample(1)]),snapshot("B",[sample(0),sample(-10,"unknown")])]
    check(monitor.value("全部人民币/分钟") == "≈¥0.11/分", "all-project CNY minute uses both projects, excludes expired and future ticks")
    check(monitor.costText([sample(0),sample(0,"unknown")]) == "≈$0.01", "mixed-price subtotal has no pending suffix")
    check(monitor.cnyText([sample(0,"unknown")]) == "—", "unknown-only cost is not shown as zero")
    monitor.sessions = []
    check(monitor.value("全部人民币/分钟") == "≈¥0.00/分", "empty minute is zero without active conversation")
    monitor.fx = 10; monitor.sessions = [snapshot("A",[sample(0)])]
    check(monitor.value("全部人民币/分钟") == "≈¥0.08/分", "CNY minute follows configured exchange rate")
    print("PASS: \(checks) accounting and incremental-read checks")
}
