//
//  ModifyItemPage.swift
//  Filos
//
//  Created by lunginspector on 7/25/26.
//

import SwiftUI

struct ModifyItemPage: View {
    @EnvironmentObject private var pmgr: PlistManager
    @Environment(\.dismiss) var dismiss
    
    @State var ogItem: PlistItem = PlistItem(key: "", value: "")
    @Binding var item: PlistItem
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section {
                if isEditing {
                    TextField("键名 (Key)", text: $item.key)
                } else {
                    Text(item.key)
                }
                Picker("类型", selection: $item.type) {
                    ForEach(PlistItemType.allCases, id: \.self) { type in
                        if type != .unknown {
                            Text(type.label).id(type)
                        }
                    }
                }
                .disabled(!isEditing)
            } header: {
                HeaderLabel("属性标识", symbol: "creditcard")
            }
            
            Section {
                switch item.type {
                case .dict, .array:
                    Button("添加子项") {
                        item.dictVal.insert(PlistItem(key: "New Item", value: "", isModified: true), at: 0)
                    }
                    .disabled(!isEditing)
                    ForEach($item.dictVal) { $nestItem in
                        ItemRow(item: $nestItem, hierarchy: 0).environmentObject(pmgr)
                            .disabled(isEditing && nestItem.key == "New Item")
                            .swipeActions {
                                if isEditing {
                                    Button(role: .destructive) {
                                        item.dictVal.removeAll { $0.id == nestItem.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                    }
                case .data:
                    Text(item.stringVal)
                case .bool:
                    Toggle(item.boolVal ? "开启 (True)" : "关闭 (False)", isOn: $item.boolVal)
                        .disabled(!isEditing)
                        .onChange(of: item.boolVal) { newVal in
                            item.stringVal = newVal ? "true" : "false"
                        }
                default:
                    TextField(item.type.label, text: $item.stringVal)
                        .disabled(!isEditing)
                }
            } header: {
                if item.type == .dict || item.type == .array {
                    HeaderLabel("键值 (\(item.dictVal.count) 项)", symbol: "character.cursor.ibeam")
                } else {
                    HeaderLabel("键值", symbol: "character.cursor.ibeam")
                }
            }
            
            if isEditing {
                Button("删除此项", role: .destructive) {
                    let res = pmgr.writePlistItems(delItem: item)
                    if !res {
                        Alertinator.shared.alert(title: "删除 Plist 项目失败！", body: Errors.checkLogs)
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("\(item.key)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .listStyle(.grouped)
        .onAppear {
            Task {
                let plistItem = pmgr.plistArray.first(where: { $0.id == item.id }) ?? item
                ogItem = plistItem
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button {
                        item = ogItem
                        isEditing = false
                    } label: {
                        ToolbarLabel("取消", symbol: "xmark")
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button(role: .adaptiveConfirm) {
                        let res = pmgr.writePlistItems(newItem: item)
                        if res {
                            Haptic.shared.play(.soft)
                        } else {
                            Alertinator.shared.alert(title: "写入 Plist 失败！", body: Errors.checkLogs)
                            item = ogItem
                        }
                        isEditing = false
                    } label: {
                        ToolbarLabel("保存", symbol: "checkmark")
                    }
                } else {
                    if pmgr.isWritable {
                        Button {
                            isEditing = true
                        } label: {
                            ToolbarLabel("编辑", symbol: "pencil")
                        }
                    }
                }
            }
        }
    }
}
