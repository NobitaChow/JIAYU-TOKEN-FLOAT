import Cocoa
import SwiftUI

enum PanelGeometry {
    static func clamp(_ frame:NSRect,to screen:NSRect) -> NSRect {
        var f = frame
        f.origin.x = max(screen.minX,min(f.minX,screen.maxX-f.width))
        f.origin.y = max(screen.minY,min(f.minY,screen.maxY-f.height))
        return f
    }
    static func expanded(anchor:NSRect,height:CGFloat,screen:NSRect) -> (frame:NSRect,up:Bool) {
        let down = anchor.maxY-screen.minY, up = screen.maxY-anchor.minY
        let upwards = down < height && up > down
        let h = min(height,upwards ? up : down)
        return (NSRect(x:anchor.minX,y:upwards ? anchor.minY : anchor.maxY-h,width:anchor.width,height:h),upwards)
    }
}

struct CurrencyParts: Equatable {
    let prefix:String, amount:Double, suffix:String
    init?(_ text:String) {
        guard text.hasPrefix("≈¥") || text.hasPrefix("≈$") else { return nil }
        prefix = String(text.prefix(2))
        let rest = text.dropFirst(2), digits = rest.prefix { $0.isNumber || $0 == "." }
        guard let n = Double(digits), n.isFinite else { return nil }
        amount = n; suffix = String(rest.dropFirst(digits.count))
    }
}
struct NumberVector: VectorArithmetic {
    var values:[Double]
    static var zero:Self { Self(values:[]) }
    static func +(lhs:Self,rhs:Self) -> Self { Self(values:(0..<max(lhs.values.count,rhs.values.count)).map { (lhs.values.indices.contains($0) ? lhs.values[$0] : 0) + (rhs.values.indices.contains($0) ? rhs.values[$0] : 0) }) }
    static func -(lhs:Self,rhs:Self) -> Self { lhs + Self(values:rhs.values.map { -$0 }) }
    mutating func scale(by rhs:Double) { values = values.map { $0*rhs } }
    var magnitudeSquared:Double { values.reduce(0) { $0+$1*$1 } }
}
struct NumericParts {
    var separators:[String] = []
    var decimals:[Int] = []
    var vector = NumberVector.zero
    init(_ text:String) {
        let regex = try! NSRegularExpression(pattern:"[0-9]+(?:\\.[0-9]+)?")
        let ns = text as NSString
        var end = 0
        for match in regex.matches(in:text,range:NSRange(location:0,length:ns.length)) {
            separators.append(ns.substring(with:NSRange(location:end,length:match.range.location-end)))
            let number = ns.substring(with:match.range)
            vector.values.append(Double(number) ?? 0)
            decimals.append(number.split(separator:".").dropFirst().first?.count ?? 0)
            end = NSMaxRange(match.range)
        }
        separators.append(ns.substring(from:end))
    }
    func render(_ values:NumberVector) -> String {
        var text = separators[0]
        for i in vector.values.indices {
            text += String(format:"%.*f",decimals[i],values.values.indices.contains(i) ? values.values[i] : vector.values[i]) + separators[i+1]
        }
        return text
    }
}
struct RollingNumbers: AnimatableModifier {
    var numbers:NumberVector
    var parts:NumericParts
    var animatableData:NumberVector { get { numbers } set { numbers = newValue } }
    func body(content:Content) -> some View { Text(parts.render(numbers)).monospacedDigit() }
}
private struct RefreshRevisionKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    var refreshRevision: Int {
        get { self[RefreshRevisionKey.self] }
        set { self[RefreshRevisionKey.self] = newValue }
    }
}
private struct MetricSample: Equatable { var text: String; var revision: Int }
private struct TokenSample: Equatable { var value: Double?; var revision: Int }

