//
//  FileInfoSheet.swift
//  AccessiblePlus
//
//  Created by lunginspector on 5/20/26.
//

import SwiftUI

import UniformTypeIdentifiers

struct InfoViewer: View {
    @Environment(\.dismiss) var dismiss
    var file: FileItem
    
    init(_ file: FileItem) {
        self.file = file
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    StringInfoCell(file.name, label: "名称")
                    StringInfoCell(file.fileURL.path, label: "路径")
                    if file.type == .symlink {
                        StringInfoCell(file.destURL.path, label: "目标路径")
                    }
                    if file.type == .file {
                        StringInfoCell("\(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))", label: "大小")
                    }
                }
                
                Section {
                    StringInfoCell(file.uttype.identifier, label: "类型标识符 (UTType)")
                    StringInfoCell(file.creationDateStr, label: "创建时间")
                    StringInfoCell(file.modifiedDateStr, label: "修改时间")
                    BoolInfoCell(file.type == .symlink, label: "符号链接")
                } header: {
                    HeaderLabel("文件属性", symbol: "doc")
                }
                
                Section {
                    StringInfoCell(file.posixPerms, label: "POSIX 权限")
                    StringInfoCell(file.owner, label: "所有者")
                    StringInfoCell(file.group, label: "所属组")
                    BoolInfoCell(file.readable, label: "可读")
                    BoolInfoCell(file.writable, label: "可写")
                    BoolInfoCell(file.executable, label: "可执行")
                } header: {
                    HeaderLabel("权限信息", symbol: "shield")
                }
            }
            .navigationTitle("\(file.type.label)简介")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ToolbarLabel("关闭", symbol: "xmark")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private struct StringInfoCell: View {
        var string: String
        var label: String
        
        init(_ string: String, label: String) {
            self.string = string
            self.label = label
        }
        
        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Text(string)
                    .foregroundStyle(.secondary)
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = string
                } label: {
                    Label("复制内容", systemImage: "doc.on.doc")
                }
            }
        }
    }
    
    private struct BoolInfoCell: View {
        var bool: Bool
        var label: String
        
        init(_ bool: Bool, label: String) {
            self.bool = bool
            self.label = label
        }
        
        var body: some View {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: bool ? "checkmark" : "xmark")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
