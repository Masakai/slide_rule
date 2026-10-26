import SwiftUI
import SlideRuleKit

@main
struct SlideRuleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 780)
        #endif
    }
}

struct ContentView: View {
    @SceneStorage("selectedTab") private var selectedTab = "simulator"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("計算尺", systemImage: "ruler", value: "simulator") {
                SimulatorScreen()
            }
            Tab("レッスン", systemImage: "book", value: "lessons") {
                LessonListScreen()
            }
            Tab("練習", systemImage: "pencil.and.list.clipboard", value: "practice") {
                PracticeScreen()
            }
            Tab("原理", systemImage: "function", value: "principle") {
                PrincipleScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

/// 自由に操作できる計算尺
struct SimulatorScreen: View {
    @State private var state = RuleState(slide: 0, cursor: 0.3)
    @AppStorage("simulatorShowReadings") private var showReadings = true

    var body: some View {
        NavigationStack {
            // 計算尺のドラッグと縦スクロールが競合しないよう、計算尺は ScrollView の外に置く
            VStack(alignment: .leading, spacing: 12) {
                RuleWorkbench(state: $state, showReadings: $showReadings)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("操作")
                            .font(.headline)
                        Text("中央の滑尺（B・CI・C 尺）をドラッグすると滑尺が動き、それ以外の部分をドラッグするとカーソル線が動きます。下段の拡大表示でも同じように操作できます。細かい位置合わせには ‹ › ボタンを使います（長押しで連続移動）。")
                        Text("S 尺・T 尺は D 尺に対して読む配置です。")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("計算尺")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
