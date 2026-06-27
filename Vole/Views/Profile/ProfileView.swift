//
//  ProfileView.swift
//  Vole
//
//  Created by 杨权 on 9/8/25.
//

import Kingfisher
import SwiftUI
import UIKit

struct ProfileView: View {
    @State private var inputToken: String = ""
    @State private var showLogin = false
    @StateObject private var userManager = UserManager.shared

    var body: some View {
        MemberView(
            member: userManager.currentMember,
            onLogin: {
                inputToken = ""
                showLogin = true
            },
            onLogout: {
                logout()
            }
        )
        .sheet(isPresented: $showLogin) {
            TokenInputPage(
                token: $inputToken,
                onValidate: validateToken,
                onLogin: { token in
                    try await loginWithToken(token)
                    await MainActor.run {
                        showLogin = false
                        inputToken = ""
                    }
                }
            )
        }
        // 2. 将异步检查和静默登录逻辑放在 .task 修饰符中
        // 当 View 出现在屏幕上时，如果已有 Token 但没有用户信息，则自动刷新
        .task {
            await checkAndRefreshUser()
        }
    }

    // 把 init 里的逻辑抽离成这个方法
    func checkAndRefreshUser() async {
        // 检查是否需要静默登录：有 Token 但内存中没有 Member 数据
        if let t = UserManager.shared.token,
            let token = t.token,
            userManager.currentMember == nil
        {

            print("🔄 检测到 Token，正在尝试静默登录...")
            do {
                try await loginWithToken(token)
                print("✅ 静默登录成功")
            } catch {
                print("❌ 静默登录失败：", error)
                // 可选：如果 Token 失效了，可以在这里退回到步骤 2
                // withAnimation { step = 2 }
            }
        }
    }
    
    // 第一步：校验 Token 有效性
    func validateToken(_ token: String) async throws -> Token {
        let response = try await V2exAPI.shared.token(token: token)
        if let r = response, let validatedToken = r.result, r.success {
            let persistedToken = validatedToken.withRawToken(token)
            userManager.saveToken(persistedToken)
            return persistedToken
        } else {
            throw NSError(
                domain: "TokenError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: response?.message ?? "Token校验失败"
                ]
            )
        }
    }

    // 第二步：登录
    func loginWithToken(_ token: String) async throws {
        let response = try await V2exAPI.shared.member(token: token)
        if let r = response, let memeber = r.result, r.success {
            userManager.saveMember(memeber)
            print(memeber)
        } else {
            throw NSError(
                domain: "LoginError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "登录失败，请稍后重试"
                ]
            )
        }
    }

    private func logout() {
        userManager.clear()
    }
}

