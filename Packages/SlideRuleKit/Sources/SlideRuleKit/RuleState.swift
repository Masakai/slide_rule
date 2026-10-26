import Foundation

/// 計算尺の状態（滑尺の位置とカーソルの位置）
public struct RuleState: Sendable, Equatable {
    /// 滑尺のずれ。C 尺の左基線（1）が D 尺のどの位置にあるか（正規化座標）
    public var slide: Double
    /// カーソル線の位置（固定尺に対する正規化座標）
    public var cursor: Double

    public static let slideRange: ClosedRange<Double> = -1...1
    public static let cursorRange: ClosedRange<Double> = 0...1

    public init(slide: Double = 0, cursor: Double = 0.5) {
        self.slide = slide.clamped(to: Self.slideRange)
        self.cursor = cursor.clamped(to: Self.cursorRange)
    }

    /// 尺上の正規化位置（その尺自身の座標）
    public func localPosition(of scale: ScaleID) -> Double {
        scale.isOnSlide ? cursor - slide : cursor
    }

    /// カーソル線の下にある、その尺の値。尺の範囲外なら nil
    public func reading(_ scale: ScaleID) -> Double? {
        let x = localPosition(of: scale)
        guard x >= -1e-9, x <= 1 + 1e-9 else { return nil }
        return scale.value(at: x.clamped(to: 0...1))
    }

    /// 滑尺上の尺の位置 x が、固定尺のどこに来ているか
    public func statorPosition(ofSlidePosition x: Double) -> Double {
        x + slide
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
