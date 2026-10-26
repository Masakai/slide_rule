import SwiftUI
import SlideRuleKit

struct PracticeScreen: View {
    @AppStorage("practiceKind") private var kind: ProblemKind = .multiply
    @AppStorage("practiceDifficulty") private var difficulty: Difficulty = .basic

    @State private var problem: SlideRuleKit.Operation = .multiply(2.3, 3.4)
    @State private var state = RuleState(slide: 0, cursor: 0)
    @State private var showReadings = false
    @State private var answerText = ""
    @State private var result: Grade?
    @State private var showSteps = false
    @State private var solved = 0
    @State private var attempted = 0
    @State private var streak = 0
    @FocusState private var answerFocused: Bool

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                settings

                HStack(alignment: .firstTextBaseline) {
                    Text(problem.question)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer()
                    Text("\(solved) / \(attempted) 問正解・連続 \(streak)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // キーボード表示中も答えの欄が隠れないよう、問題文のすぐ下に置く
                answerRow

                // iPhone では入力中に拡大表示を畳み、キーボードの上に収まるようにする
                RuleWorkbench(state: $state, showReadings: $showReadings, allowsLoupe: !(answerFocused && isCompact))

                ScrollView {
                    feedback
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("練習")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onAppear { if attempted == 0 { next() } }
        .onChange(of: kind) { next() }
        .onChange(of: difficulty) { next() }
    }

    private var settings: some View {
        HStack {
            Picker("種類", selection: $kind) {
                ForEach(ProblemKind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .fixedSize()
            Picker("難易度", selection: $difficulty) {
                ForEach(Difficulty.allCases) { d in
                    Text(d.title).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var answerRow: some View {
        HStack {
            if case .log10 = problem {
                // 小数点キーボードには負号がないため、常用対数の問題では符号の切り替えボタンを出す
                Button("±") { toggleSign() }
                    .buttonStyle(.bordered)
                    .help("符号を切り替えます")
                    .disabled(result == .correct)
            }
            TextField("答え（小数点も含めて）", text: $answerText)
                .textFieldStyle(.roundedBorder)
                .focused($answerFocused)
                .onSubmit(check)
                #if os(iOS)
                // 日本語入力の変換を通さないよう、小数点付きの数字キーボードを使う
                .keyboardType(.decimalPad)
                #endif
                .disabled(result == .correct)
            #if os(iOS)
            if answerFocused {
                // 小数点キーボードには閉じるキーがないため、閉じるボタンを出す
                Button {
                    answerFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("キーボードを閉じる")
            }
            #endif
            if result == .correct {
                Button("次の問題", action: next)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("答え合わせ", action: check)
                    .buttonStyle(.borderedProminent)
                    .disabled(Double(normalized(answerText)) == nil)
                Button("次へ", action: next)
                    .help("この問題を飛ばします")
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let result {
                Label(result.title, systemImage: icon(for: result))
                    .font(.headline)
                    .foregroundStyle(color(for: result))
                Text(message(for: result))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("計算尺を動かして答えを読み取り、入力してください。小数点の位置（位取り）も含めて採点します。有効数字 3 桁程度で読めれば正解です。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup("手順を見る", isExpanded: $showSteps) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(problem.steps) { step in
                        Button {
                            withAnimation(.easeInOut(duration: 0.8)) { state = step.state }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(step.id + 1).").monospacedDigit().foregroundStyle(.secondary)
                                Text(step.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("手順をタップすると、計算尺がその状態に動きます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.top, 4)
            }
        }
    }

    private func normalized(_ s: String) -> String {
        // 全角数字・全角記号も受け付ける
        s.applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespaces) ?? s
    }

    private func toggleSign() {
        if answerText.hasPrefix("-") {
            answerText.removeFirst()
        } else {
            answerText = "-" + answerText
        }
    }

    private func check() {
        guard let value = Double(normalized(answerText)) else { return }
        let grade = Grader.grade(value, for: problem)
        answerFocused = false
        if result == nil {
            attempted += 1
            if grade == .correct { solved += 1 }
        }
        streak = grade == .correct ? streak + 1 : 0
        result = grade
    }

    private func next() {
        var nextProblem = ProblemGenerator.make(kind, difficulty)
        while nextProblem == problem {
            nextProblem = ProblemGenerator.make(kind, difficulty)
        }
        problem = nextProblem
        answerText = ""
        result = nil
        showSteps = false
        withAnimation(.easeInOut(duration: 0.5)) {
            state = RuleState(slide: 0, cursor: 0)
        }
    }

    private func message(for grade: Grade) -> String {
        let answer = fmt(problem.answer, 4)
        switch grade {
        case .correct:
            return "正確な値は \(answer) です。"
        case .close:
            return "目盛り 1〜2 本分ずれています。拡大表示でカーソル線の位置を確かめてみてください。"
        case .wrongMagnitude:
            if case .log10 = problem {
                return "小数部分は合っています。整数部分（指標）を、元の数の 10 の累乗の指数から決め直してください。"
            }
            return "数字の並びは合っていますが、小数点の位置が違います。数を「仮数 × 10 の累乗」に分けて位取りを確かめてください。"
        case .wrong:
            return "読み取り値が離れています。「手順を見る」で操作を確認できます。"
        }
    }

    private func icon(for grade: Grade) -> String {
        switch grade {
        case .correct: return "checkmark.circle.fill"
        case .close: return "circle.dotted"
        case .wrongMagnitude: return "exclamationmark.triangle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    private func color(for grade: Grade) -> Color {
        switch grade {
        case .correct: return .green
        case .close: return .orange
        case .wrongMagnitude: return .orange
        case .wrong: return .red
        }
    }
}
