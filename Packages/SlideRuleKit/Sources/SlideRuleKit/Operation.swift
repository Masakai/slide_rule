import Foundation

/// 正の数を「仮数 × 10 の指数」（1 ≤ 仮数 < 10）に分けたもの
public struct Scientific: Sendable, Equatable {
    public let mantissa: Double
    public let exponent: Int

    public init(_ value: Double) {
        precondition(value > 0, "正の数のみ扱う")
        var e = Int(floor(log10(value)))
        var m = value / pow(10, Double(e))
        // 浮動小数点の誤差で 9.9999… や 10.0000… になった場合の補正
        if m >= 10 - 1e-12 {
            m /= 10
            e += 1
        } else if m < 1 {
            m *= 10
            e -= 1
        }
        mantissa = m
        exponent = e
    }
}

/// 計算尺の操作手順の 1 段階
public struct Step: Sendable, Identifiable, Equatable {
    public let id: Int
    public let text: String
    /// この段階で計算尺がとる状態
    public let state: RuleState
    /// 注目すべき尺
    public let highlights: [ScaleID]
}

/// 計算尺で行う計算の種類と入力
public enum Operation: Sendable, Equatable, Hashable {
    case multiply(Double, Double)
    case divide(Double, Double)
    case reciprocal(Double)
    case square(Double)
    case squareRoot(Double)
    case cube(Double)
    case cubeRoot(Double)
    case log10(Double)
    /// 角度は度
    case sine(Double)
    case tangent(Double)

    /// 厳密な答え
    public var answer: Double {
        switch self {
        case let .multiply(a, b): return a * b
        case let .divide(a, b): return a / b
        case let .reciprocal(a): return 1 / a
        case let .square(a): return a * a
        case let .squareRoot(a): return a.squareRoot()
        case let .cube(a): return a * a * a
        case let .cubeRoot(a): return Foundation.cbrt(a)
        case let .log10(a): return Foundation.log10(a)
        case let .sine(d): return Foundation.sin(d * .pi / 180)
        case let .tangent(d): return Foundation.tan(d * .pi / 180)
        }
    }

    /// 問題文
    public var question: String {
        switch self {
        case let .multiply(a, b): return "\(fmt(a)) × \(fmt(b))"
        case let .divide(a, b): return "\(fmt(a)) ÷ \(fmt(b))"
        case let .reciprocal(a): return "1 ÷ \(fmt(a))"
        case let .square(a): return "\(fmt(a))²"
        case let .squareRoot(a): return "√\(fmt(a))"
        case let .cube(a): return "\(fmt(a))³"
        case let .cubeRoot(a): return "∛\(fmt(a))"
        case let .log10(a): return "log₁₀ \(fmt(a))"
        case let .sine(d): return "sin \(fmt(d))°"
        case let .tangent(d): return "tan \(fmt(d))°"
        }
    }

