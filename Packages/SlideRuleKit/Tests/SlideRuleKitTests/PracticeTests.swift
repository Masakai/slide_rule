import Foundation
import Testing
@testable import SlideRuleKit

/// 再現性のある乱数（テスト用）
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite struct PracticeTests {
    @Test func gradeRelativeError() {
        let op = SlideRuleKit.Operation.multiply(3.2, 4.5)  // 14.4
        #expect(Grader.grade(14.4, for: op) == .correct)
        #expect(Grader.grade(14.45, for: op) == .correct)
        #expect(Grader.grade(14.6, for: op) == .close)
        #expect(Grader.grade(1.44, for: op) == .wrongMagnitude)
        #expect(Grader.grade(144, for: op) == .wrongMagnitude)
        #expect(Grader.grade(15.5, for: op) == .wrong)
        #expect(Grader.grade(-14.4, for: op) == .wrong)
    }

    @Test func gradeLog() {
        let op = SlideRuleKit.Operation.log10(300)  // 2.4771
        #expect(Grader.grade(2.477, for: op) == .correct)
        #expect(Grader.grade(2.483, for: op) == .close)
        #expect(Grader.grade(0.477, for: op) == .wrongMagnitude)
        #expect(Grader.grade(2.6, for: op) == .wrong)
    }

    @Test(arguments: ProblemKind.allCases)
    func generatedProblemsAreSolvableOnTheRule(kind: ProblemKind) {
        var rng = SeededGenerator(state: 42)
        for difficulty in Difficulty.allCases {
            for _ in 0..<200 {
                let op = ProblemGenerator.make(kind, difficulty, using: &rng)
                #expect(op.answer.isFinite)
                if kind != .log10 { #expect(op.answer > 0) }
                let last = op.steps.last!
                #expect(RuleState.slideRange.contains(last.state.slide))
                #expect(RuleState.cursorRange.contains(last.state.cursor))
                // 正解をそのまま入力すれば正解になる
                #expect(Grader.grade(op.answer, for: op) == .correct)
                if difficulty == .basic, kind == .multiply || kind == .divide {
                    if case let .multiply(a, b) = op { #expect(a >= 1.1 && a <= 9.9 && b >= 1.1 && b <= 9.9) }
                }
            }
        }
    }
}