struct TokenInputPage: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var token: String
    var onValidate: (String) async throws -> Token
    var onLogin: (String) async throws -> Void  // 登录

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var validatedToken: Token?
    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    loginHeaderCard
                    tokenFieldCard

                    helpCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Token 登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .interactiveDismissDisabled(isLoading)
        }
        .onChange(of: token) { oldValue, newValue in
            guard oldValue != newValue else { return }
            validatedToken = nil
            errorMessage = nil
        }
    }

    private var buttonTitle: String {
        if validatedToken != nil {
            return errorMessage == nil ? "登录并同步资料" : "重试登录"
        } else {
            return errorMessage == nil ? "校验 Token" : "重新校验"
        }
    }

    private var buttonSubtitle: String {
        validatedToken == nil
            ? "先验证有效期与权限，再继续登录"
            : "同步你的账户资料并完成登录"
    }

    private var buttonIcon: String {
        validatedToken == nil ? "checkmark.shield" : "person.badge.key"
    }

    private var sanitizedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tokenFieldTint: Color {
        if errorMessage != nil {
            return .red
        }
        if validatedToken != nil {
            return .green
        }
        return Color.accentColor
    }

    private var loginHeaderCard: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 78, height: 78)
                .overlay {
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(spacing: 8) {
                Text("使用 Token 登录")
                    .font(.title2.weight(.bold))

                Text("以更安全的方式访问你的账户数据，整个流程会先校验 Token，再同步账户资料。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProfileStatusBadge(
                text: validatedToken == nil ? "第一步：校验 Token" : "第二步：登录账户",
                tint: validatedToken == nil ? Color.accentColor : .green
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.18),
                            Color(.secondarySystemGroupedBackground),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
        }
    }

    private var tokenFieldCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Access Token")
                .font(.headline)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tokenFieldTint.opacity(0.14))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "key")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tokenFieldTint)
                    }

                TextField("请输入 Token", text: $token)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                    .focused($isTokenFieldFocused)

                if token.isEmpty {
                    Button("粘贴") {
                        token = UIPasteboard.general.string ?? ""
                        isTokenFieldFocused = false
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                } else {
                    Button {
                        token = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                    }
                }
            }

            if errorMessage == nil && validatedToken == nil {
                Text("输入后点击下方按钮校验 Token。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            tokenFeedbackBanner
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tokenFieldTint.opacity(errorMessage == nil && validatedToken == nil ? 0.08 : 0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var tokenFeedbackBanner: some View {
        if let errorMessage {
            tokenFeedbackRow(
                title: "操作失败",
                message: errorMessage,
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
        } else if let validatedToken {
            tokenFeedbackRow(
                title: "校验通过",
                message: validationMessage(for: validatedToken),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        }
    }

    private func tokenFeedbackRow(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private var helpCard: some View {
        Link(destination: URL(string: "https://www.v2ex.com/help/personal-access-token")!) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("如何免费获取 Personal Access Token")
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.leading)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.35)

            Button(action: handleAction) {
                ProfileProminentAction(
                    title: buttonTitle,
                    subtitle: buttonSubtitle,
                    systemImage: buttonIcon,
                    tint: Color.accentColor,
                    filled: true,
                    isLoading: isLoading
                )
            }
            .buttonStyle(.plain)
            .disabled(sanitizedToken.isEmpty || isLoading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func validationMessage(for token: Token) -> String {
        if let days = token.goodForDays {
            return "你的 Token 有效期剩余 \(days) 天，已经可以继续登录。"
        }
        return "Token 可用，已经可以继续登录。"
    }

    private func handleAction() {
        let candidate = sanitizedToken
        guard !candidate.isEmpty else { return }

        if candidate != token {
            token = candidate
        }

        errorMessage = nil
        isLoading = true
        isTokenFieldFocused = false

        Task {
            do {
                if validatedToken == nil {
                    let validated = try await onValidate(candidate)
                    await MainActor.run {
                        validatedToken = validated
                        isLoading = false
                    }
                } else {
                    try await onLogin(candidate)
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct TokenRenewPage: View {
    private let initialToken: Token
    @ObservedObject private var userManager: UserManager = .shared
    @State private var isRenewing = false
    @State private var activeAlert: TokenAlert?
    @State private var didCopyToken = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    init(currentToken: Token) {
        initialToken = currentToken
    }

    var body: some View {
        List {
            Section {
                tokenOverviewCard
                    .profileListRowCardStyle(top: 12, bottom: 8)
            }

            let items = tokenInfoItems
            if !items.isEmpty {
                Section("详情") {
                    tokenInfoPanel(items)
                        .profileListRowCardStyle()
                }
            }

            Section {
                renewalPanel
                    .profileListRowCardStyle(top: 10, bottom: 18)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Token 管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $activeAlert) { alert in
            alert.content(renew: renewToken)
        }
        .task {
            await userManager.refreshTokenDetailsIfNeeded()
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
    }

    private var currentToken: Token {
        userManager.token ?? initialToken
    }

    private var statusTint: Color {
        if let remainingDays = currentToken.remainingDays {
            if remainingDays <= 0 {
                return .red
            }
            if currentToken.needsRenewalWarning {
                return .orange
            }
            return Color.accentColor
        }
        return Color.accentColor
    }

    private var renewTint: Color {
        .green
    }

    private var statusText: String {
        if let remainingDays = currentToken.remainingDays {
            if remainingDays <= 0 {
                return "已过期"
            }
            return currentToken.needsRenewalWarning ? "即将过期" : "正常"
        }
        return "待同步"
    }

    private var statusDescription: String {
        if let remainingDays = currentToken.remainingDays {
            return "当前 Token 还剩 \(remainingDays) 天有效期。"
        }
        return "详细信息会在同步完成后显示。"
    }

    private var tokenOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(statusTint.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "key.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(statusTint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Token 状态")
                        .font(.headline)
                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                ProfileStatusBadge(text: statusText, tint: statusTint)
            }

            if let token = currentToken.token {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前凭证")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(maskedToken(token))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyToken(token)
                    } label: {
                        ZStack {
                            Image(systemName: "document.on.document")
                                .foregroundStyle(.secondary)
                                .opacity(didCopyToken ? 0 : 1)
                                .scaleEffect(didCopyToken ? 0.86 : 1)

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .opacity(didCopyToken ? 1 : 0)
                                .scaleEffect(didCopyToken ? 1 : 0.86)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(didCopyToken ? "已复制原始 Token" : "复制原始 Token")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            statusTint.opacity(0.16),
                            Color(.secondarySystemGroupedBackground),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(statusTint.opacity(0.10), lineWidth: 1)
        }
    }

    private func copyToken(_ token: String) {
        UIPasteboard.general.string = token
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        copyFeedbackTask?.cancel()
        withAnimation(.smooth(duration: 0.20)) {
            didCopyToken = true
        }

        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.smooth(duration: 0.22)) {
                didCopyToken = false
            }
        }
    }

    private var renewalPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                activeAlert = .confirmation
            } label: {
                ProfileProminentAction(
                    title: "续期 Token",
                    systemImage: "arrow.clockwise",
                    tint: renewTint,
                    filled: true,
                    isLoading: isRenewing
                )
            }
            .buttonStyle(.plain)
            .disabled(isRenewing)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                Text("续期说明：将创建一个有效期 180 天、拥有 everything 权限的新 Token，并替换当前设备保存的 Token。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }

    private func tokenInfoPanel(_ items: [TokenInfoItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                tokenInfoRow(item)

                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private func tokenInfoRow(_ item: TokenInfoItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(item.tint.opacity(0.13))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.tint)
                }

            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(item.value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var tokenInfoItems: [TokenInfoItem] {
        var items: [TokenInfoItem] = []

        if let created = currentToken.created {
            items.append(
                TokenInfoItem(
                    id: "created",
                    title: "创建时间",
                    systemImage: "calendar",
                    tint: .indigo,
                    value: formatDate(created)
                )
            )
        }

        if let lastUsed = currentToken.lastUsed {
            items.append(
                TokenInfoItem(
                    id: "last-used",
                    title: "上次使用时间",
                    systemImage: "clock.arrow.circlepath",
                    tint: .teal,
                    value: formatDate(lastUsed)
                )
            )
        }

        if let expiration = currentToken.expiration {
            items.append(
                TokenInfoItem(
                    id: "expiration",
                    title: "有效期",
                    systemImage: "hourglass",
                    tint: .blue,
                    value: "\(expiration / 86_400) 天"
                )
            )
        }

        if let remainingDays = currentToken.remainingDays {
            items.append(
                TokenInfoItem(
                    id: "remaining-days",
                    title: "剩余天数",
                    systemImage: "timer",
                    tint: statusTint,
                    value: "\(remainingDays) 天"
                )
            )
        }

        if let totalUsed = currentToken.totalUsed {
            items.append(
                TokenInfoItem(
                    id: "total-used",
                    title: "累计使用次数",
                    systemImage: "chart.bar",
                    tint: .green,
                    value: "\(totalUsed)"
                )
            )
        }

        if let scope = currentToken.scope, !scope.isEmpty {
            items.append(
                TokenInfoItem(
                    id: "scope",
                    title: "权限范围",
                    systemImage: "lock.shield",
                    tint: .orange,
                    value: scope
                )
            )
        }

        return items
    }

    private func renewToken() {
        isRenewing = true

        Task {
            do {
                try await userManager.renewToken()
                activeAlert = .success
            } catch {
                activeAlert = .failure(error.localizedDescription)
            }
            isRenewing = false
        }
    }
}

private struct TokenInfoItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let value: String
}

private enum TokenAlert: Identifiable {
    case confirmation
    case success
    case failure(String)

    var id: String {
        switch self {
        case .confirmation: return "confirmation"
        case .success: return "success"
        case .failure: return "failure"
        }
    }

    func content(renew: @escaping () -> Void) -> Alert {
        switch self {
        case .confirmation:
            return Alert(
                title: Text("确认续期 Token？"),
                message: Text("将创建一个有效期 180 天的新 Token，并替换当前设备保存的 Token。"),
                primaryButton: .destructive(
                    Text("创建并替换 Token"),
                    action: renew
                ),
                secondaryButton: .cancel()
            )
        case .success:
            return Alert(
                title: Text("续期成功"),
                message: Text("新 Token 已保存并立即生效。"),
                dismissButton: .default(Text("好"))
            )
        case .failure(let message):
            return Alert(
                title: Text("续期失败"),
                message: Text(message),
                dismissButton: .default(Text("好"))
            )
        }
    }
}

func maskedToken(_ token: String) -> String {
    guard token.count > 8 else { return token }  // 不足8位直接返回原始token
    let start = token.prefix(4)
    let end = token.suffix(4)
    return "\(start)****\(end)"
}

func formatDate(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"  // 年-月-日
    return formatter.string(from: date)
}

#Preview {
    let token = Token(
        token: "1298312381209381290381029",
        scope: "",
        expiration: 2_592_000,
        goodForDays: 3,
        totalUsed: 1,
        lastUsed: 1,
        created: 1
    )
    TokenRenewPage(currentToken: token)
}