struct MoneyTicker: View {
    @Environment(\.refreshRevision) private var refreshRevision
    var text:String, enabled:Bool
    var showGain:Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = NumberVector.zero
    @State private var previous:NumericParts?
    @State private var gain:String?
    @State private var pulse = false
    @State private var declining = false
    @State private var revision = 0
    var body:some View {
        let parts = NumericParts(text)
        ViewThatFits(in:.horizontal) {
            HStack(alignment:.firstTextBaseline,spacing:5) {
                amount(parts)
                increment
            }.fixedSize(horizontal:true,vertical:false)
            VStack(alignment:.leading,spacing:2) {
                amount(parts).lineLimit(1).minimumScaleFactor(0.7)
                increment.lineLimit(1).minimumScaleFactor(0.7)
            }
        }
            .onAppear { previous = parts; displayed = parts.vector }
            .onChange(of:MetricSample(text:text,revision:refreshRevision)) { sample in
                let next = NumericParts(sample.text)
                revision += 1; let token = revision
                gain = nil; pulse = false
                if let old = previous, enabled, !reduceMotion,
                   next.separators == old.separators, next.decimals == old.decimals,
                   next.vector != old.vector {
                    withAnimation(.linear(duration:0.85)) { displayed = next.vector }
                    let delta = (next.vector-old.vector).values
                    if delta.count == 1, let difference = delta.first, difference != 0 {
                        pulse = true; declining = difference < 0
                        let prefix = next.separators[0].replacingOccurrences(of:"≈",with:"")
                        if showGain { gain = (declining ? "↓ -" : "↑ +") + prefix + String(format:"%.*f",next.decimals[0],abs(difference)) + next.separators.last! }
                    }
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.9) {
                        if revision == token { gain = nil; pulse = false }
                    }
                } else { displayed = next.vector }
                previous = next
            }
            .onChange(of:enabled) { _ in gain = nil; pulse = false; displayed = NumericParts(text).vector }
            .accessibilityLabel(text)
    }
    private func amount(_ parts:NumericParts) -> some View {
        Text("").modifier(RollingNumbers(numbers:displayed,parts:parts))
            .foregroundStyle(pulse ? (declining ? Color.red : Color.green) : Color.primary)
    }
    @ViewBuilder private var increment:some View {
        if let gain {
            Text(gain).font(.system(size:9,weight:.semibold,design:.monospaced))
                .foregroundStyle(declining ? Color.red : Color.green)
                .allowsHitTesting(false)
        }
    }

}

struct GlassSurface: View {
    var radius:CGFloat = 18
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body:some View {
        RoundedRectangle(cornerRadius:radius)
            .fill(reduceTransparency ? AnyShapeStyle(Color(red:0.12,green:0.16,blue:0.18)) : AnyShapeStyle(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius:radius).fill(Color.black.opacity(reduceTransparency ? 0 : 0.32)))
            .overlay {
                RoundedRectangle(cornerRadius:radius).fill(LinearGradient(colors:[.white.opacity(0.18),.white.opacity(0.025),Color.mint.opacity(0.07)],startPoint:.topLeading,endPoint:.bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius:radius).stroke(LinearGradient(colors:[.white.opacity(0.5),.white.opacity(0.06),.white.opacity(0.22)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.8)
            }.allowsHitTesting(false)
    }
}
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration) -> some View {
        configuration.label.padding(.horizontal,9).padding(.vertical,7)
            .background(GlassSurface(radius:12))
            .brightness(configuration.isPressed ? 0.12 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.15),value:configuration.isPressed)
    }
}

