import Foundation
import Testing
@testable import SlideRuleKit

/// 手順の最後の状態で、カーソル線の下に正しい値が読めることを確かめる
@Suite struct OperationTests {
    private func finalState(_ op: SlideRuleKit.Operation) -> RuleState {
        op.steps.last!.state
    }

    private func isClose(_ a: Double?, _ b: Double, tol: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) <= tol * max(1, abs(b))
    }

    @Test func scientific() {
        #expect(Scientific(1000) == Scientific(1000))
        #expect(Scientific(1000).exponent == 3)
        #expect(abs(Scientific(1000).mantissa - 1) < 1e-12)
        #expect(Scientific(0.0032).exponent == -3)
        #expect(abs(Scientific(0.0032).mantissa - 3.2) < 1e-12)
        #expect(Scientific(9.99).exponent == 0)
    }

    @Test func multiplyLeftIndex() {
        let s = finalState(.multiply(2, 3))
        #expect(isClose(s.reading(.D), 6))
        #expect(isClose(s.slide, log10(2)))
        #expect(isClose(s.reading(.C), 3))
    }

    @Test(arguments: [(3.0, 4.0, 1.2), (7.0, 8.0, 5.6), (5.0, 2.5, 1.25)])
    func multiplyRightIndex(a: Double, b: Double, digits: Double) {
        let s = finalState(.multiply(a, b))
        #expect(s.slide < 0)
        #expect(isClose(s.reading(.D), digits))
        #expect(isClose(s.reading(.C), b))
    }

    @Test func multiplyWithPlacement() {
        let op = SlideRuleKit.Operation.multiply(0.032, 450)
        #expect(isClose(op.answer, 14.4))
        let s = finalState(op)
        #expect(isClose(s.reading(.D), 1.44))
        #expect(op.steps.last!.text.contains("14.4"))
    }

    @Test(arguments: [(6.0, 2.0, 3.0), (8.4, 3.5, 2.4), (2.0, 8.0, 2.5), (0.56, 0.0028, 2.0)])
    func divide(a: Double, b: Double, digits: Double) {
        let s = finalState(.divide(a, b))
        #expect(isClose(s.reading(.D), digits))
        // カーソル線はどちらかの基線の上にある
        let c = s.reading(.C)!
        #expect(isClose(c, 1) || isClose(c, 10))
    }

    @Test func divideStepTwoAlignsDivisorOverDividend() {
        let steps = SlideRuleKit.Operation.divide(8.4, 3.5).steps
        #expect(isClose(steps[1].state.reading(.D), 8.4))
        #expect(isClose(steps[1].state.reading(.C), 3.5))
    }

    @Test func reciprocal() {
        let s = finalState(.reciprocal(4))
        #expect(isClose(s.reading(.CI), 2.5))
        #expect(isClose(s.reading(.C), 4))
    }

    @Test func square() {
        let s = finalState(.square(3))
        #expect(isClose(s.reading(.A), 9))
        let s2 = finalState(.square(0.25))
        #expect(isClose(s2.reading(.A), 6.25))
        #expect(SlideRuleKit.Operation.square(0.25).steps.last!.text.contains("0.0625"))
    }

    @Test(arguments: [(2.0, 1.4142135623730951), (20.0, 4.47213595499958), (0.5, 7.0710678118654755), (200.0, 1.4142135623730951), (0.02, 1.4142135623730951)])
    func squareRootPicksHalfByExponentParity(a: Double, digits: Double) {
        let op = SlideRuleKit.Operation.squareRoot(a)
        let s = finalState(op)
        #expect(isClose(s.reading(.D), digits))
        // A 尺の読みは仮数 × 10^(指数の偶奇) になっている
        let sc = Scientific(a)
        let expectedA = sc.exponent.isMultiple(of: 2) ? sc.mantissa : sc.mantissa * 10
        #expect(isClose(s.reading(.A), expectedA))
        #expect(isClose(Scientific(op.answer).mantissa, digits))
    }

    @Test(arguments: [(2.0, 1.2599210498948732), (27.0, 3.0), (500.0, 7.937005259840998), (0.008, 2.0), (0.05, 3.6840314986403864)])
    func cubeRootPicksSegment(a: Double, digits: Double) {
        let op = SlideRuleKit.Operation.cubeRoot(a)
        let s = finalState(op)
        #expect(isClose(s.reading(.D), digits, tol: 1e-9))
        #expect(isClose(Scientific(op.answer).mantissa, digits, tol: 1e-9))
    }

    @Test func cube() {
        let s = finalState(.cube(2))
        #expect(isClose(s.reading(.K), 8))
    }

    @Test func log() {
        let s = finalState(.log10(300))
        #expect(isClose(s.reading(.L), log10(3)))
        #expect(SlideRuleKit.Operation.log10(300).steps.last!.text.contains("2.477"))
    }

    @Test func sineAndTangent() {
        #expect(isClose(finalState(.sine(30)).reading(.D), 5))
        #expect(isClose(finalState(.sine(10)).reading(.D), 10 * sin(10 * .pi / 180)))
        #expect(isClose(finalState(.tangent(45)).reading(.D), 10))
        #expect(isClose(finalState(.tangent(20)).reading(.D), 10 * tan(20 * .pi / 180)))
    }

    @Test func allLessonStepsAreWithinRange() {
        for lesson in LessonCatalog.all {
            #expect(!lesson.steps.isEmpty)
            for step in lesson.steps {
                #expect(RuleState.slideRange.contains(step.state.slide))
                #expect(RuleState.cursorRange.contains(step.state.cursor))
            }
        }
    }

    @Test func finalHighlightedScaleIsReadable() {
        for lesson in LessonCatalog.all {
            for step in lesson.steps {
                for h in step.highlights {
                    // 手順の最初の「〇尺のどちら半分を使う」説明はカーソル位置が仮なので除く
                    if step.text.contains("を使います") { continue }
                    #expect(step.state.reading(h) != nil, "\(lesson.title): \(step.text) / \(h)")
                }
            }
        }
    }

    @Test func pow10Superscript() {
        #expect(pow10(-2) == "10⁻²")
        #expect(pow10(12) == "10¹²")
    }

    @Test func formatting() {
        #expect(fmt(14.400000001, 3) == "14.4")
        #expect(fmt(0.0625) == "0.0625")
        #expect(fmt(2.0) == "2")
        #expect(fmt(0.47712, 3, fixed: true) == "0.477")
    }
}