    /// 計算尺での操作手順
    public var steps: [Step] {
        var builder = StepBuilder()
        switch self {
        case let .multiply(a, b):
            buildMultiply(a, b, &builder)
        case let .divide(a, b):
            buildDivide(a, b, &builder)
        case let .reciprocal(a):
            let s = Scientific(a)
            let x = Foundation.log10(s.mantissa)
            builder.add("カーソル線を C 尺の \(fmt(s.mantissa)) に合わせます（滑尺は基線をそろえた位置）。", RuleState(slide: 0, cursor: x), [.C])
            builder.add("同じカーソル線の下の CI 尺を読むと \(fmt(10 / s.mantissa, 4)) です。CI 尺は C 尺を左右逆にした尺で、1/x を表します。", RuleState(slide: 0, cursor: x), [.CI])
            builder.add(placeText(), RuleState(slide: 0, cursor: x), [.CI])
        case let .square(a):
            let s = Scientific(a)
            let x = Foundation.log10(s.mantissa)
            builder.add("カーソル線を D 尺の \(fmt(s.mantissa)) に合わせます。", RuleState(slide: 0, cursor: x), [.D])
            builder.add("カーソル線の下の A 尺を読むと \(fmt(s.mantissa * s.mantissa, 3)) です。A 尺は 1〜10 の目盛りを半分の長さで 2 回並べて 1〜100 を表すので、D 尺の値の 2 乗が読めます。", RuleState(slide: 0, cursor: x), [.A])
            builder.add(placeText(), RuleState(slide: 0, cursor: x), [.A])
        case let .squareRoot(a):
            buildSquareRoot(a, &builder)
        case let .cube(a):
            let s = Scientific(a)
            let x = Foundation.log10(s.mantissa)
            builder.add("カーソル線を D 尺の \(fmt(s.mantissa)) に合わせます。", RuleState(slide: 0, cursor: x), [.D])
            builder.add("カーソル線の下の K 尺を読むと \(fmt(Foundation.pow(s.mantissa, 3), 3)) です。K 尺は 1〜10 の目盛りを 1/3 の長さで 3 回並べて 1〜1000 を表すので、D 尺の値の 3 乗が読めます。", RuleState(slide: 0, cursor: x), [.K])
            builder.add(placeText(), RuleState(slide: 0, cursor: x), [.K])
        case let .cubeRoot(a):
            buildCubeRoot(a, &builder)
        case let .log10(a):
            let s = Scientific(a)
            let x = Foundation.log10(s.mantissa)
            builder.add("カーソル線を D 尺の \(fmt(s.mantissa)) に合わせます。", RuleState(slide: 0, cursor: x), [.D])
            builder.add("カーソル線の下の L 尺を読むと \(fmt(x, 3, fixed: true)) です。これが log₁₀ の小数部分（仮数）です。", RuleState(slide: 0, cursor: x), [.L])
            builder.add("\(fmt(a)) = \(fmt(s.mantissa)) × \(pow10(s.exponent)) なので、整数部分（指標）は \(s.exponent) です。答えは \(s.exponent) + \(fmt(x, 3, fixed: true)) = \(fmt(answer, 3, fixed: true)) です。", RuleState(slide: 0, cursor: x), [.L, .D])
        case let .sine(d):
            let x = ScaleID.S.position(of: d)
            builder.add("カーソル線を S 尺の \(fmt(d))° に合わせます。", RuleState(slide: 0, cursor: x), [.S])
            builder.add("カーソル線の下の D 尺を読むと \(fmt(Foundation.pow(10, x), 3)) です。このアプリの S 尺は D 尺に対して読み、5.74°〜90° が sin 0.1〜1 に対応します。", RuleState(slide: 0, cursor: x), [.D])
            builder.add("D 尺の値を 10 で割って、sin \(fmt(d))° ≈ \(fmt(answer, 3)) です。", RuleState(slide: 0, cursor: x), [.S, .D])
        case let .tangent(d):
            let x = ScaleID.T.position(of: d)
            builder.add("カーソル線を T 尺の \(fmt(d))° に合わせます。", RuleState(slide: 0, cursor: x), [.T])
            builder.add("カーソル線の下の D 尺を読むと \(fmt(Foundation.pow(10, x), 3)) です。T 尺は 5.71°〜45° が tan 0.1〜1 に対応します。", RuleState(slide: 0, cursor: x), [.D])
            builder.add("D 尺の値を 10 で割って、tan \(fmt(d))° ≈ \(fmt(answer, 3)) です。", RuleState(slide: 0, cursor: x), [.T, .D])
        }
        return builder.steps
    }

    /// 最後の「位取り」の説明文（逆数・2 乗・3 乗）
    func placeText() -> String {
        switch self {
        case let .reciprocal(a):
            let s = Scientific(a)
            let head = s.exponent == 0 ? "" : "\(fmt(a)) = \(fmt(s.mantissa)) × \(pow10(s.exponent)) です。"
            return head + "1/\(fmt(s.mantissa)) は CI 尺の読みの 1/10 なので、" + placeSentence("CI", 10 / s.mantissa, -s.exponent - 1)
        case let .square(a):
            let s = Scientific(a)
            let head = s.exponent == 0 ? "" : "\(fmt(a)) = \(fmt(s.mantissa)) × \(pow10(s.exponent)) なので、2 乗の位は \(pow10(2 * s.exponent)) です。"
            return head + placeSentence("A", s.mantissa * s.mantissa, 2 * s.exponent)
        case let .cube(a):
            let s = Scientific(a)
            let head = s.exponent == 0 ? "" : "\(fmt(a)) = \(fmt(s.mantissa)) × \(pow10(s.exponent)) なので、3 乗の位は \(pow10(3 * s.exponent)) です。"
            return head + placeSentence("K", Foundation.pow(s.mantissa, 3), 3 * s.exponent)
        default:
            return "答えは \(fmt(answer, 3)) です。"
        }
    }