func shouldAutoCollapse(expanded:Bool,pinned:Bool,inside:Bool,modal:Bool) -> Bool {
    expanded && !pinned && !inside && !modal
}
struct TokenDelta {
    private(set) var previous:Double?
    private(set) var increase:Double = 0
    mutating func observe(_ value:Double?) {
        guard let value, value.isFinite else { previous = nil; increase = 0; return }
        if let previous {
            increase = max(0,value-previous)
        } else { increase = 0 }
        previous = value
    }
    var label:String { "↑ +" + String(format:"%.0f",increase) }
}
struct TokenCounter: View {
    @Environment(\.refreshRevision) private var refreshRevision
    var value:Double?
    var fallback:String
    var animated:Bool
    @State private var delta = TokenDelta()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashRevision = 0
    @State private var dimmed = false
    var body:some View {
        HStack(alignment:.firstTextBaseline,spacing:4) {
            MoneyTicker(text:value.map(num) ?? fallback,enabled:animated && value != nil,showGain:false)
            if delta.increase > 0 {
                Text(delta.label).font(.system(size:10,weight:.semibold,design:.monospaced))
                    .foregroundStyle(.mint).opacity(dimmed ? 0.2 : 1)
                    .animation(animated && !reduceMotion ? .easeInOut(duration:0.12) : nil,value:dimmed).help("最近一次记录增加了 \(String(format:"%.0f",delta.increase)) tokens；不代表每秒速度")
            }
        }.lineLimit(1).minimumScaleFactor(0.65)
         .onAppear { delta.observe(value) }
         .onChange(of:TokenSample(value:value,revision:refreshRevision)) { sample in
             let next = sample.value
             let old = delta.previous
             delta.observe(next)
             if let old, let next, next > old { flashRevision += 1 }
         }
         .task(id:flashRevision) {
             dimmed = false
             guard flashRevision > 0, animated, !reduceMotion else { return }
             for _ in 0..<3 {
                 guard !Task.isCancelled, animated, !reduceMotion else { dimmed = false; return }
                 dimmed = true
                 do { try await Task.sleep(nanoseconds:160_000_000) } catch { dimmed = false; return }
                 dimmed = false
                 do { try await Task.sleep(nanoseconds:160_000_000) } catch { return }
             }
         }
         .onChange(of:animated) { _ in dimmed = false }
         .onChange(of:reduceMotion) { _ in dimmed = false }
    }
}

// Native first-click handling for a non-key, non-activating utility panel.
final class FirstClickButton:NSButton {
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey:Bool { false }
}
final class FirstClickHostingView<Content:View>:NSHostingView<Content> {
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
struct DisclosureControl:NSViewRepresentable {
    var expanded:Bool
    var action:() -> Void
    final class Coordinator:NSObject {
        var action:() -> Void
        init(_ action:@escaping () -> Void) { self.action = action }
        @objc func activate(_ sender:Any?) { action() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(action) }
    func makeNSView(context:Context) -> FirstClickButton {
        let button = FirstClickButton()
        button.isBordered = false; button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange); button.focusRingType = .none
        button.target = context.coordinator; button.action = #selector(Coordinator.activate(_:))
        button.imagePosition = .imageOnly
        button.setContentHuggingPriority(.defaultLow,for:.horizontal)
        return button
    }
    func updateNSView(_ button:FirstClickButton,context:Context) {
        context.coordinator.action = action
        button.image = NSImage(systemSymbolName:expanded ? "chevron.up" : "chevron.down",accessibilityDescription:nil)
        button.contentTintColor = .white
        button.setAccessibilityLabel(expanded ? "收起明细" : "展开明细")
        button.toolTip = expanded ? "收起明细" : "展开明细"
    }
}

struct ResizeHandle:NSViewRepresentable {
    final class Handle:NSView {
        var start = NSPoint.zero
        var size = NSSize.zero
        override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
        override var needsPanelToBecomeKey:Bool { false }
        override func mouseDown(with event:NSEvent) {
            start = window?.convertPoint(toScreen:event.locationInWindow) ?? .zero
            size = window?.frame.size ?? .zero
        }
        override func mouseDragged(with event:NSEvent) {
            guard let window, let delegate = NSApp.delegate as? AppDelegate else { return }
            let point = window.convertPoint(toScreen:event.locationInWindow)
            let dy = delegate.monitor.opensUp ? point.y-start.y : start.y-point.y
            delegate.userResize(width:size.width+point.x-start.x,height:size.height+dy)
        }
        override func resetCursorRects() { addCursorRect(bounds,cursor:.crosshair) }
        override func draw(_ dirtyRect:NSRect) {
            NSColor.white.withAlphaComponent(0.65).setStroke()
            let path = NSBezierPath(); path.lineWidth = 1.2
            path.move(to:NSPoint(x:5,y:2)); path.line(to:NSPoint(x:14,y:11))
            path.move(to:NSPoint(x:10,y:2)); path.line(to:NSPoint(x:14,y:6)); path.stroke()
        }
    }
    func makeNSView(context:Context) -> Handle {
        let view = Handle(); view.setAccessibilityLabel("拖动调整窗口大小"); return view
    }
    func updateNSView(_ view:Handle,context:Context) {}
}
