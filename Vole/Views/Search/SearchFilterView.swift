//
//  SearchFilterView.swift
//  Vole
//
//  Created by 杨权 on 12/3/25.
//

import SwiftUI

// 筛选相关的枚举与模型

struct SearchFilterSheet: View {
    @Binding var options: SearchFilterOptions
    var onConfirm: () -> Void
    var onCancel: () -> Void

    // 内部暂存状态，点击确定才应用
    @State private var tempOptions: SearchFilterOptions
    @StateObject private var nodeManager = NodeManager.shared
    @FocusState private var isNodeFieldFocused: Bool

    init(
        options: Binding<SearchFilterOptions>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._options = options
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // 初始化暂存状态
        self._tempOptions = State(initialValue: options.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. 时间筛选
                Section(header: Text("发布时间")) {
                    Picker("时间范围", selection: $tempOptions.timeRange) {
                        ForEach(SearchTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)  // 或者用 .segmented
                }

                // 2. 节点筛选
                Section(header: Text("节点")) {
                    TextField(
                        "输入节点名称 (例如: python)",
                        text: $tempOptions.nodeName
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isNodeFieldFocused)

                    if let selectedNode {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedNode.title ?? selectedNode.name)
                                Text(selectedNode.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if isNodeFieldFocused && !nodeSuggestions.isEmpty {
                        ForEach(nodeSuggestions) { node in
                            Button {
                                tempOptions.nodeName = node.name
                                isNodeFieldFocused = false
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(node.title ?? node.name)
                                            .foregroundStyle(.primary)
                                        Text(node.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if node.name == trimmedNodeName {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !trimmedNodeName.isEmpty && nodeManager.nodes.isEmpty {
                        Text("节点列表加载中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !trimmedNodeName.isEmpty && isNodeFieldFocused {
                        Text("没有找到匹配的节点，仍会按输入的节点名搜索")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 3. 排序方式
                Section(header: Text("排序")) {
                    Picker("排序方式", selection: $tempOptions.sortType) {
                        ForEach(SearchSortType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if nodeManager.nodes.isEmpty {
                    await nodeManager.refreshNodes(force: false)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        // 将暂存状态同步回外部，并触发回调
                        options = tempOptions
                        onConfirm()
                    }
                }
            }
        }
    }

    private var trimmedNodeName: String {
        tempOptions.nodeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedNode: Node? {
        guard !trimmedNodeName.isEmpty else { return nil }
        return nodeManager.getNode(trimmedNodeName)
    }

    private var nodeSuggestions: [Node] {
        guard !trimmedNodeName.isEmpty else { return [] }

        let keyword = trimmedNodeName.lowercased()

        return nodeManager.nodes
            .filter { node in
                node.name.lowercased().contains(keyword)
                    || (node.title?.lowercased().contains(keyword) ?? false)
            }
            .sorted { lhs, rhs in
                let lhsExact = lhs.name.caseInsensitiveCompare(trimmedNodeName)
                    == .orderedSame
                let rhsExact = rhs.name.caseInsensitiveCompare(trimmedNodeName)
                    == .orderedSame

                if lhsExact != rhsExact {
                    return lhsExact
                }

                let lhsStarts = lhs.name.lowercased().hasPrefix(keyword)
                let rhsStarts = rhs.name.lowercased().hasPrefix(keyword)
                if lhsStarts != rhsStarts {
                    return lhsStarts
                }

                return (lhs.topics ?? 0) > (rhs.topics ?? 0)
            }
            .prefix(8)
            .map { $0 }
    }
}

#Preview {
//    SearchFilterSheet()
}