    /// 「〇尺の読み r に 10^e を掛けて、答えは…」
    func placeSentence(_ scale: String, _ reading: Double, _ exponent: Int) -> String {
        if exponent == 0 {
            return "\(scale) 尺の読み \(fmt(reading, 3)) がそのまま答えです。"
        }
        return "\(scale) 尺の読み \(fmt(reading, 3)) に \(pow10(exponent)) を掛けて、答えは \(fmt(answer, 3)) です。"
    }

    private func buildMultiply(_ a: Double, _ b: Double, _ builder: inout StepBuilder) {
        let sa = Scientific(a)
        let sb = Scientific(b)
        let la = Foundation.log10(sa.mantissa)
        let lb = Foundation.log10(sb.mantissa)
        builder.add("カーソル線を D 尺の \(fmt(sa.mantissa)) に合わせます。", RuleState(slide: 0, cursor: la), [.D])
        let useRight = la + lb > 1 + 1e-12
        let slide = useRight ? la - 1 : la
        if useRight {
            builder.add("左基線を合わせると C 尺の \(fmt(sb.mantissa)) が右にはみ出します（\(fmt(sa.mantissa)) × \(fmt(sb.mantissa)) が 10 を超えるため）。そこで C 尺の右端の 10（右基線）をカーソル線に合わせます。", RuleState(slide: slide, cursor: la), [.C, .D])
        } else {
            builder.add("滑尺を動かし、C 尺の左端の 1（左基線）をカーソル線に合わせます。", RuleState(slide: slide, cursor: la), [.C, .D])
        }
        let cursor = slide + lb
        let digits = useRight ? sa.mantissa * sb.mantissa / 10 : sa.mantissa * sb.mantissa
        builder.add("カーソル線を C 尺の \(fmt(sb.mantissa)) まで動かします。", RuleState(slide: slide, cursor: cursor), [.C])
        builder.add("カーソル線の下の D 尺を読むと \(fmt(digits, 3)) です。長さの和 log \(fmt(sa.mantissa)) + log \(fmt(sb.mantissa)) が積の位置になります。", RuleState(slide: slide, cursor: cursor), [.D])
        let exponent = sa.exponent + sb.exponent + (useRight ? 1 : 0)
        var place = ""
        if sa.exponent != 0 || sb.exponent != 0 {
            place += "位取り：\(fmt(a)) × \(fmt(b)) = (\(fmt(sa.mantissa)) × \(pow10(sa.exponent))) × (\(fmt(sb.mantissa)) × \(pow10(sb.exponent))) = \(fmt(sa.mantissa)) × \(fmt(sb.mantissa)) × \(pow10(sa.exponent + sb.exponent)) です。"
        }
        if useRight {
            place += "右基線を使ったときは、仮数どうしの積が D 尺の読みの 10 倍になります。"
        }
        place += placeSentence("D", digits, exponent)
        builder.add(place, RuleState(slide: slide, cursor: cursor), [.D])
    }

    private func buildDivide(_ a: Double, _ b: Double, _ builder: inout StepBuilder) {
        let sa = Scientific(a)
        let sb = Scientific(b)
        let la = Foundation.log10(sa.mantissa)
        let lb = Foundation.log10(sb.mantissa)
        builder.add("カーソル線を D 尺の \(fmt(sa.mantissa)) に合わせます。", RuleState(slide: 0, cursor: la), [.D])
        let slide = la - lb
        builder.add("滑尺を動かし、C 尺の \(fmt(sb.mantissa)) をカーソル線に合わせます。", RuleState(slide: slide, cursor: la), [.C, .D])
        let useLeft = slide >= -1e-12
        let cursor = useLeft ? max(slide, 0) : slide + 1
        let digits = useLeft ? sa.mantissa / sb.mantissa : sa.mantissa / sb.mantissa * 10
        if useLeft {
            builder.add("カーソル線を C 尺の左基線（1）に移します。", RuleState(slide: slide, cursor: cursor), [.C])
        } else {
            builder.add("C 尺の左基線は左にはみ出しているので、右基線（10）にカーソル線を移します。", RuleState(slide: slide, cursor: cursor), [.C])
        }
        builder.add("カーソル線の下の D 尺を読むと \(fmt(digits, 3)) です。長さの差 log \(fmt(sa.mantissa)) − log \(fmt(sb.mantissa)) が商の位置になります。", RuleState(slide: slide, cursor: cursor), [.D])
        let exponent = sa.exponent - sb.exponent - (useLeft ? 0 : 1)
        var place = ""
        if sa.exponent != 0 || sb.exponent != 0 {
            place += "位取り：\(fmt(a)) ÷ \(fmt(b)) = (\(fmt(sa.mantissa)) × \(pow10(sa.exponent))) ÷ (\(fmt(sb.mantissa)) × \(pow10(sb.exponent))) = (\(fmt(sa.mantissa)) ÷ \(fmt(sb.mantissa))) × \(pow10(sa.exponent - sb.exponent)) です。"
        }
        if !useLeft {
            place += "右基線を使ったときは、仮数どうしの商が D 尺の読みの 1/10 になります。"
        }
        place += placeSentence("D", digits, exponent)
        builder.add(place, RuleState(slide: slide, cursor: cursor), [.D])
    }

