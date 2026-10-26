import SwiftUI
import SlideRuleKit

/// 計算尺の色。実物に合わせ、ダークモードでも明るい地色のままにする
enum RuleColors {
    static let stator = Color(red: 0.97, green: 0.95, blue: 0.89)
    static let slide = Color(red: 1.0, green: 0.995, blue: 0.97)
    static let edge = Color(red: 0.55, green: 0.5, blue: 0.42)
    static let tick = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let inverted = Color(red: 0.78, green: 0.1, blue: 0.1)
    static let highlight = Color(red: 1.0, green: 0.86, blue: 0.35).opacity(0.45)
    static let hairline = Color.red
    static let glass = Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.18)
}

/// 尺の並びと、各行の上下位置
struct RuleLayout {
    /// 上から：上固定尺（K, A）、滑尺（B, CI, C）、下固定尺（D, L, S, T）
    static let rows: [ScaleID] = [.K, .A, .B, .CI, .C, .D, .L, .S, .T]

    var rowHeight: CGFloat = 22
    var gap: CGFloat = 4
    var padding: CGFloat = 4

    var totalHeight: CGFloat {
        padding * 2 + rowHeight * CGFloat(Self.rows.count) + gap * 2
    }

    func rowTop(_ id: ScaleID) -> CGFloat {
        let i = Self.rows.firstIndex(of: id)!
        var y = padding + CGFloat(i) * rowHeight
        if i >= 2 { y += gap }
        if i >= 5 { y += gap }
        return y
    }

    /// 滑尺部分の上端と下端
    var slideBand: ClosedRange<CGFloat> {
        rowTop(.B)...(rowTop(.C) + rowHeight)
    }

    /// 目盛り線を行の下端から上へ伸ばすか（滑尺との境目に目盛りを寄せる）
    static func anchoredAtBottom(_ id: ScaleID) -> Bool {
        id == .K || id == .A || id == .C
    }
}

/// 目盛りの生成結果を画面幅ごとに覚えておく
@MainActor
final class TickCache {
    static let shared = TickCache()
    private var store: [String: [Tick]] = [:]

    func ticks(_ scale: ScaleID, pixelLength: Double) -> [Tick] {
        // 幅を 16pt 単位に丸めてキャッシュする
        let bucket = max(16, (pixelLength / 16).rounded() * 16)
        let key = "\(scale.rawValue)-\(Int(bucket))"
        if let hit = store[key] { return hit }
        if store.count > 300 { store.removeAll() }
        let t = scale.ticks(pixelLength: bucket)
        store[key] = t
        return t
    }
}

/// 計算尺本体の描画と操作
///
/// center が nil のときは全体を表示し、値があるときはその位置を中心に zoom 倍で拡大表示する。
struct RuleView: View, @MainActor Animatable {
    /// 描画に使う状態（アニメーション中は補間された値になる）
    var state: RuleState
    var center: Double?
    var zoom: Double = 1
    var highlights: Set<ScaleID> = []
    var layout = RuleLayout()
    /// 実際の状態。ドラッグで書き換える
    @Binding var target: RuleState
    var onDragChanged: (Bool) -> Void = { _ in }

    static let margin = 0.07

    @State private var dragKind: DragKind?
    @State private var dragStart = RuleState()

