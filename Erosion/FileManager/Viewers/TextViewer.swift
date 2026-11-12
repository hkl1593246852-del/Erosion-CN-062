//
//  TextViewer.swift
//  Filos
//
//  Created by lunginspector on 5/20/26.
//

import SwiftUI


struct TextViewer: View {
    @EnvironmentObject var mgr: ErosionManager
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("textViewerSize") var textViewerSize = 11
    @AppStorage("useMonospaced") var useMonospaced = true
    
    var fileURL: URL
    
    @State private var file = clearFileItem
    @State private var fileText = ""
    @State private var editText = ""
    @State private var isEditing = false
    
    init(_ fileURL: URL) {
        self.fileURL = fileURL
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    if isEditing {
                        TextEditor(text: $editText)
                            .font(.system(size: CGFloat(textViewerSize), design: useMonospaced ? .monospaced : .default))
                    } else {
                        Text(fileText)
                            .font(.system(size: CGFloat(textViewerSize), design: useMonospaced ? .monospaced : .default))
                            .padding(5)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 100, alignment: .topLeading)
            }
            .navigationTitle(fileURL.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if !file.writable {
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
                    if isEditing {
                        Button {
                            isEditing = false
                            editText = fileText
                        } label: {
                            ToolbarLabel("取消", symbol: "xmark")
                        }
                    }
                    
                    Menu {
                        if file.writable && !isEditing {
                            Button {
                                isEditing = true
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }
                        
                        Button {
                            Haptic.shared.play(.soft)
                            UIPasteboard.general.string = fileText
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            if let url = makeTemp(fileURL) {
                                presentShareSheet(with: url)
                            }
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("菜单", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button(role: .adaptiveConfirm) {
                            let res = writeTextIntoFile(fileURL, string: editText)
                            if res {
                                isEditing = false
                                fileText = getFileText(fileURL)
                            }
                        } label: {
                            ToolbarLabel("保存", symbol: "checkmark")
                        }
                    } else {
                        Button {
                            dismiss()
                            mgr.refreshFiles.toggle()
                        } label: {
                            ToolbarLabel("关闭", symbol: "xmark")
                        }
                    }
                }
            }
            .onAppear {
                file = getFileItem(at: fileURL)
                let text = getFileText(fileURL)
                fileText = text
                editText = text
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func writeTextIntoFile(_ url: URL, string: String) -> Bool {
        if url.lastPathComponent == "com.apple.MobileGestalt.plist" {
            Alertinator.shared.alert(title: "已拦截高危编辑！", body: "禁止使用纯文本编辑器直接覆盖二进制 MobileGestalt 系统缓存文件！")
            return false
        }
        let data = Data(string.utf8)
        let ext = url.pathExtension.lowercased()
        if ext == "plist" {
            guard (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil else {
                Alertinator.shared.alert(title: "Plist 语法校验未通过！", body: "当前编辑的 XML Plist 存在语法错误，安全护栏已拒绝写入以免损坏配置。")
                return false
            }
        } else if ext == "json" {
            guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
                Alertinator.shared.alert(title: "JSON 语法校验未通过！", body: "当前编辑的 JSON 存在语法错误，安全护栏已拒绝写入。")
                return false
            }
        }

        if fm.fileExists(atPath: url.path) {
            // Never fall through to bare non-atomic write on existing files (SEC-M4-03)
            let atomicRes = writeFileAtomically(data, to: url, allowEmpty: string.isEmpty)
            if !atomicRes.0 {
                Alertinator.shared.alert(title: "原位安全保存失败！", body: atomicRes.1)
            }
            return atomicRes.0
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("(fm) failed to write data: \(error.localizedDescription)")
        }
        return false
    }
}
