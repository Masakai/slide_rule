import SwiftUI
import SlideRuleKit

/// 計算尺の原理の解説
struct PrincipleScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("計算尺とは") {
                        Text("計算尺は、目盛りを刻んだ 2 本の物差しをずらして掛け算・割り算などを行う道具です。17 世紀にイギリスで考案され、電卓が普及する 1970 年代まで、技術者や学生が日常的に使っていました。答えは有効数字 3 桁程度で得られます。")
                    }

                    section("掛け算を足し算に変える") {
                        Text("対数には log(a × b) = log a + log b という性質があります。数 x を、左端から log₁₀ x の長さの位置に刻んだ物差しを用意すると、2 本の物差しで長さを足すだけで掛け算ができます。")
                        LengthAdditionDemo()
                        Text("上の図で a と b を変えると、下の物差しの log a の位置から上の物差しを並べ、log b の長さだけ進んだ位置に a × b が現れます。普通の物差し（等間隔）で同じことをすると足し算になります。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    section("目盛りの間隔が均等でない理由") {
                        Text("log₁₀ 1 = 0、log₁₀ 2 ≈ 0.301、log₁₀ 3 ≈ 0.477 … log₁₀ 10 = 1 なので、1 と 2 の間は全長の約 30%、9 と 10 の間は約 4.6% しかありません。左ほど間隔が広いのはこのためです。")
                        LogRulerDiagram()
                    }

                    section("尺の一覧") {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                            GridRow {
                                Text("尺").bold()
                                Text("位置 x に刻む値").bold()
                                Text("主な用途").bold()
                            }
                            Divider().gridCellUnsizedAxes(.horizontal)
                            row("C・D", "10^x（1〜10）", "掛け算・割り算")
                            row("CI", "10^(1−x)", "逆数")
                            row("A・B", "10^(2x)（1〜100）", "2 乗・平方根")
                            row("K", "10^(3x)（1〜1000）", "3 乗・立方根")
                            row("L", "x（0〜1）", "常用対数")
                            row("S", "sin θ = 10^x ÷ 10", "sin（5.74°〜90°）")
                            row("T", "tan θ = 10^x ÷ 10", "tan（5.71°〜45°）")
                        }
                        .font(.callout)
                        Text("このアプリでは S 尺・T 尺を D 尺に対して読みます。機種によっては滑尺の裏側にあり、C 尺に対して読むものもあります。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    section("精度と有効数字") {
                        Text("標準的な長さ 25 cm の計算尺では、有効数字 3 桁程度まで読み取れます（目盛りの広い 1〜2 の区間では 4 桁目の見当もつきます）。D 尺の 1 目盛りが表す値は場所によって違いますが、値に対する比率（相対誤差）はほぼ一定になります。")
                    }

                    section("位取り（小数点の位置）") {
                        Text("計算尺が示すのは数字の並びだけです。小数点の位置は自分で決めます。")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("例：0.032 × 450")
                                .bold()
                            Text("1. 仮数と 10 の累乗に分ける：3.2 × 10⁻² と 4.5 × 10²")
                            Text("2. 計算尺で 3.2 × 4.5 を求める：右基線を使い、D 尺に 1.44 が読める")
                            Text("3. 仮数どうしの積は 14.4（右基線を使ったので読みの 10 倍）")
                            Text("4. 10⁻² × 10² = 10⁰ を掛けて、答えは 14.4")
                            Text("5. 概算 0.03 × 500 = 15 と比べて、大きさが合っていることを確かめる")
                        }
                        .font(.callout)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("原理")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ a: String, _ b: String, _ c: String) -> some View {
        GridRow {
            Text(a).bold()
            Text(b)
            Text(c)
        }
    }
}

/// 2 本の対数目盛りで長さを足して積を求める図
struct LengthAdditionDemo: View {
    @State private var a = 2.0
    @State private var b = 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                let left: CGFloat = 12
                let length = size.width - 24
                let la = log10(a)
                let lb = log10(b)
                // 積が 10 を超えたら、上の物差しを 1 本分左にずらして読む（右基線）
                let shift = la + lb > 1 ? la - 1 : la
                drawRuler(&context, y: 52, x0: left, length: length, offset: 0, color: .primary)
                drawRuler(&context, y: 20, x0: left, length: length, offset: shift, color: .blue)