    private func buildSquareRoot(_ a: Double, _ builder: inout StepBuilder) {
        let s = Scientific(a)
        let odd = s.exponent.isMultiple(of: 2) == false
        let onA = odd ? s.mantissa * 10 : s.mantissa
        let x = Foundation.log10(onA) / 2
        let rootExponent = odd ? (s.exponent - 1) / 2 : s.exponent / 2
        let half = odd ? "右半分（10〜100）" : "左半分（1〜10）"
        builder.add("\(fmt(a)) = \(fmt(s.mantissa)) × \(pow10(s.exponent)) と表します。指数 \(s.exponent) が\(odd ? "奇数" : "偶数")なので、A 尺の\(half)を使います。", RuleState(slide: 0, cursor: 0.5), [.A])
        builder.add("カーソル線を A 尺の \(fmt(onA)) に合わせます。", RuleState(slide: 0, cursor: x), [.A])
        builder.add("カーソル線の下の D 尺を読むと \(fmt(onA.squareRoot(), 3)) です。", RuleState(slide: 0, cursor: x), [.D])
        let rootHead = rootExponent == 0 ? "" : "\(fmt(a)) = \(fmt(onA)) × \(pow10(2 * rootExponent)) の平方根は √\(fmt(onA)) × \(pow10(rootExponent)) です。"
        builder.add(rootHead + placeSentence("D", onA.squareRoot(), rootExponent), RuleState(slide: 0, cursor: x), [.D])
    }

    private func buildCubeRoot(_ a: Double, _ builder: inout StepBuilder) {
        let s = Scientific(a)
        // 指数を 3 で割った余り（負の指数でも 0〜2 にする）
        let r = ((s.exponent % 3) + 3) % 3
        let onK = s.mantissa * Foundation.pow(10, Double(r))
        let x = Foundation.log10(onK) / 3
        let rootExponent = (s.exponent - r) / 3
        let part = ["左の 1/3（1〜10）", "中央の 1/3（10〜100）", "右の 1/3（100〜1000）"][r]
        builder.add("\(fmt(a)) = \(fmt(onK)) × \(pow10(s.exponent - r)) と、指数が 3 の倍数になるように表します。K 尺の\(part)を使います。", RuleState(slide: 0, cursor: 0.5), [.K])
        builder.add("カーソル線を K 尺の \(fmt(onK)) に合わせます。", RuleState(slide: 0, cursor: x), [.K])
        builder.add("カーソル線の下の D 尺を読むと \(fmt(Foundation.cbrt(onK), 3)) です。", RuleState(slide: 0, cursor: x), [.D])
        let rootHead = rootExponent == 0 ? "" : "\(pow10(s.exponent - r)) の立方根は \(pow10(rootExponent)) です。"
        builder.add(rootHead + placeSentence("D", Foundation.cbrt(onK), rootExponent), RuleState(slide: 0, cursor: x), [.D])
    }
}

struct StepBuilder {
    private(set) var steps: [Step] = []

    mutating func add(_ text: String, _ state: RuleState, _ highlights: [ScaleID]) {
        steps.append(Step(id: steps.count, text: text, state: state, highlights: highlights))
    }
}

/// 10 の累乗を上付き文字で表す（10⁻²）
public func pow10(_ e: Int) -> String {
    let sup: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
    return "10" + String(String(e).map { sup[$0] ?? $0 })
}

/// 表示用の数値整形。significant を指定すると有効数字で丸める
public func fmt(_ v: Double, _ significant: Int? = nil, fixed: Bool = false) -> String {
    if fixed, let digits = significant {
        return String(format: "%.\(digits)f", v)
    }
    var value = v
    if let sig = significant, v != 0 {
        let e = Int(floor(log10(abs(v))))
        let factor = pow(10, Double(sig - 1 - e))
        value = (v * factor).rounded() / factor
    }
    if abs(value - value.rounded()) < 1e-9, abs(value) < 1e15 {
        return String(Int(value.rounded()))
    }
    var s = String(format: "%.6f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
