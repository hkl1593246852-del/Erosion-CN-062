//
//  CacheCleanerView.swift
//  Erosion
//
//  Safe container-level cache & temporary file cleaner for reclaiming bloated iOS "System Data" storage.
//

import SwiftUI

struct ContainerCacheEntry: Identifiable {
    let id: String
    let bundleID: String
    let displayTitle: String
    let containerURL: URL
    var cachesBytes: Int64
    var tmpBytes: Int64
    var isSelected: Bool

    var totalCleanableBytes: Int64 {
        cachesBytes + tmpBytes
    }
}

struct CacheCleanerView: View {
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var entries: [ContainerCacheEntry] = []
    @State private var searchText = ""
    @State private var includeSystemContainers = false
    @AppStorage("totalFreedBytesHistory") private var totalFreedBytesHistory: Int = 0

    private static let protectedBundleIDs: Set<String> = [
        "com.jbdotparty.Erosion",
        "com.apple.PosterBoard",
        "com.apple.springboard",
        "com.apple.Preferences"
    ]

    private var filteredEntries: [ContainerCacheEntry] {
        let base = includeSystemContainers
            ? entries
            : entries.filter { !$0.bundleID.hasPrefix("com.apple.") || $0.bundleID == "com.apple.mobilesafari" }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
            $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var totalReclaimableBytes: Int64 {
        filteredEntries.reduce(0) { $0 + $1.totalCleanableBytes }
    }

    private var selectedReclaimableBytes: Int64 {
        filteredEntries.filter(\.isSelected).reduce(0) { $0 + $1.totalCleanableBytes }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前可安全释放缓存")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(AppContainerDirectoryHelper.formatBytes(totalReclaimableBytes))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(totalReclaimableBytes > 0 ? Color.accentColor : Color.secondary)
                        }
                        Spacer()
                        if totalFreedBytesHistory > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("累计已释放")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(AppContainerDirectoryHelper.formatBytes(Int64(totalFreedBytesHistory)))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Button {
                            scanCaches()
                        } label: {
                            Label("重新扫描", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                        }
                        .disabled(isScanning || isCleaning)

                        Spacer()

                        Button(role: .destructive) {
                            let selectedCount = filteredEntries.filter(\.isSelected).count
                            guard selectedCount > 0 else { return }
                            Alertinator.shared.alert(
                                title: "确认清理所选应用缓存吗？",
                                body: "将清理 \(selectedCount) 个应用容器内的 Library/Caches 与 tmp 临时碎片（预计释放 \(AppContainerDirectoryHelper.formatBytes(selectedReclaimableBytes))）。\n\n安全承诺：绝不触碰 Documents、聊天记录数据库或登录配置。",
                                actionLabel: "立即清理",
                                action: {
                                    cleanSelectedEntries()
                                }
                            )
                        } label: {
                            Label("一键清理已选 (\(AppContainerDirectoryHelper.formatBytes(selectedReclaimableBytes)))", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                        .disabled(isScanning || isCleaning || selectedReclaimableBytes <= 0)
                    }
                }
                .padding(.vertical, 4)

                PlainToggle(
                    "显示系统组件容器 (com.apple.*)",
                    subtitle: "默认包含第三方应用及 Safari 浏览器缓存",
                    isOn: $includeSystemContainers
                )
            } header: {
                HeaderLabel("空间释放概览", symbol: "chart.pie.fill")
            } footer: {
                Text("本工具仅清理各容器下的 Library/Caches、tmp 与 WebKit 网页缓存，保留目录本身与权限，100% 不影响应用聊天记录、账号登录态与用户文档。")
            }

            Section {
                if isScanning || isCleaning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(isCleaning ? "正在安全清理所选容器缓存..." : "正在扫描各应用容器缓存体积...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if filteredEntries.isEmpty {
                    Text("未发现可清理的应用缓存")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredEntries) { entry in
                        HStack(spacing: 12) {
                            Button {
                                toggleSelection(for: entry.id)
                            } label: {
                                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(entry.isSelected ? Color.accentColor : Color.secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.displayTitle)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("Caches: \(AppContainerDirectoryHelper.formatBytes(entry.cachesBytes)) · tmp: \(AppContainerDirectoryHelper.formatBytes(entry.tmpBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(AppContainerDirectoryHelper.formatBytes(entry.totalCleanableBytes))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(entry.totalCleanableBytes > 50 * 1024 * 1024 ? Color.orange : Color.primary)

                                HStack(spacing: 10) {
                                    NavigationLink {
                                        FileBrowserView(path: entry.containerURL.appendingPathComponent("Library/Caches"), shouldGrant: true)
                                    } label: {
                                        Text("查看")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderless)

                                    Button(role: .destructive) {
                                        cleanSingleEntry(entry)
                                    } label: {
                                        Text("清理")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                HStack {
                    HeaderLabel("容器缓存体积排行 (\(filteredEntries.count))", symbol: "trash.slash.fill")
                    Spacer()
                    if !filteredEntries.isEmpty {
                        Button(filteredEntries.allSatisfy(\.isSelected) ? "取消全选" : "全选") {
                            let target = !filteredEntries.allSatisfy(\.isSelected)
                            let visibleIDs = Set(filteredEntries.map(\.id))
                            for idx in entries.indices where visibleIDs.contains(entries[idx].id) {
                                entries[idx].isSelected = target
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("容器缓存清理")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索应用名称或 Bundle ID")
        .onAppear {
            if entries.isEmpty && !isScanning {
                scanCaches()
            }
        }
    }

    private func toggleSelection(for id: String) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].isSelected.toggle()
        }
    }

    private func scanCaches() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let rawPaths = fsHandlers.getDirPaths(FSURL.appContainers.path)
            var result: [ContainerCacheEntry] = []
            let selfBID = Bundle.main.bundleIdentifier ?? "com.jbdotparty.Erosion"

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
                guard !bid.isEmpty, bid != selfBID, !Self.protectedBundleIDs.contains(bid) else { continue }

                let cachesURL = url.appendingPathComponent("Library/Caches")
                let tmpURL = url.appendingPathComponent("tmp")

                let cBytes = AppContainerDirectoryHelper.directorySize(at: cachesURL, maxDepth: 5)
                let tBytes = AppContainerDirectoryHelper.directorySize(at: tmpURL, maxDepth: 4)

                let total = cBytes + tBytes
                guard total > 4096 else { continue }

                result.append(ContainerCacheEntry(
                    id: url.lastPathComponent,
                    bundleID: bid,
                    displayTitle: AppContainerDirectoryHelper.displayName(for: bid),
                    containerURL: url,
                    cachesBytes: cBytes,
                    tmpBytes: tBytes,
                    isSelected: !bid.hasPrefix("com.apple.") && total >= 1024 * 1024
                ))
            }

            result.sort { $0.totalCleanableBytes > $1.totalCleanableBytes }

            DispatchQueue.main.async {
                self.entries = result
                self.isScanning = false
            }
        }
    }

    private func cleanSingleEntry(_ entry: ContainerCacheEntry) {
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let freed = Self.purgeCacheContents(for: entry)
            DispatchQueue.main.async {
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries.remove(at: idx)
                }
                totalFreedBytesHistory += Int(max(freed, 0))
                isCleaning = false
                Haptic.shared.play(.soft)
                Alertinator.shared.alert(
                    title: "清理完成！",
                    body: "已安全清理「\(entry.displayTitle)」缓存，释放空间 \(AppContainerDirectoryHelper.formatBytes(freed))。"
                )
            }
        }
    }

    private func cleanSelectedEntries() {
        let targets = filteredEntries.filter(\.isSelected)
        guard !targets.isEmpty else { return }
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalFreed: Int64 = 0
            var cleanedIDs: Set<String> = []
            for target in targets {
                let freed = Self.purgeCacheContents(for: target)
                totalFreed += freed
                cleanedIDs.insert(target.id)
            }
            DispatchQueue.main.async {
                entries.removeAll { cleanedIDs.contains($0.id) }
                totalFreedBytesHistory += Int(max(totalFreed, 0))
                isCleaning = false
                Haptic.shared.play(.soft)
                Alertinator.shared.alert(
                    title: "批量清理完成！",
                    body: "已成功清理 \(cleanedIDs.count) 个应用的冗余缓存与临时文件，共释放 \(AppContainerDirectoryHelper.formatBytes(totalFreed)) 存储空间！"
                )
            }
        }
    }

    private static func purgeCacheContents(for entry: ContainerCacheEntry) -> Int64 {
        let before = entry.totalCleanableBytes
        let wasActive = wq.hasActiveAccess(path: entry.containerURL.path)
        guard wq.grantAccess(path: entry.containerURL.path).0 else { return 0 }
        defer {
            if !wasActive {
                wq.releaseAccess(path: entry.containerURL.path)
            }
        }

        let dirs = [
            entry.containerURL.appendingPathComponent("Library/Caches"),
            entry.containerURL.appendingPathComponent("tmp"),
            entry.containerURL.appendingPathComponent("Library/WebKit/WebsiteData/CacheStorage")
        ]
        for dir in dirs {
            var dirSt = stat()
            guard lstat(dir.path, &dirSt) == 0, (dirSt.st_mode & S_IFMT) == S_IFDIR else { continue }
            guard let children = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for child in children {
                guard !child.contains("/"), child != ".", child != ".." else { continue }
                let childURL = dir.appendingPathComponent(child)
                var childSt = stat()
                guard lstat(childURL.path, &childSt) == 0 else { continue }
                let mode = childSt.st_mode & S_IFMT
                // Only remove regular files and regular subdirectories; skip sockets/FIFOs/symlinks
                if mode == S_IFREG || mode == S_IFDIR {
                    try? fm.removeItem(at: childURL)
                }
            }
        }
        return before
    }
}
