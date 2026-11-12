//
//  PlistViewer.swift
//  Filos
//
//  Created by lunginspector on 7/25/26.
//

import SwiftUI

struct PlistViewer: View {
    @StateObject private var pmgr = PlistManager.shared
    @Environment(\.dismiss) var dismiss
    var fileURL: URL
    
    @State private var file = clearFileItem
    @State private var showErrorView = false
    
    init(_ fileURL: URL) {
        self.fileURL = fileURL
    }
    
    var body: some View {
        NavigationView {
            List {
                if showErrorView {
                    PlainAlert(title: "加载 Plist 失败！", symbol: "exclamationmark.triangle.fill", text: Errors.checkLogs, color: .yellow)
                } else {
                    ForEach($pmgr.plistArray) { $item in
                        ItemRow(item: $item, hierarchy: 0)
                            .environmentObject(pmgr)
                    }
                }
            }
            .navigationTitle(file.fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.inset)
            .safeAreaInset(edge: .bottom) {
                if !pmgr.isWritable {
                    HStack {
                        Spacer()
                        Button {
                            Alertinator.shared.alert(title: "只读文件", body: "当前没有写入权限，仅支持读取此文件。")
                        } label: {
                            Image(systemName: "lock")
                                .padding(10)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.trailing)
                        .ignoresSafeArea()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let url = makeTemp(file.fileURL) {
                            presentShareSheet(with: url)
                        }
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ToolbarLabel("关闭", symbol: "xmark")
                    }
                }
            }
        }
        .onAppear {
            pmgr.url = fileURL
            file = getFileItem(at: fileURL)
            let res = pmgr.loadPlistItems()
            if !res {
                showErrorView = true
            }
            pmgr.isWritable = file.writable
        }
        .navigationViewStyle(.stack)
    }
}

// no comment.
extension UIColor {
    static func hierarchyLevelColor(_ level: Int = 0) -> UIColor {
        UIColor { trait in
            let isDark = (trait.userInterfaceStyle == .dark)
            let baseColor = isDark ? UIColor.secondarySystemBackground.resolvedColor(with: trait) : UIColor.white.resolvedColor(with: trait)
            
            let clampedLevel = max(0, level)
            var factor = max(0, 1 - 0.03 * CGFloat(clampedLevel))
            if isDark {
                factor = max(0, 1 + 0.24 * CGFloat(clampedLevel))
            }

            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            if baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
                let newBrightness = max(0, min(1, b * factor))
                return UIColor(hue: h, saturation: s, brightness: newBrightness, alpha: a)
            }

            var r: CGFloat = 0
            var g: CGFloat = 0
            var bl: CGFloat = 0

            guard baseColor.getRed(&r, green: &g, blue: &bl, alpha: &a) else {
                return baseColor
            }

            return UIColor(red: max(0, r * factor), green: max(0, g * factor), blue: max(0, bl * factor), alpha: a)
        }
    }
}
