import StoreKit
import SwiftUI

struct SettingView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("appTheme") private var selectedTheme: AppTheme = .blue

    @State private var showStore = false
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var siteConfigurationStore = SiteConfigurationStore.shared

    private var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
        let build =
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private let appID = "6756212194"
    private let contactEmail = "quark.yeung@icloud.com"

    private var appStoreURL: URL? {
        URL(string: "itms-apps://apps.apple.com/app/id\(appID)")
    }

    private var contactURL: URL? {
        URL(
            string: "mailto:\(contactEmail)?subject=App反馈&body=你好，我想反馈"
                .addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? ""
        )
    }

    private var discordURL: URL {
        URL(string: "https://discord.gg/4vnEBzrW3d")!
    }

    private var projectURL: URL {
        URL(string: "https://github.com/YangQuan666/Vole")!
    }

    private var selectedSiteHost: String {
        URL(string: siteConfigurationStore.selectedBaseURL)?.host
            ?? siteConfigurationStore.selectedBaseURL
    }

    private var savedSiteSummary: String {
        "已保存 \(siteConfigurationStore.baseURLs.count) 个站点"
    }

    var body: some View {
        List {
            Section("偏好设置") {
                themeRow

                NavigationLink {
                    HomeNodeListSettingsView()
                } label: {
                    SettingRow(
                        systemImage: "list.bullet.rectangle.portrait",
                        tint: .orange,
                        title: "首页列表",
                        subtitle: "管理首页展示的节点列表"
                    )
                }

                NavigationLink {
                    SiteBaseURLSettingsView(store: siteConfigurationStore)
                } label: {
                    SettingRow(
                        systemImage: "network",
                        tint: .green,
                        title: "站点地址",
                        subtitle: savedSiteSummary
                    ) {
                        Text(selectedSiteHost)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section("支持与反馈") {
                Button {
                    showStore = true
                } label: {
                    SettingRow(
                        systemImage: "cup.and.heat.waves",
                        tint: .orange,
                        title: "请我喝咖啡",
                        subtitle: "为爱发电，感谢支持"
                    ) {
                        Text("支持一下")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    guard let contactURL else { return }
                    openURL(contactURL)
                } label: {
                    SettingRow(
                        systemImage: "envelope",
                        tint: .blue,
                        title: "联系我们",
                        subtitle: contactEmail
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)

                Link(destination: discordURL) {
                    SettingRow(
                        systemImage: "bubble.left.and.exclamationmark.bubble.right",
                        tint: .indigo,
                        title: "问题反馈",
                        subtitle: "加入 Discord 社区"
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)
            }

            Section("关于项目") {
                Button {
                    guard let appStoreURL else { return }
                    openURL(appStoreURL)
                } label: {
                    SettingRow(
                        systemImage: "info.circle",
                        tint: .gray,
                        title: "版本号",
                        subtitle: "查看 App Store 页面"
                    ) {
                        Text(appVersion)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Link(destination: projectURL) {
                    SettingRow(
                        systemImage: "folder",
                        tint: .brown,
                        title: "项目地址",
                        subtitle: "YangQuan666/Vole"
                    ) {
                        SettingExternalAccessory()
                    }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LicenseContentView()
                } label: {
                    SettingRow(
                        systemImage: "doc.text",
                        tint: .teal,
                        title: "许可协议",
                        subtitle: "查看项目 License"
                    )
                }

                NavigationLink {
                    OpenSourceListView()
                } label: {
                    SettingRow(
                        systemImage: "square.stack.3d.up",
                        tint: .mint,
                        title: "开源软件声明",
                        subtitle: "查看第三方依赖与来源"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "选择金额",
            isPresented: $showStore,
            titleVisibility: .visible
        ) {
            ForEach(storeManager.products, id: \.id) { product in
                Button("\(product.displayName) - \(product.displayPrice)") {
                    Task {
                        let success = await storeManager.purchase(product)
                        if success {
                            print("购买成功，可以更新本地余额或显示提示")
                        } else {
                            print("购买失败或取消")
                        }
                    }
                }
            }
        }
        .task {
            await storeManager.loadProducts()
        }
    }

    private var themeRow: some View {
        SettingRow(
            systemImage: "paintpalette",
            tint: selectedTheme.color,
            title: "主题色",
            subtitle: "点击切换 App 的强调色"
        ) {
            Picker("主题色", selection: $selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue)
                        .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(selectedTheme.color)
        }
    }
}

private struct SettingRow<Accessory: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    init(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            SettingRowIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            accessory()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct SettingRowIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }
}

private struct ThemeValuePill: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.color)
                .frame(width: 8, height: 8)

            Text(theme.rawValue)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(theme.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.color.opacity(0.12))
        )
    }
}

private struct SettingExternalAccessory: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

struct SiteBaseURLSettingsView: View {
    @ObservedObject var store: SiteConfigurationStore
    @State private var isAddSheetPresented = false

    var body: some View {
        List {
            Section {
                ForEach(
                    Array(store.baseURLs.enumerated()),
                    id: \.element
                ) { _, baseURL in
                    Button {
                        store.select(baseURL)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(baseURL)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                if baseURL.caseInsensitiveCompare(
                                    SiteConfiguration.defaultBaseURL
                                ) == .orderedSame {
                                    Text("默认站点")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if baseURL.caseInsensitiveCompare(
                                store.selectedBaseURL
                            ) == .orderedSame {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if store.canDelete(baseURL) {
                            Button(role: .destructive) {
                                store.remove(baseURL)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("已保存站点")
            } footer: {
                Text("点击任意地址即可切换。左滑可删除，至少会保留一个地址。")
            }
        }
        .navigationTitle("站点地址")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            AddSiteBaseURLSheet(store: store)
        }
    }
}

private struct AddSiteBaseURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SiteConfigurationStore

    @State private var input = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入站点地址", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Base URL")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("支持直接输入域名，未带协议时会自动补成 https://。")
                    }
                }
            }
            .navigationTitle("添加站点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        do {
            try store.add(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 主应用许可协议内容视图
struct LicenseContentView: View {
    @State private var licenseText: String = "加载中..."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(licenseText)
                    .font(.system(.caption, design: .monospaced))  // 使用等宽字体展示协议文本
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("许可协议")
        .onAppear {
            loadLicenseFile()
        }
    }

    private func loadLicenseFile() {
        // 1. 尝试读取名为 "License" 的文件
        if let url = Bundle.main.url(
            forResource: "LICENSE",
            withExtension: ""
        ) {
            do {
                licenseText = try String(contentsOf: url, encoding: .utf8)
            } catch {
                licenseText =
                    "无法加载项目许可协议文件 (License.txt)。错误: \(error.localizedDescription)"
                print("Error loading License.txt file: \(error)")
            }
        }
        // 2. 最终未找到文件
        else {
            licenseText =
                "未找到名为 'License.txt', 'LICENSE.txt' 或 'License' 的项目许可协议文件。请确保文件已添加到 Bundle 资源中。"
        }
    }
}

// 开源软件列表视图
struct OpenSourceListView: View {
    // 状态变量的类型为 OpenSourceItem
    @State private var items: [OpenSourceItem] = []

    var body: some View {
        List {
            // 使用 Link 打开外部 URL
            ForEach(items) { item in
                Link(
                    destination: URL(string: item.url) ?? URL(
                        string: "about:blank"
                    )!
                ) {
                    HStack {
                        Text(item.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "link")  // 外部链接图标
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("开源声明")
        .onAppear {
            loadOpenSourceProjects()
        }
    }

    // MARK: - 加载 JSON 逻辑
    private func loadOpenSourceProjects() {
        // 尝试从 Bundle 中查找 opensource.json 文件
        guard
            let url = Bundle.main.url(
                forResource: "opensource",
                withExtension: "json"
            )
        else {
            print("Error: opensource.json file not found in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            // 使用 JSONDecoder 解析数据，类型为 OpenSourceItem
            let decodedItems = try JSONDecoder().decode(
                [OpenSourceItem].self,
                from: data
            )
            self.items = decodedItems
        } catch {
            print("Error decoding or loading opensource.json: \(error)")
        }
    }
}

struct OpenSourceItem: Identifiable, Codable {
    // 使用 name 作为 id
    var id: String { name }
    let name: String
    let url: String
}

// 预览
#Preview {
    NavigationView {
        SettingView()
    }
}