                let xa = left + CGFloat(la) * length
                let xp = left + CGFloat(shift + lb) * length
                var arrowA = Path()
                arrowA.move(to: CGPoint(x: left, y: 76))
                arrowA.addLine(to: CGPoint(x: xa, y: 76))
                context.stroke(arrowA, with: .color(.orange), lineWidth: 3)
                var arrowB = Path()
                arrowB.move(to: CGPoint(x: left + CGFloat(shift) * length, y: 6))
                arrowB.addLine(to: CGPoint(x: xp, y: 6))
                context.stroke(arrowB, with: .color(.green), lineWidth: 3)

                var hair = Path()
                hair.move(to: CGPoint(x: xp, y: 0))
                hair.addLine(to: CGPoint(x: xp, y: 84))
                context.stroke(hair, with: .color(.red), lineWidth: 1.2)
            }
            .frame(height: 86)
            .clipped()

            Grid(alignment: .leading, verticalSpacing: 4) {
                GridRow {
                    Text("a = \(fmt(a, 2))").monospacedDigit().foregroundStyle(.orange)
                    Slider(value: $a, in: 1...9.9, step: 0.1)
                }
                GridRow {
                    Text("b = \(fmt(b, 2))").monospacedDigit().foregroundStyle(.green)
                    Slider(value: $b, in: 1...9.9, step: 0.1)
                }
            }
            Text("a × b = \(fmt(a * b, 3))　（log a + log b = \(String(format: "%.3f", log10(a) + log10(b)))）")
                .font(.callout.monospacedDigit())
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func drawRuler(_ context: inout GraphicsContext, y: CGFloat, x0: CGFloat, length: CGFloat, offset: Double, color: Color) {
        var line = Path()
        let start = x0 + CGFloat(offset) * length
        line.move(to: CGPoint(x: start, y: y))
        line.addLine(to: CGPoint(x: start + length, y: y))
        context.stroke(line, with: .color(color.opacity(0.6)), lineWidth: 1)
        for n in 1...10 {
            let x = start + CGFloat(log10(Double(n))) * length
            var t = Path()
            t.move(to: CGPoint(x: x, y: y - 6))
            t.addLine(to: CGPoint(x: x, y: y + 6))
            context.stroke(t, with: .color(color), lineWidth: 1)
            context.draw(Text("\(n)").font(.system(size: 9)).foregroundStyle(color), at: CGPoint(x: x, y: y + 13))
        }
    }
}

/// 数直線上の log の位置と、刻まれる数の対応図
struct LogRulerDiagram: View {
    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 14
            let length = size.width - 28
            var axis = Path()
            axis.move(to: CGPoint(x: left, y: 30))
            axis.addLine(to: CGPoint(x: left + length, y: 30))
            context.stroke(axis, with: .color(.primary), lineWidth: 1)
            // 上：等間隔の log 値、下：対応する数
            for i in 0...10 {
                let x = left + CGFloat(i) / 10 * length
                var t = Path()
                t.move(to: CGPoint(x: x, y: 24))
                t.addLine(to: CGPoint(x: x, y: 30))
                context.stroke(t, with: .color(.secondary), lineWidth: 0.8)
                if i.isMultiple(of: 2) {
                    context.draw(Text(String(format: "%.1f", Double(i) / 10)).font(.system(size: 9)).foregroundStyle(.secondary), at: CGPoint(x: x, y: 14))
                }
            }
            for n in 1...10 {
                let x = left + CGFloat(log10(Double(n))) * length
                var t = Path()
                t.move(to: CGPoint(x: x, y: 30))
                t.addLine(to: CGPoint(x: x, y: 40))
                context.stroke(t, with: .color(.blue), lineWidth: 1.2)
                context.draw(Text("\(n)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.blue), at: CGPoint(x: x, y: 50))
            }
        }
        .frame(height: 60)
        .overlay(alignment: .bottomTrailing) {
            Text("上：log₁₀ x　下：x")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: 14)
        }
        .padding(.bottom, 14)
    }
}
