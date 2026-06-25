//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct MemberView: View {
    @ObservedObject private var userManager: UserManager = .shared
    @Environment(\.dismiss) private var dismiss
    var member: Member?

    var onLogin: (() -> Void)?
    var onLogout: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                MemberDetailView(member: member)

                if let token = userManager.token,
                    let tokenStr = token.token
                {
                    Section("账户安全") {
                        NavigationLink(
                            destination: TokenRenewPage(currentToken: token)
                        ) {
                            ProfileCardRow(
                                systemImage: "key.viewfinder",
                                tint: token.needsRenewalWarning
                                    ? .orange : Color.accentColor,
                                title: "Token 管理",
                                subtitle: maskedToken(tokenStr)
                            ) {
                                if token.needsRenewalWarning {
                                    ProfileStatusBadge(
                                        text: "即将过期",
                                        tint: .orange
                                    )
                                    .accessibilityLabel("Token 即将过期")
                                } else if let remainingDays = token.remainingDays {
                                    Text("剩余 \(remainingDays) 天")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(
                                "复制原始 Token",
                                systemImage: "document.on.document"
                            ) {
                                UIPasteboard.general.string = tokenStr
                            }
                        }
                        .profileListRowCardStyle()
                    }

                    Section {
                        Button(role: .destructive) {
                            onLogout?()
                        } label: {
                            ProfileProminentAction(
                                title: "退出登录",
                                systemImage: "rectangle.portrait.and.arrow.right",
                                tint: .red,
                                filled: false
                            )
                        }
                        .buttonStyle(.plain)
                        .profileListRowCardStyle(top: 10, bottom: 18)
                    }
                } else {
                    Section {
                        Button {
                            onLogin?()
                        } label: {
                            ProfileProminentAction(
                                title: "使用 Token 登录",
                                subtitle: "登录后查看账户资料与 Token 状态",
                                systemImage: "person.crop.circle.badge.plus",
                                tint: Color.accentColor,
                                filled: true
                            )
                        }
                        .buttonStyle(.plain)
                        .profileListRowCardStyle(top: 10, bottom: 18)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .font(.title)
                        }
                    }
                }
            }
        }
    }
}

struct ProfileProminentAction: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let tint: Color
    let filled: Bool
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(filled ? .white : tint)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.semibold)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .opacity(filled ? 0.9 : 0.8)
                }
            }

            Spacer()
        }
        .foregroundStyle(filled ? Color.white : tint)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(filled ? tint : tint.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(filled ? .clear : tint.opacity(0.14), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    let member = Member(
        id: 1111,
        username: "oligi",
        location: "陕西",
        tagline: "NS 巫师3 真好玩",
        bio: "我是一名爱打游戏，爱编程、喜欢打羽毛球的INTP人格",
        created: 1
    )
    MemberView(member: member)
}
