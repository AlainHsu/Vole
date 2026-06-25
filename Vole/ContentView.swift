//
//  ContentView.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: TabID = .home
    @State private var homeFeedSelection: HomeFeed = .latest
    @StateObject private var navManager = NavigationManager()
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @ObservedObject private var notifyManager = NotifyManager.shared

    var body: some View {

        Group {
            if #available(iOS 26, *) {
                TabView(selection: $selection) {
                    Tab("主页", systemImage: "doc.text.image", value: .home) {
                        HomeView(selection: $homeFeedSelection)
                    }
                    Tab(
                        "节点",
                        systemImage: "square.grid.2x2.fill",
                        value: .node
                    ) {
                        NodeView()
                    }
                    Tab(
                        "通知",
                        systemImage: "tray.full.fill",
                        value: .notify
                    ) {
                        NotifyView()
                    }
                    .badge(
                        notifyManager.unreadCount > 0
                            ? notifyManager.unreadCount : 0
                    )
                    Tab(
                        "搜索",
                        systemImage: "magnifyingglass",
                        value: .search,
                        role: .search
                    ) {
                        SearchView()
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .homeFeedBottomAccessory(
                    isEnabled: selection == .home,
                    selection: $homeFeedSelection,
                    collections: collectionManager.customCollections
                )
            } else {
                TabView(selection: $selection) {
                    Tab("主页", systemImage: "doc.text.image", value: .home) {
                        HomeView(selection: $homeFeedSelection)
                    }
                    Tab(
                        "节点",
                        systemImage: "square.grid.2x2.fill",
                        value: .node
                    ) {
                        NodeView()
                    }
                    Tab(
                        "通知",
                        systemImage: "tray.full.fill",
                        value: .notify
                    ) {
                        NotifyView()
                    }
                    .badge(
                        notifyManager.unreadCount > 0
                            ? notifyManager.unreadCount : 0
                    )
                    Tab(
                        "搜索",
                        systemImage: "magnifyingglass",
                        value: .search,
                        role: .search
                    ) {
                        SearchView()
                    }
                }
            }
        }
        .environmentObject(navManager)
        .onAppear {
            notifyManager.updateScenePhase(scenePhase)
        }
        .onChange(of: scenePhase) { _, newValue in
            notifyManager.updateScenePhase(newValue)
        }
    }
}

enum TabID: Hashable {
    case home, node, notify, search
}

@available(iOS 26, *)
private struct HomeFeedBottomAccessoryModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var selection: HomeFeed
    let collections: [NodeCollection]

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) {
                HomeFeedPicker(
                    selection: $selection,
                    collections: collections
                )
                .frame(maxWidth: 360)
                .padding(.horizontal, 8)
            }
        } else {
            if isEnabled {
                content.tabViewBottomAccessory {
                    HomeFeedPicker(
                        selection: $selection,
                        collections: collections
                    )
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 8)
                }
            } else {
                content
            }
        }
    }
}

private extension View {
    @available(iOS 26, *)
    func homeFeedBottomAccessory(
        isEnabled: Bool,
        selection: Binding<HomeFeed>,
        collections: [NodeCollection]
    ) -> some View {
        modifier(
            HomeFeedBottomAccessoryModifier(
                isEnabled: isEnabled,
                selection: selection,
                collections: collections
            )
        )
    }
}

#Preview {
    ContentView()
    //        .modelContainer(for: Item.self, inMemory: true)
}