    private enum DragKind { case slide, cursor }

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(state.slide, state.cursor), center ?? 0) }
        set {
            state.slide = newValue.first.first
            state.cursor = newValue.first.second
            if center != nil { center = newValue.second }
        }
    }

    /// 画面に映す範囲（正規化座標）
    var visibleRange: ClosedRange<Double> {
        let full = (-Self.margin)...(1 + Self.margin)
        guard let center else { return full }
        let width = (full.upperBound - full.lowerBound) / zoom
        let lo = min(max(center - width / 2, full.lowerBound), full.upperBound - width)
        return lo...(lo + width)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let visible = visibleRange
            let unit = width / (visible.upperBound - visible.lowerBound)
            let tickTable = Dictionary(uniqueKeysWithValues: RuleLayout.rows.map { ($0, TickCache.shared.ticks($0, pixelLength: unit)) })
            Canvas { context, size in
                draw(in: &context, size: size, visible: visible, unit: unit, tickTable: tickTable)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(unit: unit))
        }
        .frame(height: layout.totalHeight)
        .accessibilityElement()
        .accessibilityLabel("計算尺")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let d = state.reading(.D).map { fmt($0, 3) } ?? "範囲外"
        let c = state.reading(.C).map { fmt($0, 3) } ?? "範囲外"
        return "カーソル下 D 尺 \(d)、C 尺 \(c)"
    }

    private func dragGesture(unit: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if dragKind == nil {
                    // ドラッグ開始位置で、滑尺を動かすかカーソルを動かすかを決め、ドラッグ中は変えない
                    dragKind = layout.slideBand.contains(g.startLocation.y) ? .slide : .cursor
                    dragStart = target
                    onDragChanged(true)
                }
                let delta = g.translation.width / unit
                var next = dragStart
                switch dragKind {
                case .slide:
                    next.slide = min(max(dragStart.slide + delta, RuleState.slideRange.lowerBound), RuleState.slideRange.upperBound)
                case .cursor, nil:
                    next.cursor = min(max(dragStart.cursor + delta, RuleState.cursorRange.lowerBound), RuleState.cursorRange.upperBound)
                }
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { target = next }
            }
            .onEnded { _ in
                dragKind = nil
                onDragChanged(false)
            }
    }

    // MARK: - 描画

    private func draw(in context: inout GraphicsContext, size: CGSize, visible: ClosedRange<Double>, unit: Double, tickTable: [ScaleID: [Tick]]) {
        let px: (Double) -> CGFloat = { u in CGFloat((u - visible.lowerBound) * unit) }
        let rowH = layout.rowHeight

        // 固定尺
        let upper = CGRect(x: 0, y: layout.rowTop(.K), width: size.width, height: rowH * 2)
        let lower = CGRect(x: 0, y: layout.rowTop(.D), width: size.width, height: rowH * 4)
        context.fill(Path(upper), with: .color(RuleColors.stator))
        context.fill(Path(lower), with: .color(RuleColors.stator))
        context.stroke(Path(upper), with: .color(RuleColors.edge), lineWidth: 0.5)
        context.stroke(Path(lower), with: .color(RuleColors.edge), lineWidth: 0.5)

        // 滑尺
        let band = layout.slideBand
        let slideRect = CGRect(
            x: px(state.slide - Self.margin), y: band.lowerBound,
            width: px(state.slide + 1 + Self.margin) - px(state.slide - Self.margin), height: band.upperBound - band.lowerBound
        )
        context.fill(Path(slideRect), with: .color(RuleColors.slide))
        context.stroke(Path(slideRect), with: .color(RuleColors.edge), lineWidth: 0.8)

        // 注目する尺
        for id in highlights {
            let y = layout.rowTop(id)
            let rect: CGRect
            if id.isOnSlide {
                rect = CGRect(x: slideRect.minX, y: y, width: slideRect.width, height: rowH)
            } else {
                rect = CGRect(x: 0, y: y, width: size.width, height: rowH)
            }
            context.fill(Path(rect), with: .color(RuleColors.highlight))
        }

        // 目盛り
        let heights: [CGFloat] = [0.42, 0.32, 0.25, 0.18, 0.12].map { $0 * rowH }
        for id in RuleLayout.rows {
            let offset = id.isOnSlide ? state.slide : 0
            let top = layout.rowTop(id)
            let bottomAnchored = RuleLayout.anchoredAtBottom(id)
            let color = id.isInverted ? RuleColors.inverted : RuleColors.tick
            var lastLabelEdge: CGFloat = -.infinity
            var lines = Path()
            // 数字の重なり判定を左から順に行うため、逆目盛り（CI）は並びを反転する
            let ordered = id.isInverted ? Array((tickTable[id] ?? []).reversed()) : (tickTable[id] ?? [])
            for tick in ordered {
                let u = tick.position + offset
                guard u >= visible.lowerBound - 0.01, u <= visible.upperBound + 0.01 else { continue }
                let x = px(u)
                let h = heights[min(tick.level, heights.count - 1)]
                let y0 = bottomAnchored ? top + rowH : top
                let y1 = bottomAnchored ? y0 - h : y0 + h
                lines.move(to: CGPoint(x: x, y: y0))
                lines.addLine(to: CGPoint(x: x, y: y1))

                guard let label = tick.label else { continue }
                let isMajor = tick.level == 0
                let text = context.resolve(
                    Text(label)
                        .font(.system(size: rowH * (isMajor ? 0.42 : 0.35), weight: isMajor ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(color)
                )
                let textSize = text.measure(in: CGSize(width: 100, height: 20))
                // 数字が重なる場合は後ろの方を省く
                guard x - textSize.width / 2 > lastLabelEdge + 1.5 else { continue }
                lastLabelEdge = x + textSize.width / 2
                let labelY = bottomAnchored ? y1 - 1 : y1 + 1
                context.draw(text, at: CGPoint(x: x, y: labelY), anchor: bottomAnchored ? .bottom : .top)
            }
            context.stroke(lines, with: .color(color), lineWidth: 0.7)
        }

        // 尺の名前（左端）と表す量（右端）
        for id in RuleLayout.rows {
            let midY = layout.rowTop(id) + rowH / 2
            let color = id.isInverted ? RuleColors.inverted : RuleColors.tick
            drawTag(Text(id.name).font(.system(size: 10, weight: .bold)), color: color, at: CGPoint(x: 3, y: midY), anchor: .leading, in: &context)
            drawTag(Text(id.formula).font(.system(size: 8.5)), color: color, at: CGPoint(x: size.width - 3, y: midY), anchor: .trailing, in: &context)
        }

        // カーソル
        let cx = px(state.cursor)
        let glass = CGRect(x: cx - 14, y: 0, width: 28, height: size.height)
        context.fill(Path(roundedRect: glass, cornerRadius: 3), with: .color(RuleColors.glass))
        context.stroke(Path(roundedRect: glass, cornerRadius: 3), with: .color(RuleColors.edge.opacity(0.5)), lineWidth: 0.5)
        var hair = Path()
        hair.move(to: CGPoint(x: cx, y: 0))
        hair.addLine(to: CGPoint(x: cx, y: size.height))
        context.stroke(hair, with: .color(RuleColors.hairline), lineWidth: 1)
    }

    private func drawTag(_ text: Text, color: Color, at point: CGPoint, anchor: UnitPoint, in context: inout GraphicsContext) {
        let resolved = context.resolve(text.foregroundStyle(color))
        let s = resolved.measure(in: CGSize(width: 60, height: 20))
        let x = anchor == .leading ? point.x : point.x - s.width - 4
        let rect = CGRect(x: x, y: point.y - s.height / 2 - 1, width: s.width + 4, height: s.height + 2)
        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white.opacity(0.85)))
        context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }
}
