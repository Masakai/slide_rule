import Foundation

/// レッスン 1 回分
public struct Lesson: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    /// 冒頭の説明
    public let intro: String
    /// 計算尺上で再現する手順
    public let steps: [Step]
}

public enum LessonCatalog {
    public static let all: [Lesson] = [
        reading,
        lesson(
            id: "multiply-left",
            title: "掛け算（左基線）",
            summary: "C 尺と D 尺で長さを足す",
            intro: "計算尺の C 尺・D 尺は、数 x を log x の長さの位置に刻んでいます。滑尺をずらして長さ log a に log b をつなげると、合計の位置 log a + log b = log ab に積が現れます。まず積が 10 未満になる例で、C 尺の左端の 1（左基線）を使う方法を練習します。",
            operations: [.multiply(2, 3), .multiply(1.5, 4.2)]
        ),
        lesson(
            id: "multiply-right",
            title: "掛け算（右基線）",
            summary: "はみ出すときは右基線を使う",
            intro: "3 × 4 のように仮数どうしの積が 10 を超えると、左基線を合わせたときに C 尺の 4 が D 尺の右端より外に出てしまいます。このときは C 尺の右端の 10（右基線）を合わせます。滑尺を 1 本分左にずらすことは、答えを 10 で割って読むことに相当します。",
            operations: [.multiply(3, 4), .multiply(7, 8)]
        ),
        lesson(
            id: "divide",
            title: "割り算",
            summary: "長さを引いて商を読む",
            intro: "割り算は掛け算の逆で、長さ log a から log b を引きます。D 尺の a に C 尺の b を重ねると、C 尺の基線の位置に商が現れます。左基線が D 尺の外に出たら右基線で読みます。",
            operations: [.divide(6, 2), .divide(8.4, 3.5), .divide(2, 8)]
        ),
        lesson(
            id: "reciprocal",
            title: "逆数と CI 尺",
            summary: "C 尺を裏返した尺で 1/x を読む",
            intro: "CI 尺は C 尺を左右反対にした尺で、赤い数字で刻まれています。位置 x に 1/x の値（ただし 1〜10 の範囲に直したもの）があるので、カーソルを C 尺に合わせるだけで逆数が読めます。",
            operations: [.reciprocal(4), .reciprocal(2.5)]
        ),
        lesson(
            id: "square",
            title: "2 乗と平方根",
            summary: "A 尺と D 尺の関係",
            intro: "A 尺は 1〜10 の目盛りを D 尺の半分の長さに縮めて 2 回並べ、全長で 1〜100 を表す尺です。位置 x で A 尺は 10^(2x)、D 尺は 10^x なので、D 尺で x を合わせると A 尺に x² が読めます。平方根では逆に A 尺から D 尺へ読みます。A 尺の左半分と右半分のどちらを使うかが要点です。",
            operations: [.square(3), .squareRoot(2), .squareRoot(20), .squareRoot(0.5)]
        ),
        lesson(
            id: "cube",
            title: "3 乗と立方根",
            summary: "K 尺は 1〜1000",
            intro: "K 尺は 1〜10 の目盛りを D 尺の 1/3 の長さに縮めて 3 回並べ、全長で 1〜1000 を表す尺です。D 尺の x に対して K 尺に x³ が読めます。立方根では、元の数の指数が 3 の倍数になるように書き直して、K 尺の 3 つの区間のどれを使うかを決めます。",
            operations: [.cube(2), .cubeRoot(27), .cubeRoot(500), .cubeRoot(2)]
        ),
        lesson(
            id: "log",
            title: "常用対数（L 尺）",
            summary: "等間隔の L 尺で log を読む",
            intro: "L 尺は 0〜1 を等間隔に刻んだ尺です。D 尺の数 x の位置は log₁₀ x の長さなので、L 尺を読むとそのまま log₁₀ x の小数部分が得られます。",
            operations: [.log10(2), .log10(300)]
        ),
        lesson(
            id: "trig",
            title: "三角関数（S 尺・T 尺）",
            summary: "角度から sin・tan を読む",
            intro: "このアプリでは S 尺と T 尺を D 尺に対して読む配置にしています。実物の計算尺には S・T 尺を滑尺の裏や C 尺に対して読む機種も多いので、手持ちの計算尺がある場合は説明書で確認してください。S 尺は 5.74°〜90°、T 尺は 5.71°〜45° を扱い、どちらも D 尺の読みを 10 で割った値が答えです。",
            operations: [.sine(30), .sine(10), .tangent(20), .tangent(45)]
        ),
        lesson(
            id: "placement",
            title: "位取り（桁の決め方）",
            summary: "計算尺は数字の並びだけを出す",
            intro: "計算尺は 3 桁程度の数字の並びを出す道具で、小数点の位置は教えてくれません。数を「仮数 × 10 の累乗」に分け、仮数を計算尺で、10 の累乗を暗算で扱います。概算で答えの大きさを見積もって確かめる習慣も役立ちます。",
            operations: [.multiply(0.032, 450), .divide(0.56, 0.0028)]
        ),
    ]

    /// 目盛りの読み方
    static var reading: Lesson {
        var b = StepBuilder()
        let d = ScaleID.D
        b.add("D 尺の左端の 1 を左基線、右端の 10 を右基線と呼びます。C 尺・D 尺は 1〜10 を対数の長さで刻んでいるので、左ほど目盛りの間隔が広くなっています。", RuleState(slide: 0, cursor: 0), [.C, .D])
        b.add("1〜2 の区間は目盛りが細かく刻まれます。カーソル線は D 尺の 1.5 にあります。拡大表示（ルーペ）にすると 0.01 刻みの目盛りが見えます。", RuleState(slide: 0, cursor: d.position(of: 1.5)), [.D])
        b.add("D 尺の 1.23 です。1.2 と 1.3 の間を 10 等分した 3 本目です。", RuleState(slide: 0, cursor: d.position(of: 1.23)), [.D])
        b.add("2〜4 の区間は 0.02 刻みです。カーソル線は 2.46 にあります。", RuleState(slide: 0, cursor: d.position(of: 2.46)), [.D])
        b.add("4〜10 の区間は 0.05 刻みです。7.85 は 7.8 と 7.9 の間の中央です。目盛りの間を目分量で読むと、もう 1 桁の見当がつきます。", RuleState(slide: 0, cursor: d.position(of: 7.85)), [.D])
        b.add("読み取れるのは有効数字 3 桁程度です。右へ行くほど 1 目盛りが表す値が大きくなるので、相対的な精度はどこでもほぼ同じになります。", RuleState(slide: 0, cursor: 1), [.D])
        return Lesson(
            id: "reading",
            title: "目盛りの読み方",
            summary: "C 尺・D 尺の刻みを知る",
            intro: "最初に、計算の基本となる C 尺と D 尺の目盛りを読めるようにします。区間ごとに 1 目盛りの大きさが違う点に注意します。",
            steps: b.steps
        )
    }

    /// 複数の計算例をつなげて 1 つのレッスンにする
    static func lesson(id: String, title: String, summary: String, intro: String, operations: [Operation]) -> Lesson {
        var steps: [Step] = []
        for op in operations {
            let opSteps = op.steps
            for (i, s) in opSteps.enumerated() {
                let text = i == 0 ? "【\(op.question)】\(s.text)" : s.text
                steps.append(Step(id: steps.count, text: text, state: s.state, highlights: s.highlights))
            }
        }
        return Lesson(id: id, title: title, summary: summary, intro: intro, steps: steps)
    }
}
