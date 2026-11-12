//
//  AppDataBackupView.swift
//  Erosion
//
//  Third-party App & Game save backup, restore, and direct Plist/JSON editor launcher.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

enum AppContainerDirectoryHelper {
    static let knownAppNames: [String: String] = [
        "com.tencent.xin": "微信",
        "com.tencent.mqq": "QQ",
        "com.ss.iphone.ugc.Aweme": "抖音",
        "tv.danmaku.bilianime": "哔哩哔哩",
        "com.xingin.discover": "小红书",
        "com.taobao.taobao4iphone": "淘宝",
        "com.alipay.iphoneclient": "支付宝",
        "com.jingdong.app.mall": "京东",
        "com.meituan.imeituan": "美团",
        "com.netease.cloudmusic": "网易云音乐",
        "com.tencent.QQMusic": "QQ音乐",
        "com.zhihu.ios": "知乎",
        "com.sina.weibo": "微博",
        "com.baidu.BaiduMobile": "百度",
        "com.autonavi.amap": "高德地图",
        "com.tencent.smoba": "王者荣耀",
        "com.tencent.tmgp.pubgmhd": "和平精英",
        "com.tencent.jkchess": "金铲铲之战",
        "com.miHoYo.Yuanshen": "原神",
        "com.miHoYo.GenshinImpact": "原神 (国际服)",
        "com.miHoYo.hkrpg": "崩坏：星穹铁道",
        "com.miHoYo.Nap": "绝区零",
        "com.hypergryph.arknights": "明日方舟",
        "com.chucklefish.stardewvalley": "星露谷物语",
        "com.and.games505.TerrariaPaid": "泰拉瑞亚",
        "com.mojang.minecraftpe": "我的世界 (Minecraft)",
        "com.popcap.ios.PvZ2": "植物大战僵尸 2",
        "com.SoulGame.SoulKnight": "元气骑士",
        "com.locojoy.balatro": "小丑牌 (Balatro)",
        "com.NSSurge.inc.surge-ios": "Surge",
        "com.luo.quantumult-x": "Quantumult X",
        "com.liguangming.Shadowrocket": "Shadowrocket",
        "org.telegram.Telegram-iOS": "Telegram",
        "com.burbn.instagram": "Instagram",
        "com.atebits.Tweetie2": "X (Twitter)",
        "com.google.ios.youtube": "YouTube",
        "com.openai.chat": "ChatGPT",
        "com.apple.mobilesafari": "Safari 浏览器",
        "com.apple.Music": "Apple 音乐",
        "com.apple.DocumentsApp": "文件"
    ]

    static func displayName(for bundleID: String) -> String {
        if let known = knownAppNames[bundleID] {
            return "\(known) (\(bundleID))"
        }
        return bundleID
    }

    static func directorySize(at url: URL, maxDepth: Int = 6, currentDepth: Int = 0) -> Int64 {
        guard currentDepth <= maxDepth else { return 0 }
        guard let names = try? fm.contentsOfDirectory(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        for name in names {
            let childPath = (url.path as NSString).appendingPathComponent(name)
            var st = stat()
            if lstat(childPath, &st) == 0 {
                let mode = st.st_mode & S_IFMT
                if mode == S_IFREG {
                    total += Int64(st.st_size)
                } else if mode == S_IFDIR {
                    total += directorySize(at: URL(fileURLWithPath: childPath), maxDepth: maxDepth, currentDepth: currentDepth + 1)
                }
            }
        }
        return total
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(bytes, 0))
    }
}

struct AppSaveContainerItem: Identifiable {
    let id: String
    let bundleID: String
    let displayTitle: String
    let containerURL: URL
    let saveDataSize: Int64
}

struct LocalSaveBackupItem: Identifiable {
    let id: String
    let fileURL: URL
    let bundleID: String
    let createdAt: Date
    let fileSize: Int64
}

struct AppDataBackupView: View {
    @State private var isScanning = false
    @State private var scanProgressText = "正在扫描本机应用数据容器..."
    @State private var containers: [AppSaveContainerItem] = []
    @State private var backups: [LocalSaveBackupItem] = []
    @State private var searchText = ""
    @State private var includeSystemApps = false
    @State private var showBackupImporter = false

    private static let backupsRootURL = URL.documentsDirectory.appendingPathComponent("AppDataBackups")

