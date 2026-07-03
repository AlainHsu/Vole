//
//  NodeRowView.swift
//  Vole
//
//  Created by 杨权 on 10/19/25.
//

import Kingfisher
import SwiftUI

struct NodeRowView: View {
    let node: Node

    var body: some View {
        HStack {
            // 左侧头像
            if let avatarURL = node.getHighestQualityAvatar(),
                let url = makeFullURL(from: avatarURL)
            {
                KFImage(url)
                    .placeholder {
                        Color.gray
                            .cornerRadius(8)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(node.title ?? node.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(node.displaySubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 构建完整 URL（支持相对路径）
    private func makeFullURL(from path: String) -> URL? {
        SiteConfiguration.makeSiteURL(from: path)
    }
}

#Preview {
    //    if let node = ModelData().topics[0].node {
    //        NodeRowView(node: node)
    //    }
}
