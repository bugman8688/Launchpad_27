import AppKit
import SwiftUI

/// 主界面：顶部搜索框 + 全屏图标网格。
struct ContentView: View {
    @UIState private var apps: [AppItem] = []
    @UIState private var searchText = ""

    private var keyword: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredApps: [AppItem] {
        guard !keyword.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    private var emptyStateText: String? {
        if apps.isEmpty && keyword.isEmpty {
            return "未找到应用"
        }
        if !keyword.isEmpty && filteredApps.isEmpty {
            return "无结果"
        }
        return nil
    }

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 24)
    ]

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 24) {
                searchField

                if let emptyStateText {
                    Spacer()
                    Text(emptyStateText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(filteredApps) { app in
                                AppIconCell(app: app)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 24)
                    }
                }
            }
            .padding(.top, 40)
        }
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
        .task {
            guard apps.isEmpty else { return }
            apps = AppCatalogService().loadApplications()
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.12, blue: 0.20), Color(red: 0.02, green: 0.03, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var searchField: some View {
        TextField("搜索", text: $searchText)
            .textFieldStyle(.plain)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(width: 320)
            .background(
                Capsule().fill(Color.white.opacity(0.15))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}
