import SwiftUI
import SlideRuleKit

/// 計算尺本体・拡大表示・微調整ボタン・読み取り値をまとめた作業台
struct RuleWorkbench: View {
    @Binding var state: RuleState
    var highlights: Set<ScaleID> = []
    @Binding var showReadings: Bool
    /// false のときは設定にかかわらず拡大表示を出さない
    var allowsLoupe = true

    @AppStorage("showLoupe") private var showLoupe = true
    @AppStorage("loupeZoom") private var loupeZoom = 6.0
    /// 拡大表示の中でドラッグしている間は表示範囲を固定する（指の動きと目盛りの動きを一致させるため）
    @State private var frozenCenter: Double?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    /// 微調整 1 回分の移動量（正規化座標）。D 尺で約 0.1% の変化
    private let nudge = 0.0005

    /// iPhone の縦画面では行を低くして、説明文の場所を確保する
    private var layout: RuleLayout {
        isCompact ? RuleLayout(rowHeight: 18, gap: 3, padding: 3) : RuleLayout()
    }

    var body: some View {
        VStack(spacing: 6) {
            RuleView(state: state, highlights: highlights, layout: layout, target: $state)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if showLoupe && allowsLoupe {
                RuleView(
                    state: state,
                    center: frozenCenter ?? state.cursor,
                    zoom: loupeZoom,
                    highlights: highlights,
                    layout: layout,
                    target: $state,
                    onDragChanged: { dragging in
                        if dragging {
                            frozenCenter = frozenCenter ?? state.cursor
                        } else {
                            withAnimation(.easeOut(duration: 0.35)) { frozenCenter = nil }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    Text("×\(Int(loupeZoom))")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 5)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.trailing, 36)
                        .padding(.top, 1)
                }
            }

            controls

            if showReadings {
                ReadingsView(state: state)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: isCompact ? 8 : 14) {
            nudgeGroup("カーソル", keyPath: \.cursor, range: RuleState.cursorRange)
            nudgeGroup("滑尺", keyPath: \.slide, range: RuleState.slideRange)
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.5)) { state.slide = 0 }
            } label: {
                Label("基線をそろえる", systemImage: "arrow.left.and.right.square")
                    .labelStyle(AdaptiveLabelStyle(iconOnly: isCompact))
            }
            .help("滑尺を元の位置（C 尺と D 尺の基線が一致する位置）に戻します")

            Menu {
                Toggle("拡大表示", isOn: $showLoupe)
                Picker("倍率", selection: $loupeZoom) {
                    ForEach([3.0, 6.0, 10.0, 16.0], id: \.self) { z in
                        Text("×\(Int(z))").tag(z)
                    }
                }
                Toggle("読み取り値", isOn: $showReadings)
            } label: {
                Label("表示", systemImage: "eye")
                    .labelStyle(AdaptiveLabelStyle(iconOnly: isCompact))
            }
            .fixedSize()
        }
        .font(isCompact ? .footnote : .callout)
    }

    private func nudgeGroup(_ title: String, keyPath: WritableKeyPath<RuleState, Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 3) {
            Text(title).foregroundStyle(.secondary)
            Button {
                state[keyPath: keyPath] = max(range.lowerBound, state[keyPath: keyPath] - nudge)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 18, minHeight: 20)
            }
            .accessibilityLabel("\(title)を左へ")
            Button {
                state[keyPath: keyPath] = min(range.upperBound, state[keyPath: keyPath] + nudge)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 18, minHeight: 20)
            }
            .accessibilityLabel("\(title)を右へ")
        }
        .buttonStyle(.bordered)
        .buttonRepeatBehavior(.enabled)
        .controlSize(isCompact ? .small : .regular)
    }
}

/// 狭い画面ではアイコンだけを表示するラベル
struct AdaptiveLabelStyle: LabelStyle {
    var iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title
            }
        }
    }
}

/// カーソル線の下にある各尺の値
struct ReadingsView: View {
    var state: RuleState

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(RuleLayout.rows) { id in
                HStack(spacing: 4) {
                    Text(id.name)
                        .font(.caption.bold())
                        .foregroundStyle(id.isInverted ? Color.red : Color.primary)
                        .frame(width: 20, alignment: .leading)
                    Text(text(for: id))
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func text(for id: ScaleID) -> String {
        guard let v = state.reading(id) else { return "範囲外" }
        if id.isAngle { return String(format: "%.2f°", v) }
        if id == .L { return String(format: "%.4f", v) }
        return fmt(v, 4)
    }
}