    private var filteredContainers: [AppSaveContainerItem] {
        let base = includeSystemApps
            ? containers
            : containers.filter { !$0.bundleID.hasPrefix("com.apple.") }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
            $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        showBackupImporter = true
                    } label: {
                        Label("导入外部备份包 (.zip)", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                    Button {
                        scanAllContainers()
                    } label: {
                        Label("刷新列表", systemImage: "arrow.clockwise")
                    }
                    .disabled(isScanning)
                }
                PlainToggle(
                    "显示系统内置应用容器 (com.apple.*)",
                    subtitle: "默认仅展示第三方应用与游戏容器",
                    isOn: $includeSystemApps
                )
            } header: {
                HeaderLabel("备份与筛选控制", symbol: "slider.horizontal.3")
            }

            if !backups.isEmpty {
                Section {
                    ForEach(backups) { backup in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(AppContainerDirectoryHelper.displayName(for: backup.bundleID))
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(AppContainerDirectoryHelper.formatBytes(backup.fileSize))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(backup.fileURL.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            HStack(spacing: 14) {
                                Button {
                                    Alertinator.shared.alert(
                                        title: "确定还原此存档备份吗？",
                                        body: "将把 \(backup.fileURL.lastPathComponent) 中的 Documents 与 Preferences 存档还原至「\(backup.bundleID)」当前容器（自动匹配重装后的最新容器 UUID）。还原前请先在后台关闭目标应用！",
                                        actionLabel: "确认还原",
                                        action: {
                                            restoreBackup(backup)
                                        }
                                    )
                                } label: {
                                    Label("一键还原", systemImage: "arrow.uturn.backward.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    presentShareSheet(with: backup.fileURL)
                                } label: {
                                    Label("导出分享", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                Spacer()

                                Button(role: .destructive) {
                                    deleteBackup(backup)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    HeaderLabel("本地已保存的存档备份 (\(backups.count))", symbol: "archivebox.fill")
                } footer: {
                    Text("即使卸载重装了游戏或应用导致容器 UUID 改变，点击“一键还原”也会按 Bundle ID 自动定位当前最新容器并原位写回存档。")
                }
            }

            Section {
                if isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(scanProgressText)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if filteredContainers.isEmpty {
                    Text("未找到匹配的应用数据容器")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredContainers) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.displayTitle)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(AppContainerDirectoryHelper.formatBytes(item.saveDataSize))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("容器 UUID: \(item.containerURL.lastPathComponent)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 14) {
                                Button {
                                    backupContainer(item)
                                } label: {
                                    Label("备份存档", systemImage: "externaldrive.badge.plus")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                NavigationLink {
                                    FileBrowserView(path: item.containerURL.appendingPathComponent("Documents"), shouldGrant: true)
                                } label: {
                                    Label("修改 Documents", systemImage: "folder.badge.gearshape")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                NavigationLink {
                                    FileBrowserView(path: item.containerURL.appendingPathComponent("Library/Preferences"), shouldGrant: true)
                                } label: {
                                    Label("修改配置 Plist", systemImage: "doc.text.magnifyingglass")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                HeaderLabel("应用与游戏存档列表 (\(filteredContainers.count))", symbol: "gamecontroller.fill")
            } footer: {
                Text("点击“备份存档”会将该应用的 Documents 与 Library/Preferences 打包为 ZIP；点击“修改 Documents”或“修改配置 Plist”可直接调用内置无损 Plist/文本编辑器修改游戏数值或配置。")
            }
        }
        .navigationTitle("应用与游戏存档管理")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索应用名称或 Bundle ID")
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.zip, .item]) { result in
            handleImportBackup(result)
        }
        .onAppear {
            loadLocalBackups()
            if containers.isEmpty && !isScanning {
                scanAllContainers()
            }
        }
    }

    private func ensureBackupDir() {
        try? fm.createDirectory(at: Self.backupsRootURL, withIntermediateDirectories: true)
        mgExcludeFromCloudBackup(Self.backupsRootURL)
    }

    private func loadLocalBackups() {
        ensureBackupDir()
        guard let urls = try? fm.contentsOfDirectory(
            at: Self.backupsRootURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ) else {
            return
        }
        var items: [LocalSaveBackupItem] = []
        for url in urls where url.pathExtension.lowercased() == "zip" {
            let baseName = url.deletingPathExtension().lastPathComponent
            let bundleID: String
            if let range = baseName.range(of: "__", options: .backwards) {
                bundleID = String(baseName[..<range.lowerBound])
            } else {
                bundleID = baseName
            }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date()
            items.append(LocalSaveBackupItem(
                id: url.lastPathComponent,
                fileURL: url,
                bundleID: bundleID,
                createdAt: date,
                fileSize: size
            ))
        }
        items.sort { $0.createdAt > $1.createdAt }
        backups = items
    }

    private static let protectedSystemBundleIDs: Set<String> = [
        "com.jbdotparty.Erosion",
        "com.apple.springboard",
        "com.apple.PosterBoard",
        "com.apple.Preferences"
    ]

    private func scanAllContainers() {
        isScanning = true
        scanProgressText = "正在扫描本机应用数据容器..."
        DispatchQueue.global(qos: .userInitiated).async {
            let rawPaths = fsHandlers.getDirPaths(FSURL.appContainers.path)
            var discovered: [AppSaveContainerItem] = []
            for rawPath in rawPaths {
                let url = URL(fileURLWithPath: rawPath)
                let wasActive = wq.hasActiveAccess(path: url.path)
                guard wq.grantAccess(path: url.path).0 else { continue }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: url.path)
                    }
                }

                var buf = [CChar](repeating: 0, count: 512)
                let len = getxattr(url.path, "com.apple.containermanager.identifier", &buf, 511, 0, XATTR_NOFOLLOW)
                guard len > 0 else { continue }
                let bid = String(cString: buf)
                guard !bid.isEmpty, !Self.protectedSystemBundleIDs.contains(bid) else { continue }

                let docsURL = url.appendingPathComponent("Documents")
                let prefsURL = url.appendingPathComponent("Library/Preferences")
                let docsSize = AppContainerDirectoryHelper.directorySize(at: docsURL, maxDepth: 4)
                let prefsSize = AppContainerDirectoryHelper.directorySize(at: prefsURL, maxDepth: 2)

                discovered.append(AppSaveContainerItem(
                    id: url.lastPathComponent,
                    bundleID: bid,
                    displayTitle: AppContainerDirectoryHelper.displayName(for: bid),
                    containerURL: url,
                    saveDataSize: docsSize + prefsSize
                ))
            }

            discovered.sort {
                if $0.saveDataSize != $1.saveDataSize {
                    return $0.saveDataSize > $1.saveDataSize
                }
                return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.containers = discovered
                self.isScanning = false
            }
        }
    }

    private func backupContainer(_ item: AppSaveContainerItem) {
        ensureBackupDir()
        DispatchQueue.global(qos: .userInitiated).async {
            let stagingDir = fm.temporaryDirectory.appendingPathComponent("SaveBackup_\(UUID().uuidString)")
            defer { try? fm.removeItem(at: stagingDir) }

            do {
                try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                let wasActive = wq.hasActiveAccess(path: item.containerURL.path)
                guard wq.grantAccess(path: item.containerURL.path).0 else {
                    throw "无法获取该应用容器的读取权限"
                }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: item.containerURL.path)
                    }
                }

                let docsSrc = item.containerURL.appendingPathComponent("Documents")
                let prefsSrc = item.containerURL.appendingPathComponent("Library/Preferences")

                if fm.fileExists(atPath: docsSrc.path) {
                    try? fm.copyItem(at: docsSrc, to: stagingDir.appendingPathComponent("Documents"))
                }
                if fm.fileExists(atPath: prefsSrc.path) {
                    let libDest = stagingDir.appendingPathComponent("Library")
                    try fm.createDirectory(at: libDest, withIntermediateDirectories: true)
                    try? fm.copyItem(at: prefsSrc, to: libDest.appendingPathComponent("Preferences"))
                }

                let meta: [String: String] = [
                    "bundleID": item.bundleID,
                    "createdAt": ISO8601DateFormatter().string(from: Date())
                ]
                if let metaData = try? PropertyListSerialization.data(fromPropertyList: meta, format: .xml, options: 0) {
                    try? metaData.write(to: stagingDir.appendingPathComponent("BackupManifest.plist"))
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let zipName = "\(item.bundleID)__\(formatter.string(from: Date())).zip"
                let zipURL = Self.backupsRootURL.appendingPathComponent(zipName)
                if fm.fileExists(atPath: zipURL.path) {
                    try? fm.removeItem(at: zipURL)
                }

                try fm.zipItem(at: stagingDir, to: zipURL, shouldKeepParent: false)
                mgExcludeFromCloudBackup(zipURL)

                DispatchQueue.main.async {
                    loadLocalBackups()
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "存档备份成功！",
                        body: "已生成备份文件：\(zipName)\n你可在上方“本地已保存的存档备份”中随时一键还原或导出分享。"
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    Alertinator.shared.alert(title: "备份存档失败！", body: error.localizedDescription)
                }
            }
        }
    }

    private func restoreBackup(_ backup: LocalSaveBackupItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            let extractDir = fm.temporaryDirectory.appendingPathComponent("RestoreSave_\(UUID().uuidString)")
            defer { try? fm.removeItem(at: extractDir) }

            do {
                try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
                try fm.unzipItem(at: backup.fileURL, to: extractDir)

                var resolvedBundleID = backup.bundleID
                let manifestURL = extractDir.appendingPathComponent("BackupManifest.plist")
                if let mData = try? Data(contentsOf: manifestURL),
                   let mDict = try? PropertyListSerialization.propertyList(from: mData, options: [], format: nil) as? [String: Any],
                   let mBID = mDict["bundleID"] as? String, !mBID.isEmpty {
                    resolvedBundleID = mBID
                }

                guard !Self.protectedSystemBundleIDs.contains(resolvedBundleID) else {
                    DispatchQueue.main.async {
                        Alertinator.shared.alert(title: "安全护栏拦截！", body: "禁止向受保护的核心系统容器还原外部备份包。")
                    }
                    return
                }

                let targetContainerPath: String
                if let matched = containers.first(where: { $0.bundleID == resolvedBundleID }) {
                    targetContainerPath = matched.containerURL.path
                } else {
                    targetContainerPath = fsHandlers.getContainerPath(forMatch: resolvedBundleID)
                }

                guard !targetContainerPath.isEmpty else {
                    DispatchQueue.main.async {
                        Alertinator.shared.alert(
                            title: "未找到目标应用容器！",
                            body: "本机当前未检测到「\(resolvedBundleID)」的数据容器，请先安装并至少打开一次该应用后再试。"
                        )
                    }
                    return
                }

                let containerURL = URL(fileURLWithPath: targetContainerPath)
                let wasActive = wq.hasActiveAccess(path: containerURL.path)
                guard wq.grantAccess(path: containerURL.path).0 else {
                    throw "无法获取目标容器的写入权限"
                }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: containerURL.path)
                    }
                }

