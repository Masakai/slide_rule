import Foundation
import Testing
@testable import SlideRuleKit

@Suite struct ScaleTests {
    @Test(arguments: ScaleID.allCases)
    func positionAndValueAreInverse(scale: ScaleID) {
        for i in 0...100 {
            let x = Double(i) / 100
            #expect(abs(scale.position(of: scale.value(at: x)) - x) < 1e-9)
        }
    }

    @Test(arguments: ScaleID.allCases)
    func domainMapsToUnitInterval(scale: ScaleID) {
        let ends = [scale.position(of: scale.domain.lowerBound), scale.position(of: scale.domain.upperBound)].sorted()
        #expect(abs(ends[0]) < 1e-9)
        #expect(abs(ends[1] - 1) < 1e-9)
    }

    @Test func sineScaleAgainstD() {
        let d = ScaleID.D
        #expect(abs(d.value(at: ScaleID.S.position(of: 30)) - 5) < 1e-9)
        #expect(abs(d.value(at: ScaleID.S.position(of: 90)) - 10) < 1e-9)
        #expect(abs(d.value(at: ScaleID.S.position(of: ScaleID.sMinDegrees)) - 1) < 1e-9)
        #expect(abs(ScaleID.sMinDegrees - 5.739) < 0.001)
    }

    @Test func tangentScaleAgainstD() {
        let d = ScaleID.D
        #expect(abs(d.value(at: ScaleID.T.position(of: 45)) - 10) < 1e-9)
        #expect(abs(d.value(at: ScaleID.T.position(of: ScaleID.tMinDegrees)) - 1) < 1e-9)
        #expect(abs(ScaleID.tMinDegrees - 5.711) < 0.001)
    }

    @Test func ciIsReciprocalOfC() {
        for v in stride(from: 1.0, through: 10.0, by: 0.37) {
            let state = RuleState(slide: 0.2, cursor: 0.2 + log10(v) * 0.8)
            let c = state.reading(.C)!
            let ci = state.reading(.CI)!
            #expect(abs(c * ci - 10) < 1e-9)
        }
    }

    @Test func lIsMantissaOfLogD() {
        for v in [1.0, 2.0, 3.16, 7.5, 9.99] {
            let state = RuleState(slide: 0, cursor: log10(v))
            #expect(abs(state.reading(.L)! - log10(v)) < 1e-9)
        }
    }

    @Test func slideScalesOutOfRangeReturnNil() {
        let state = RuleState(slide: 0.6, cursor: 0.3)
        #expect(state.reading(.C) == nil)
        #expect(state.reading(.D) != nil)
    }
}

@Suite struct TickTests {
    @Test func cScaleOneToTwoAtPhoneWidth() {
        let ticks = ScaleID.C.ticks(pixelLength: 340).filter { $0.value <= 2 + 1e-9 }
        // 0.05 刻みで 21 本、1 と 2 が主目盛り
        #expect(ticks.count == 21)
        #expect(ticks.first?.label == "1")
        #expect(ticks.last?.label == "2")
        #expect(abs(ticks[10].value - 1.5) < 1e-9)
        #expect(abs(ticks[10].position - log10(1.5)) < 1e-9)
    }

    @Test func cScaleFineWhenZoomed() {
        let ticks = ScaleID.C.ticks(pixelLength: 2000)
        #expect(ticks.contains { abs($0.value - 1.01) < 1e-9 })
        #expect(ticks.contains { abs($0.value - 2.02) < 1e-9 })
        #expect(ticks.contains { abs($0.value - 9.95) < 1e-9 })
        // 1.05 のような半端な目盛りには数字を付けない
        #expect(ticks.first { abs($0.value - 1.05) < 1e-9 }?.label == nil)
        #expect(ticks.first { abs($0.value - 1.1) < 1e-9 }?.label == "1")
    }

    @Test(arguments: ScaleID.allCases)
    func ticksAreSortedUniqueAndInDomain(scale: ScaleID) {
        for px in [300.0, 800.0, 3000.0] {
            let ticks = scale.ticks(pixelLength: px)
            #expect(!ticks.isEmpty)
            for (a, b) in zip(ticks, ticks.dropFirst()) {
                #expect(b.value > a.value + 1e-9)
            }
            for t in ticks {
                #expect(t.position >= -1e-9 && t.position <= 1 + 1e-9)
            }
        }
    }

    @Test func majorLabelsOfK() {
        let labels = ScaleID.K.ticks(pixelLength: 340).filter { $0.level == 0 }.compactMap(\.label)
        #expect(labels.contains("1"))
        #expect(labels.contains("10"))
        #expect(labels.contains("100"))
        #expect(labels.contains("1000"))
    }
}
