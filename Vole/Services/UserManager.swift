//
//  UserManager.swift
//  Vole
//
//  Created by 杨权 on 9/9/25.
//

import Foundation

class UserManager: ObservableObject {
    static let shared = UserManager()
    private init() {
        // 启动时尝试加载
        self.currentMember = loadMember()
        self.token = KeychainHelper.shared.read()
    }

    @Published var currentMember: Member?
    @Published var token: Token?

    private let memberKey = "currentMember"

    func saveMember(_ member: Member) {
        if let data = try? JSONEncoder().encode(member) {
            UserDefaults.standard.set(data, forKey: memberKey)
            self.currentMember = member
        }
    }

    private func loadMember() -> Member? {
        guard let data = UserDefaults.standard.data(forKey: memberKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Member.self, from: data)
    }

    @discardableResult
    func saveToken(_ token: Token) -> Bool {
        guard KeychainHelper.shared.save(token: token) else { return false }
        self.token = token
        return true
    }

    func refreshTokenDetailsIfNeeded() async {
        guard let token, token.needsDetails, let value = token.token,
            let response = try? await V2exAPI.shared.token(token: value),
            response.success,
            let details = response.result
        else {
            return
        }
        _ = saveToken(token.completed(with: details))
    }

    func renewToken() async throws {
        let response = try await V2exAPI.shared.createToken(
            expiration: Token.renewalExpiration,
            scope: "everything"
        )
        guard let response, response.success,
            let createdToken = response.result,
            let value = createdToken.token
        else {
            throw TokenRenewalError.api(
                response?.message ?? "无法创建新的 Token"
            )
        }

        let details = try? await V2exAPI.shared.token(token: value)?.result
        guard saveToken(createdToken.completed(with: details)) else {
            throw TokenRenewalError.keychain
        }
    }

    func clear() {
        _ = KeychainHelper.shared.delete()
        UserDefaults.standard.removeObject(forKey: memberKey)
        self.token = nil
        self.currentMember = nil
    }
    
    func search(name: String) async throws -> [Member] {
        guard !name.isEmpty else { return [] }
        let keyword = name.lowercased()
        let member = try await V2exAPI.shared.memberShow(username: keyword)
        if let m = member {
            return [m]
        }
        return []
    }
}

private enum TokenRenewalError: LocalizedError {
    case api(String)
    case keychain

    var errorDescription: String? {
        switch self {
        case .api(let message):
            return message
        case .keychain:
            return "新 Token 已创建，但无法保存到 Keychain"
        }
    }
}
