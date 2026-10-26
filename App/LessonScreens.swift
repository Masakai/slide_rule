import SwiftUI
import SlideRuleKit

struct LessonListScreen: View {
    var body: some View {
        NavigationStack {
            List(Array(LessonCatalog.all.enumerated()), id: \.element.id) { index, lesson in
                NavigationLink {
                    LessonDetailScreen(lesson: lesson)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lesson.title).font(.headline)
                            Text(lesson.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("レッスン")
        }
    }
}

struct LessonDetailScreen: View {
    let lesson: Lesson

    @State private var state = RuleState(slide: 0, cursor: 0)
    @State private var index = -1
    @AppStorage("lessonShowReadings") private var showReadings = false

    private var current: Step? {
        lesson.steps.indices.contains(index) ? lesson.steps[index] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RuleWorkbench(state: $state, highlights: Set(current?.highlights ?? []), showReadings: $showReadings)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let current {
                        Text("手順 \(index + 1) / \(lesson.steps.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(current.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .id(current.id)
                    } else {
                        Text(lesson.intro)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("「次へ」で手順を 1 つずつ進めると、計算尺が自動で動きます。途中で自分で動かして確かめることもできます。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button {
                    go(to: index - 1)
                } label: {
                    Label("前へ", systemImage: "chevron.left")
                }
                .disabled(index < 0)

                Spacer()

                if current != nil {
                    Button("もう一度") { apply(current!) }
                        .help("この手順の状態に計算尺を戻します")
                }

                Spacer()

                Button {
                    go(to: index + 1)
                } label: {
                    Label(index < 0 ? "始める" : "次へ", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(index >= lesson.steps.count - 1)
            }
        }
        .padding()
        .navigationTitle(lesson.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func go(to newIndex: Int) {
        index = max(-1, min(newIndex, lesson.steps.count - 1))
        if let current { apply(current) }
    }

    private func apply(_ step: Step) {
        withAnimation(.easeInOut(duration: 0.9)) {
            state = step.state
        }
    }
}

/// アイコンを文字の右に置くラベル
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
