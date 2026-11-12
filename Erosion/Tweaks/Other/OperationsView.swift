//
//  OperationsView.swift
//  Erosion
//
//  Created by lunginspector on 8/17/26.
//

import SwiftUI
import UniformTypeIdentifiers


struct OperationsView: View {
    @State private var directory = ""
    @State private var fileName = ""
    @State private var isAcc = false
    @State private var showImporter = false
    
    @State private var imprtName = ""
    @State private var imprtData = Data()
    
    var body: some View {
        List {
            Section {
                TextField("目标目录路径（如 /var/...）", text: $directory)
                    .disabled(isAcc)
                TextField("目标文件名", text: $fileName)
                    .disabled(isAcc)
                HStack {
                    Button("获取读写权限") {
                        let res = wq.grantAccess(path: "\(directory)/\(fileName)")
                        if !res.0 {
                            Alertinator.shared.alert(title: "获取目标文件权限失败！", body: "\(res.1): \(res.2)")
                        } else {
                            isAcc = true
                        }
                    }
                    .disabled(isAcc)
                    if isAcc {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark")
                            Text("已授权")
                        }
                        .foregroundStyle(.green)
                    }
                }
                if isAcc {
                    Button("更改目标路径", role: .destructive) {
                        isAcc = false
                        imprtName = ""
                        imprtData = Data()
                    }
                    
                    Button("导出原文件") {
                        let fileDir = "\(directory)/\(fileName)"
                        presentShareSheet(with: URL(fileURLWithPath: fileDir))
                    }
                }
            } header: {
                HeaderLabel("目标文件", symbol: "dot.scope")
            }
            
            Section {
                HStack {
                    Button("导入替换文件") {
                        showImporter = true
                    }
                    .disabled(!imprtData.isEmpty)
                    if !imprtName.isEmpty {
                        Spacer()
                        Text(imprtName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Button("覆盖目标文件") {
                    let targetURL = URL(fileURLWithPath: "\(directory)/\(fileName)").standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "已拦截高危系统路径覆盖！", body: blockReason)
                        return
                    }
                    do {
                        Self.backupBeforeMutation(targetURL)
                        if fm.fileExists(atPath: targetURL.path) {
                            let atomicRes = writeFileAtomically(imprtData, to: targetURL)
                            if !atomicRes.0 {
                                throw atomicRes.1
                            }
                        } else {
                            try imprtData.write(to: targetURL, options: .atomic)
                        }
                        print("(ov) successfully overwrote file: \(targetURL.path) (\(imprtData.count))")
                        Haptic.shared.play(.soft)
                    } catch {
                        print("(ov) failed to overwrite: \(error.localizedDescription)")
                        Alertinator.shared.alert(title: "覆盖文件失败！", body: "\(error.localizedDescription)")
                    }
                }
                .disabled(imprtData.isEmpty)
                
                Button("写入到目标目录") {
                    let targetURL = URL(fileURLWithPath: "\(directory)").appendingPathComponent(imprtName).standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "已拦截高危系统路径写入！", body: blockReason)
                        return
                    }
                    do {
                        Self.backupBeforeMutation(targetURL)
                        if fm.fileExists(atPath: targetURL.path) {
                            let atomicRes = writeFileAtomically(imprtData, to: targetURL)
                            if !atomicRes.0 {
                                throw atomicRes.1
                            }
                        } else {
                            try imprtData.write(to: targetURL, options: .atomic)
                        }
                        print("(ov) successfully moved file: \(imprtName) -> \(targetURL.path)")
                        Haptic.shared.play(.soft)
                    } catch {
                        print("(ov) failed to move: \(error.localizedDescription)")
                        Alertinator.shared.alert(title: "写入文件失败！", body: "\(error.localizedDescription)")
                    }
                }
                .disabled(imprtData.isEmpty)
                
                Button("删除目标文件", role: .destructive) {
                    let targetURL = URL(fileURLWithPath: "\(directory)/\(fileName)").standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "已拦截高危系统文件删除！", body: blockReason)
                        return
                    }
                    Alertinator.shared.alert(
                        title: "确认删除目标文件？",
                        body: "删除前将自动在应用文档目录保存时间戳备份：\n\(targetURL.path)",
                        actionLabel: "确认删除",
                        action: {
                            do {
                                Self.backupBeforeMutation(targetURL)
                                try fm.removeItem(at: targetURL)
                                print("(ov) successfully deleted file: \(targetURL.path)")
                                Haptic.shared.play(.heavy)
                            } catch {
                                print("(ov) failed to delete: \(error.localizedDescription)")
                                Alertinator.shared.alert(title: "删除文件失败！", body: "\(error.localizedDescription)")
                            }
                        }
                    )
                }
                .disabled(!isAcc)
            } header: {
                HeaderLabel("文件操作", symbol: "wrench.and.screwdriver")
            }
        }
        .navigationTitle("任意文件替换")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            handleImport(result)
        }
    }
    
    func handleImport(_ res: Result<URL, Error>) {
        switch res {
        case .success(let recURL):
            do {
                let stopAccess = recURL.startAccessingSecurityScopedResource()
                defer {
                    if stopAccess {
                        recURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                imprtData = try Data(contentsOf: recURL)
                imprtName = recURL.lastPathComponent
            } catch {
                print("(ov) failed to import file: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "导入文件失败！", body: "该文件可能无效、已损坏或无法访问，请更换其他替换文件重试。")
            }
        case .failure(let error):
            print("(ov) failed to import file: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "导入文件失败！", body: "该文件可能无效、已损坏或无法访问，请更换其他替换文件重试。")
        }
    }

    private static func blockedSystemPathReason(for url: URL) -> String? {
        let p = url.standardizedFileURL.path
        let lower = p.lowercased()
        let exactNames: Set<String> = [
            "com.apple.mobilegestalt.plist",
            "cloudconfigurationdetails.plist",
            "keychain-2.db",
            "truststore.sqlite3"
        ]
        if exactNames.contains(url.lastPathComponent.lowercased()) {
            return "文件 \(url.lastPathComponent) 属于核心系统安全/引导配置，严禁在“任意文件替换”中裸写或删除（请使用专用模块或安全菜单操作）。"
        }
        let forbiddenPrefixes = [
            "/system", "/private/preboot", "/usr", "/bin", "/sbin", "/dev",
            "/var/keychains", "/private/var/keychains", "/var/db", "/private/var/db"
        ]
        for pre in forbiddenPrefixes where lower == pre || lower.hasPrefix(pre + "/") {
            return "路径 \(p) 位于系统核心保护区，防白苹果安全护栏已禁止直接覆写或删除。"
        }
        return nil
    }

    private static func backupBeforeMutation(_ url: URL) {
        guard fm.fileExists(atPath: url.path) else { return }
        let backupDir = URL.documentsDirectory.appendingPathComponent("OperationBackups")
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        mgExcludeFromCloudBackup(backupDir)
        let stamp = Int(Date().timeIntervalSince1970)
        let backupURL = backupDir.appendingPathComponent("\(stamp)_\(url.lastPathComponent).bak")
        try? fm.copyItem(at: url, to: backupURL)
        mgExcludeFromCloudBackup(backupURL)
    }
}
