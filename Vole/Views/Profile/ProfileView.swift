//
//  ProfileView.swift
//  Vole
//
//  Created by 杨权 on 9/8/25.
//

import Kingfisher
import SwiftUI

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
    @Binding var token: String
    var onValidate: (String) async throws -> Token  // 校验 Token，返回过期时间
    var onLogin: (String) async throws -> Void  // 登录

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var tokenExpiry: Int?  // 校验通过后保存过期时间
    @State private var loginFailed = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            VStack(spacing: 12) {
                Text("使用 Token 登录")
                    .font(.largeTitle)
                    .bold()
                Text("以更加安全的方式访问你账户中的数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 60)

            Spacer()

            // 输入区域
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    TextField("请输入 Token", text: $token)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 30)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 34)
                    }

                    // 校验通过显示过期时间
                    if let expiry = tokenExpiry {
                        Text("你的 Token 有效期剩余 \(expiry) 天")
                            .font(.footnote)
                            .foregroundColor(.green)
                            .padding(.horizontal, 34)
                    }
                }

                // 获取 token 提示
                Label {
                    Text(
                        "如何免费获取 [Personal Access Token](https://www.v2ex.com/help/personal-access-token)（用于登录）"
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }

            Spacer()

            // 底部按钮
            Button(action: handleAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .white)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                } else {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .background(
                (token.isEmpty || isLoading)
                    ? Color.gray.opacity(0.3) : Color.accentColor
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .disabled(token.isEmpty || isLoading)

            Spacer()
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    // 按钮文字根据状态变化
    private var buttonTitle: String {
        if loginFailed {
            return "重试"
        } else if tokenExpiry != nil {
            return "下一步"
        } else {
            return "校验 Token"
        }
    }

    private func handleAction() {
        errorMessage = nil
        isLoading = true
        loginFailed = false

        Task {
            do {
                if tokenExpiry == nil {
                    // 第一步：校验 Token
                    let t = try await onValidate(token)
                    await MainActor.run {
                        tokenExpiry = t.goodForDays
                        isLoading = false
                    }
                } else {
                    // 第二步：登录
                    try await onLogin(token)
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    loginFailed = true
                }
            }
        }
    }

    private func formattedExpiry(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct TokenRenewPage: View {
    private let initialToken: Token
    @ObservedObject private var userManager: UserManager = .shared
    @State private var isRenewing = false
    @State private var activeAlert: TokenAlert?

    init(currentToken: Token) {
        initialToken = currentToken
    }

    var body: some View {
        List {
            Section {
                if let token = currentToken.token {
                    HStack {
                        Text("Token")
                        Spacer(minLength: 12)
                        Text(token)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .contextMenu {
                                Button(
                                    "复制原始 Token",
                                    systemImage: "document.on.document"
                                ) {
                                    UIPasteboard.general.string = token
                                }
                            }
                    }
                }
                if let created = currentToken.created {
                    LabeledContent(
                        "创建时间",
                        value: formatDate(created)
                    )
                }
                if let lastUsed = currentToken.lastUsed {
                    LabeledContent(
                        "上次使用时间",
                        value: formatDate(lastUsed)
                    )
                }
                if let expiration = currentToken.expiration {
                    LabeledContent(
                        "有效期",
                        value: "\(expiration / 86_400) 天"
                    )
                }
                if let remainingDays = currentToken.remainingDays {
                    LabeledContent("剩余天数") {
                        Text("\(remainingDays) 天")
                            .foregroundStyle(
                                remainingDays <= 0
                                    ? .red
                                    : currentToken.needsRenewalWarning
                                        ? .orange : .secondary
                            )
                            .fontWeight(
                                currentToken.needsRenewalWarning
                                    ? .semibold : .regular
                            )
                    }
                }
            }

            Section {
                Button {
                    activeAlert = .confirmation
                } label: {
                    HStack {
                        Spacer()
                        if isRenewing {
                            ProgressView()
                        } else {
                            Label("续期 Token", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isRenewing)
            } footer: {
                Text("将创建一个有效期 180 天、拥有 everything 权限的新 Token，并替换当前设备保存的 Token。")
            }
        }
        .navigationTitle("Token 详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $activeAlert) { alert in
            alert.content(renew: renewToken)
        }
        .task {
            await userManager.refreshTokenDetailsIfNeeded()
        }
    }

    private var currentToken: Token {
        userManager.token ?? initialToken
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