                var restoredFiles = 0
                let docsExtract = extractDir.appendingPathComponent("Documents")
                if fm.fileExists(atPath: docsExtract.path) {
                    let docsTarget = containerURL.appendingPathComponent("Documents")
                    restoredFiles += Self.mergeDirectoryInPlace(from: docsExtract, to: docsTarget)
                }

                let prefsExtract = extractDir.appendingPathComponent("Library/Preferences")
                if fm.fileExists(atPath: prefsExtract.path) {
                    let prefsTarget = containerURL.appendingPathComponent("Library/Preferences")
                    restoredFiles += Self.mergeDirectoryInPlace(from: prefsExtract, to: prefsTarget)
                }

                DispatchQueue.main.async {
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "存档还原完成！",
                        body: "已成功将 \(restoredFiles) 个存档/配置文件原位还原至「\(resolvedBundleID)」容器。"
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    Alertinator.shared.alert(title: "还原存档失败！", body: error.localizedDescription)
                }
            }
        }
    }

    private static func mergeDirectoryInPlace(from srcDir: URL, to dstDir: URL) -> Int {
        try? fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
        guard let names = try? fm.contentsOfDirectory(atPath: srcDir.path) else { return 0 }
        var count = 0
        for name in names {
            guard !name.contains("/"), name != ".", name != ".." else { continue }
            let srcURL = srcDir.appendingPathComponent(name)
            let dstURL = dstDir.appendingPathComponent(name)
            var st = stat()
            guard lstat(srcURL.path, &st) == 0 else { continue }
            let mode = st.st_mode & S_IFMT
            if mode == S_IFDIR {
                count += mergeDirectoryInPlace(from: srcURL, to: dstURL)
            } else if mode == S_IFREG, let data = try? Data(contentsOf: srcURL) {
                var dstSt = stat()
                if lstat(dstURL.path, &dstSt) == 0 {
                    // Never overwrite a symlink in destination
                    guard (dstSt.st_mode & S_IFMT) == S_IFREG else { continue }
                    if writeFileAtomically(data, to: dstURL, allowEmpty: true).0 {
                        count += 1
                    }
                } else {
                    if writeFileTemp(data, to: dstURL).0 {
                        count += 1
                    }
                }
            }
        }
        return count
    }

    private func deleteBackup(_ backup: LocalSaveBackupItem) {
        try? fm.removeItem(at: backup.fileURL)
        loadLocalBackups()
    }

    private func handleImportBackup(_ result: Result<URL, Error>) {
        ensureBackupDir()
        switch result {
        case .success(let url):
            let stopAccess = url.startAccessingSecurityScopedResource()
            defer {
                if stopAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let destURL = Self.backupsRootURL.appendingPathComponent(url.lastPathComponent)
            try? fm.removeItem(at: destURL)
            do {
                try fm.copyItem(at: url, to: destURL)
                mgExcludeFromCloudBackup(destURL)
                loadLocalBackups()
                Haptic.shared.play(.soft)
            } catch {
                Alertinator.shared.alert(title: "导入备份包失败！", body: error.localizedDescription)
            }
        case .failure(let error):
            Alertinator.shared.alert(title: "导入备份包失败！", body: error.localizedDescription)
        }
    }
}
