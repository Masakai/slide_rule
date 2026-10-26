import Foundation

/// 練習問題の種類
public enum ProblemKind: String, CaseIterable, Sendable, Identifiable {
    case multiply, divide, reciprocal, square, squareRoot, cube, cubeRoot, log10, sine, tangent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .multiply: return "掛け算"
        case .divide: return "割り算"
        case .reciprocal: return "逆数"
        case .square: return "2 乗"
        case .squareRoot: return "平方根"
        case .cube: return "3 乗"
        case .cubeRoot: return "立方根"
        case .log10: return "常用対数"
        case .sine: return "sin"
        case .tangent: return "tan"
        }
    }
}

/// 難易度
public enum Difficulty: String, CaseIterable, Sendable, Identifiable {
    /// 1〜10 の数だけを使う。位取りは不要
    case basic
    /// 0.01〜1000 程度の数を使い、位取りも求める
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .basic: return "初級（1〜10）"
        case .advanced: return "上級（位取りあり）"
        }
    }
}

/// 採点結果
public enum Grade: Sendable, Equatable {
    /// 計算尺の読み取り精度の範囲内
    case correct
    /// 目盛り 1〜2 本分ずれている
    case close
    /// 数字の並びは合っているが桁（位取り）が違う
    case wrongMagnitude
    case wrong

    public var title: String {
        switch self {
        case .correct: return "正解"
        case .close: return "惜しい"
        case .wrongMagnitude: return "桁が違います"
        case .wrong: return "不正解"
        }
    }
}

public enum Grader {
    /// 正解とみなす相対誤差。D 尺右端（目盛り 0.05 刻み）で半目盛りを読み違えた程度
    public static let correctTolerance = 0.005
    /// 惜しいとみなす相対誤差
    public static let closeTolerance = 0.015
    /// 常用対数は絶対誤差で判定する（L 尺は 0.002 刻み程度で読める）
    public static let logCorrectTolerance = 0.003
    public static let logCloseTolerance = 0.008

    /// 解答者は小数点を含めた値そのもの（例：14.4）を入力する前提で採点する
    public static func grade(_ input: Double, for operation: Operation) -> Grade {
        let answer = operation.answer
        if case .log10 = operation {
            let diff = abs(input - answer)
            if diff <= logCorrectTolerance { return .correct }
            if diff <= logCloseTolerance { return .close }
            // 小数部分（仮数）は合っていて整数部分（指標）だけ違う
            let frac = abs((input - answer) - (input - answer).rounded())
            if frac <= logCloseTolerance { return .wrongMagnitude }
            return .wrong
        }
        guard input > 0, answer > 0 else { return .wrong }
        let ratio = input / answer
        let rel = abs(ratio - 1)
        if rel <= correctTolerance { return .correct }
        if rel <= closeTolerance { return .close }
        let k = Foundation.log10(ratio).rounded()
        if k != 0, abs(ratio / Foundation.pow(10, k) - 1) <= closeTolerance {
            return .wrongMagnitude
        }
        return .wrong
    }
}

public enum ProblemGenerator {
    /// 指定した種類・難易度の問題を 1 問作る
    public static func make<G: RandomNumberGenerator>(_ kind: ProblemKind, _ difficulty: Difficulty, using rng: inout G) -> Operation {
        func operand() -> Double {
            // 有効数字 2 桁（1.1〜9.9）。1.0 ちょうどは計算にならないので避ける
            let base = Double(Int.random(in: 11...99, using: &rng)) / 10
            guard difficulty == .advanced else { return base }
            let shift = Int.random(in: -2...2, using: &rng)
            return roundTo(base * Foundation.pow(10, Double(shift)))
        }
        switch kind {
        case .multiply:
            return .multiply(operand(), operand())
        case .divide:
            var a = operand()
            var b = operand()
            while abs(a - b) < 1e-12 {
                a = operand()
                b = operand()
            }
            return .divide(a, b)
        case .reciprocal:
            return .reciprocal(operand())
        case .square:
            return .square(operand())
        case .squareRoot:
            if difficulty == .basic {
                // A 尺の両半分を使うよう 1〜100 から出題
                let v = Double(Int.random(in: 2...99, using: &rng))
                return .squareRoot(v)
            }
            return .squareRoot(operand())
        case .cube:
            return .cube(operand())
        case .cubeRoot:
            if difficulty == .basic {
                let v = Double(Int.random(in: 2...999, using: &rng))
                return .cubeRoot(v)
            }
            return .cubeRoot(operand())
        case .log10:
            return .log10(operand())
        case .sine:
            // 90° に近いと S 尺の目盛りが詰まって読めないので 6°〜70° に限る
            return .sine(Double(Int.random(in: 6...70, using: &rng)))
        case .tangent:
            return .tangent(Double(Int.random(in: 6...44, using: &rng)))
        }
    }

    public static func make(_ kind: ProblemKind, _ difficulty: Difficulty) -> Operation {
        var rng = SystemRandomNumberGenerator()
        return make(kind, difficulty, using: &rng)
    }

    /// 0.31000000000000005 のような誤差を落とす
    private static func roundTo(_ v: Double) -> Double {
        (v * 1e6).rounded() / 1e6
    }
}
