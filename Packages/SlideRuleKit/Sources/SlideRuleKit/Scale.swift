import Foundation

/// 計算尺の尺（目盛り）の種類。
///
/// 位置は尺の全長を 1 とした正規化座標（左端 0、右端 1）で扱う。
/// S 尺・T 尺は D 尺に対して読む配置（D 尺の値 ÷ 10 が sin・tan の値）にしている。
public enum ScaleID: String, CaseIterable, Sendable, Identifiable {
    case K, A, B, CI, C, D, L, S, T

    public var id: String { rawValue }

    /// 尺の名前（表示用）
    public var name: String { rawValue }

    /// D 尺の値を x としたときに、この尺が表す量
    public var formula: String {
        switch self {
        case .K: return "x³"
        case .A, .B: return "x²"
        case .CI: return "1/x"
        case .C, .D: return "x"
        case .L: return "log x"
        case .S: return "sin"
        case .T: return "tan"
        }
    }

    /// 滑尺（中央の動く部分）に刻まれているか
    public var isOnSlide: Bool {
        switch self {
        case .B, .CI, .C: return true
        default: return false
        }
    }

    /// 右から左へ増える（逆目盛り）か。表示で赤く描くために使う
    public var isInverted: Bool { self == .CI }

    /// 角度の尺か（入力・表示を度で扱う）
    public var isAngle: Bool { self == .S || self == .T }

    /// 目盛りが表す値の範囲
    public var domain: ClosedRange<Double> {
        switch self {
        case .C, .D, .CI: return 1...10
        case .A, .B: return 1...100
        case .K: return 1...1000
        case .L: return 0...1
        case .S: return ScaleID.sMinDegrees...90
        case .T: return ScaleID.tMinDegrees...45
        }
    }

    /// sin θ = 0.1 となる角度（S 尺の左端）
    public static let sMinDegrees = asin(0.1) * 180 / .pi
    /// tan θ = 0.1 となる角度（T 尺の左端）
    public static let tMinDegrees = atan(0.1) * 180 / .pi

    /// 値 → 正規化位置
    public func position(of value: Double) -> Double {
        switch self {
        case .C, .D: return log10(value)
        case .CI: return 1 - log10(value)
        case .A, .B: return log10(value) / 2
        case .K: return log10(value) / 3
        case .L: return value
        case .S: return log10(10 * sin(value * .pi / 180))
        case .T: return log10(10 * tan(value * .pi / 180))
        }
    }

    /// 正規化位置 → 値
    public func value(at position: Double) -> Double {
        switch self {
        case .C, .D: return pow(10, position)
        case .CI: return pow(10, 1 - position)
        case .A, .B: return pow(10, 2 * position)
        case .K: return pow(10, 3 * position)
        case .L: return position
        case .S: return asin(pow(10, position) / 10) * 180 / .pi
        case .T: return atan(pow(10, position) / 10) * 180 / .pi
        }
    }
}
