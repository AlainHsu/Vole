import Kingfisher
import SwiftUI

struct HomeNodeListSettingsView: View {
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @State private var showCreateSheet = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            homeFeedSection
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("首页列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                HomeNodeCollectionEditorView(mode: .create)
            }
        }
    }

    private var homeFeedSection: some View {
        Section {
            ForEach(homeFeedItems) { item in
                homeFeedRow(item)
            }
            .onMove(perform: collectionManager.moveHomeFeed)
            .onDelete(perform: deleteHomeFeeds)
        } footer: {
            Text("首页 picker 只显示排序最靠前的 3 个列表。内置列表只能拖动排序。")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                toggleEditMode()
            } label: {
                Image(systemName: editModeIconName)
            }

            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var homeFeedItems: [HomeFeedSettingsItem] {
        collectionManager.homeFeedOrderIDs.compactMap(homeFeedItem)
    }

    private var editModeIconName: String {
        editMode.isEditing ? "checkmark" : "arrow.up.arrow.down"
    }

    @ViewBuilder
    private func homeFeedRow(_ item: HomeFeedSettingsItem) -> some View {
        switch item.kind {
        case .builtIn:
            rowContent(title: item.title, subtitle: item.subtitle)
                .deleteDisabled(true)
        case .collection(let collection):
            NavigationLink {
                HomeNodeCollectionEditorView(mode: .edit(collection))
            } label: {
                rowContent(title: item.title, subtitle: item.subtitle)
            }
        }
    }

    private func rowContent(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func homeFeedItem(for id: String) -> HomeFeedSettingsItem? {
        switch id {
        case NodeCollectionManager.latestFeedID:
            return .builtIn(id: id, title: "最新")
        case NodeCollectionManager.hotFeedID:
            return .builtIn(id: id, title: "热门")
        default:
            return collectionFeedItem(for: id)
        }
    }

    private func collectionFeedItem(for id: String) -> HomeFeedSettingsItem? {
        guard let feed = HomeFeed(id: id, collectionManager: collectionManager),
            case .collection(let collectionID) = feed,
            let collection = collectionManager.customCollection(id: collectionID)
        else { return nil }

        return HomeFeedSettingsItem(
            id: id,
            title: collection.name,
            subtitle: "\(collection.nodeNames.count.formattedCount)/10 个节点",
            kind: .collection(collection)
        )
    }

    private func toggleEditMode() {
        withAnimation {
            editMode = editMode.isEditing ? .inactive : .active
        }
    }

    private func deleteHomeFeeds(at offsets: IndexSet) {
        let items = homeFeedItems
        for index in offsets {
            guard case .collection(let collection) = items[index].kind
            else { continue }
            collectionManager.removeCustomCollection(collection)
        }
    }
}

private struct HomeFeedSettingsItem: Identifiable {
    enum Kind {
        case builtIn
        case collection(NodeCollection)
    }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind

    static func builtIn(id: String, title: String) -> HomeFeedSettingsItem {
        HomeFeedSettingsItem(
            id: id,
            title: title,
            subtitle: "内置列表",
            kind: .builtIn
        )
    }
}

struct HomeNodeCollectionEditorView: View {
    enum Mode {
        case create
        case edit(NodeCollection)
    }

    let mode: Mode

    @StateObject private var collectionManager = NodeCollectionManager.shared
    @StateObject private var nodeManager = NodeManager.shared

    @State private var name: String
    @State private var selectedNodeNames: Set<String>
    @State private var searchText = ""
    @State private var showLimitAlert = false
    @State private var createdCollection: NodeCollection?

    private let maxNodeCount = 10

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedNodeNames = State(initialValue: [])
        case .edit(let collection):
            _name = State(initialValue: collection.name)
            _selectedNodeNames = State(initialValue: Set(collection.nodeNames))
        }
    }

    var body: some View {
        List {
            nameSection
            selectedSection
            nodeSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索节点")
        .task {
            if nodeManager.nodes.isEmpty {
                await nodeManager.refreshNodes(force: false)
            }
        }
        .onChange(of: name) { _, _ in
            persistChanges()
        }
        .onChange(of: selectedNodeNames) { _, _ in
            persistChanges()
        }
        .alert("最多选择 \(maxNodeCount) 个节点", isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        }
    }

    private var nameSection: some View {
        Section {
            TextField("列表名称", text: $name)
        }
    }

    private var selectedSection: some View {
        Section {
            HStack {
                Text("已选择")
                Spacer()
                Text("\(selectedNodeNames.count.formattedCount)/\(maxNodeCount.formattedCount)")
                    .foregroundColor(selectionCountColor)
            }

            if !selectedNodeNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedNodes, id: \.name) { node in
                            selectedNodeChip(node)
                        }
                    }
                }
            }
        }
    }

    private var nodeSection: some View {
        Section {
            if nodeManager.nodes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载节点中…")
                    Spacer()
                }
            } else {
                ForEach(filteredNodes) { node in
                    nodeRow(node)
                }
            }
        } header: {
            Text("节点")
        }
    }

    private var selectionCountColor: Color {
        selectedNodeNames.count >= maxNodeCount ? .orange : .secondary
    }

    private func selectedNodeChip(_ node: Node) -> some View {
        Text(node.title ?? node.name)
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private func nodeRow(_ node: Node) -> some View {
        Button {
            toggle(node)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: checkmarkName(for: node))
                    .foregroundColor(checkmarkColor(for: node))

                nodeAvatar(node)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title ?? node.name)
                        .foregroundStyle(.primary)
                    Text(node.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let topics = node.topics, topics > 0 {
                    Text(topics.formattedCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeAvatar(_ node: Node) -> some View {
        Group {
            if let url = nodeAvatarURL(for: node) {
                KFImage(url)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                    }
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func nodeAvatarURL(for node: Node) -> URL? {
        node.getHighestQualityAvatar().flatMap(makeFullNodeURL)
    }

    private func makeFullNodeURL(from path: String) -> URL? {
        SiteConfiguration.makeSiteURL(from: path)
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            return "新建列表"
        case .edit:
            return "编辑列表"
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPersist: Bool {
        !trimmedName.isEmpty && !selectedNodeNames.isEmpty
    }

    private var filteredNodes: [Node] {
        let nodes = nodeManager.nodes.sorted {
            ($0.topics ?? 0) > ($1.topics ?? 0)
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !keyword.isEmpty else { return nodes }

        return nodes.filter { node in
            node.name.lowercased().contains(keyword)
                || (node.title?.lowercased().contains(keyword) ?? false)
        }
    }

    private var selectedNodes: [Node] {
        selectedNodeNames.compactMap { name in
            nodeManager.getNode(name) ?? Node.createVirtual(name: name)
        }
        .sorted { ($0.title ?? $0.name) < ($1.title ?? $1.name) }
    }

    private func toggle(_ node: Node) {
        if selectedNodeNames.contains(node.name) {
            selectedNodeNames.remove(node.name)
        } else if selectedNodeNames.count < maxNodeCount {
            selectedNodeNames.insert(node.name)
        } else {
            showLimitAlert = true
        }
    }

    private func checkmarkName(for node: Node) -> String {
        selectedNodeNames.contains(node.name) ? "checkmark.circle.fill" : "circle"
    }

    private func checkmarkColor(for node: Node) -> Color {
        selectedNodeNames.contains(node.name) ? .accentColor : .secondary
    }

    private func persistChanges() {
        guard canPersist else { return }

        let nodeNames = Array(selectedNodeNames).sorted()
        switch mode {
        case .create:
            if var createdCollection {
                createdCollection.name = trimmedName
                createdCollection.nodeNames = nodeNames
                collectionManager.updateCustomCollection(createdCollection)
                self.createdCollection = createdCollection
            } else {
                createdCollection = collectionManager.addCustomCollection(
                    name: trimmedName,
                    nodeNames: nodeNames
                )
            }
        case .edit(let collection):
            var updated = collection
            updated.name = trimmedName
            updated.nodeNames = nodeNames
            collectionManager.updateCustomCollection(updated)
        }
    }
}
