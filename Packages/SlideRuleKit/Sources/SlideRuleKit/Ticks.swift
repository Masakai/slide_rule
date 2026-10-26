import Foundation

/// 1 本の目盛り線
public struct Tick: Sendable, Equatable {
    /// 目盛りが表す値
    public let value: Double
    /// 正規化位置（0〜1）
    public let position: Double
    /// 目盛りの階層。0 が主目盛り（最も長い線）
    public let level: Int
    /// 数字を添える場合の文字列
    public let label: String?
}

/// 目盛りを刻む区間と、その区間で使う刻み幅の候補（粗い順）
struct TickSegment: Sendable {
    let lower: Double
    let upper: Double
    /// steps[0] が主目盛りの間隔。後ろほど細かい。各要素は直前の要素を割り切る
    let steps: [Double]
}

extension ScaleID {
    /// 対数尺 1 桁分（1〜10）の刻み方。実物の計算尺と同様に、左ほど細かく刻む
    private static func logDecade(_ scale: Double) -> [TickSegment] {
        [
            TickSegment(lower: 1 * scale, upper: 2 * scale, steps: [1, 0.5, 0.1, 0.05, 0.01].map { $0 * scale }),
            TickSegment(lower: 2 * scale, upper: 4 * scale, steps: [1, 0.5, 0.1, 0.02].map { $0 * scale }),
            TickSegment(lower: 4 * scale, upper: 10 * scale, steps: [1, 0.5, 0.1, 0.05].map { $0 * scale }),
        ]
    }

    var tickSegments: [TickSegment] {
        switch self {
        case .C, .D, .CI:
            return Self.logDecade(1)
        case .A, .B:
            return Self.logDecade(1) + Self.logDecade(10)
        case .K:
            return Self.logDecade(1) + Self.logDecade(10) + Self.logDecade(100)
        case .L:
            return [TickSegment(lower: 0, upper: 1, steps: [0.1, 0.05, 0.01, 0.005, 0.001])]
        case .S:
            return [
                TickSegment(lower: 5, upper: 10, steps: [1, 0.5, 0.1]),
                TickSegment(lower: 10, upper: 30, steps: [5, 1, 0.5, 0.1]),
                TickSegment(lower: 30, upper: 60, steps: [10, 5, 1, 0.5]),
                TickSegment(lower: 60, upper: 90, steps: [10, 5, 1]),
            ]
        case .T:
            return [
                TickSegment(lower: 5, upper: 10, steps: [1, 0.5, 0.1]),
                TickSegment(lower: 10, upper: 45, steps: [5, 1, 0.5, 0.1]),
            ]
        }
    }

    /// 画面上の長さに応じて、線が詰まりすぎない細かさで目盛りを生成する。
    ///
    /// - Parameters:
    ///   - pixelLength: 尺の全長（0〜1）が画面上で占める長さ（pt）
    ///   - minTickSpacing: 隣り合う目盛り線の最小間隔（pt）
    ///   - minLabelSpacing: 数字を添える目盛りの最小間隔（pt）
    public func ticks(pixelLength: Double, minTickSpacing: Double = 3.5, minLabelSpacing: Double = 16) -> [Tick] {
        let tickThreshold = minTickSpacing / pixelLength
        let labelThreshold = minLabelSpacing / pixelLength
        let eps = 1e-9
        var result: [Tick] = []

        for segment in tickSegments {
            let major = segment.steps[0]
            var start = (segment.lower / major + eps).rounded(.down) * major
            while start < segment.upper - eps {
                let end = min(start + major, segment.upper)
                let lo = max(start, segment.lower, domain.lowerBound)
                let hi = min(end, domain.upperBound)
                defer { start += major }
                guard hi > lo + eps else { continue }

                let tickDepth = deepestLevel(steps: segment.steps, lo: lo, hi: hi, threshold: tickThreshold)
                let labelDepth = min(
                    deepestLevel(steps: segment.steps, lo: lo, hi: hi, threshold: labelThreshold),
                    tickDepth
                )
                let fine = segment.steps[tickDepth]
                let count = Int(((end - start) / fine).rounded())
                for i in 0...count {
                    let v = start + Double(i) * fine
                    guard v >= domain.lowerBound - eps, v <= domain.upperBound + eps else { continue }
                    let level = levelOf(v, steps: segment.steps)
                    let label: String?
                    if level == 0 {
                        label = Self.format(v)
                    } else if level <= labelDepth, Self.isLabelable(step: segment.steps[level], major: major) {
                        label = Self.lastDigit(v, step: segment.steps[level])
                    } else {
                        label = nil
                    }
                    result.append(Tick(value: v, position: position(of: v), level: level, label: label))
                }
            }
        }
        return Self.dedupe(result)
    }

    /// 補助目盛りに数字を添えてよいか。
    /// 主目盛りの半分か、主目盛りの 1/10 以上の 10 の累乗の刻みに限る。
    /// 1.05 や 10.5 に「5」が付くと、隣の数字と混同しやすいため
    static func isLabelable(step: Double, major: Double) -> Bool {
        if abs(step - major / 2) < 1e-9 { return true }
        guard step >= major / 10 - 1e-9 else { return false }
        let e = log10(step)
        return abs(e - e.rounded()) < 1e-9
    }

    /// 区間 [lo, hi] で、目盛り間隔が threshold 以上になる最も細かい階層
    private func deepestLevel(steps: [Double], lo: Double, hi: Double, threshold: Double) -> Int {
        var depth = 0
        for (i, step) in steps.enumerated().dropFirst() {
            if minSpacing(step: step, lo: lo, hi: hi) >= threshold {
                depth = i
            } else {
                break
            }
        }
        return depth
    }

    /// 単調な写像なので、間隔の最小値は区間の両端のどちらかで生じる
    private func minSpacing(step: Double, lo: Double, hi: Double) -> Double {
        if step >= hi - lo {
            return abs(position(of: hi) - position(of: lo))
        }
        let left = abs(position(of: lo + step) - position(of: lo))
        let right = abs(position(of: hi) - position(of: hi - step))
        return min(left, right)
    }

    private func levelOf(_ v: Double, steps: [Double]) -> Int {
        for (i, step) in steps.enumerated() {
            let q = v / step
            if abs(q - q.rounded()) < 1e-6 {
                return i
            }
        }
        return steps.count - 1
    }

    /// 境界で重なった目盛りを 1 本にまとめる（階層の小さい方を残す）
    private static func dedupe(_ ticks: [Tick]) -> [Tick] {
        let sorted = ticks.sorted { $0.value < $1.value }
        var out: [Tick] = []
        for t in sorted {
            if let last = out.last, abs(last.value - t.value) < 1e-7 {
                if t.level < last.level || (t.level == last.level && last.label == nil && t.label != nil) {
                    out[out.count - 1] = t
                }
            } else {
                out.append(t)
            }
        }
        return out
    }

    /// 主目盛りの数字。整数は小数点なし、それ以外は末尾の 0 を省く
    static func format(_ v: Double) -> String {
        if abs(v - v.rounded()) < 1e-9 {
            return String(Int(v.rounded()))
        }
        var s = String(format: "%.3f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// 補助目盛りの数字。実物の計算尺と同じく末尾 1 桁だけを添える（1.5 → "5"）
    static func lastDigit(_ v: Double, step: Double) -> String {
        let unit = pow(10, floor(log10(step)))
        let n = Int((v / unit).rounded())
        return String(n % 10)
    }
}
