//
//  FileBrowserView.swift
//  AccessiblePlus
//
//  Created by lunginspector on 5/12/26.
//

import SwiftUI

import QuickLook
import Combine

enum FileSortMode: String, CaseIterable, Codable, Hashable {
    case system, name, date, type, size
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .system: return "默认"
        case .name: return "名称"
        case .date: return "日期"
        case .type: return "类型"
        case .size: return "大小"
        }
    }
}

struct FileBrowserView: View {
    @EnvironmentObject var mgr: ErosionManager
    var path: URL = URL(fileURLWithPath: "/")
    var isContainer = false
    var shouldGrant = false
    
    @State private var dirFiles: [FileItem] = []
    @State private var unfilteredFiles: [FileItem] = []
    @State private var searchText = ""
    @AppStorage("maxInode") var maxInode = 15000000
    @AppStorage("chosenSort") var chosenSort: FileSortMode = .system
    @AppStorage("filesAscend") var filesAscend = true
    @AppStorage("listStyle") var listStyle = 1
    @AppStorage("hideDates") var hideDates = false
    @AppStorage("textViewerSize") var textViewerSize = 10
    @AppStorage("useMonospaced") var useMonospaced = true
    
    @State private var showFileImporter = false
    @State private var showFailure = false
    @State private var failMsg = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            ProgressView()
                                .offset(y: 0.5)
                            Text("正在加载文件...")
                                .fontWeight(.medium)
                        }
                        if isContainer {
                            Text("由于容器路径扫描耗时较长，首次加载可能需要 30 秒以上，请耐心等待。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if showFailure {
                CompactAlert(title: "无法加载目录文件！", symbol: "folder.badge.questionmark", text: failMsg)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } else {
                ForEach(dirFiles) { file in
                    if file.type == .folder {
                        FolderRow(file: file, shouldGrant: isContainer ? true : false, isContainer: isContainer)
                    } else {
                        FileRow(file: file)
                    }
                }
            }
        }
        .navigationTitle(path.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .customListStyle(listStyle)
        .adaptiveListMargin()
        .searchable(text: $searchText, prompt: "搜索文件或 Bundle ID")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(FileSortMode.allCases, id: \.self) { option in
                        Button {
                            chosenSort = option
                        } label: {
                            if chosenSort == option {
                                Label(option.label, systemImage: "checkmark")
                                    .tag(option)
                            } else {
                                Text(option.label)
                                    .tag(option)
                            }
                        }
                    }
                    Divider()
                    Button {
                        filesAscend.toggle()
                    } label: {
                        if filesAscend {
                            Label("升序", systemImage: "chevron.up")
                        } else {
                            Label("降序", systemImage: "chevron.down")
                        }
                    }
                    .disabled(chosenSort == .system)
                } label: {
                    Label("排序", systemImage: "line.3.horizontal.decrease")
                }
                .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !isContainer {
                        Menu {
                            Button {
                                Alertinator.shared.prompt(title: "请输入新文件名称（请附带文件扩展名）：", placeholder: "new.txt", completion: { name in
                                    let name = name ?? ""
                                    if !name.isEmpty {
                                        do {
                                            let fileURL = path.appendingPathComponent(name)
                                            try Data().write(to: fileURL)
                                            mgr.refreshFiles.toggle()
                                        } catch {
                                            print("(fm) failed to create file: \(error.localizedDescription)")
                                            Alertinator.shared.alert(title: "新建文件失败！", body: Errors.checkLogs)
                                        }
                                    }
                                })
                            } label: {
                                Label("文件", systemImage: "doc")
                            }
                            
                            Button {
                                Alertinator.shared.prompt(title: "请输入新建 Plist 属性列表名称：", placeholder: "配置名称", completion: { name in
                                    let name = name ?? ""
                                    if !name.isEmpty {
                                        do {
                                            let fileURL = path.appendingPathComponent(name + ".plist")
                                            let data = try PropertyListSerialization.data(fromPropertyList: NSMutableDictionary(), format: .xml, options: 0)
                                            try data.write(to: fileURL)
                                            mgr.refreshFiles.toggle()
                                        } catch {
                                            print("(fm) failed to create plist: \(error.localizedDescription)")
                                            Alertinator.shared.alert(title: "新建 Plist 失败！", body: Errors.checkLogs)
                                        }
                                    }
                                })
                            } label: {
                                Label("属性列表 (Plist)", systemImage: "tablecells")
                            }
                            
                            Button {
                                Alertinator.shared.prompt(title: "请输入新建文件夹名称：", placeholder: "新建文件夹", completion: { name in
                                    let name = name ?? ""
                                    if !name.isEmpty {
                                        do {
                                            try fm.createDirectoryIfNeeded(at: path.appendingPathComponent(name))
                                            mgr.refreshFiles.toggle()
                                        } catch {
                                            print("(fm) failed to create folder: \(error.localizedDescription)")
                                            Alertinator.shared.alert(title: "新建文件夹失败！", body: Errors.checkLogs)
                                        }
                                    }
                                })
                            } label: {
                                Label("文件夹", systemImage: "folder")
                            }
                            
                            Button {
                                Alertinator.shared.prompt(title: "请输入符号链接指向的目标路径：", placeholder: "/path/to/dir", completion: { symPath in
                                    let symPath = symPath ?? ""
                                    if !symPath.isEmpty {
                                        do {
                                            try fm.createSymbolicLink(atPath: path.appendingPathComponent(URL(fileURLWithPath: symPath).lastPathComponent).path, withDestinationPath: symPath)
                                            mgr.refreshFiles.toggle()
                                        } catch {
                                            print("(fm) failed to create symlink: \(error.localizedDescription)")
                                            Alertinator.shared.alert(title: "创建符号链接失败！", body: "\(error.localizedDescription)")
                                        }
                                    }
                                })
                            } label: {
                                Label("符号链接 (Symlink)", systemImage: "arrow.up.right.circle")
                            }
                        } label: {
                            Label("新建...", systemImage: "plus")
                        }
                        
                        Button {
                            showFileImporter.toggle()
                        } label: {
                            Label("导入文件", systemImage: "arrow.down.doc")
                        }
                        Divider()
                    }
                    NavigationLink {
                        FileBrowserView(path: URL.documentsDirectory)
                    } label: {
                        Label("打开应用文档目录", systemImage: "folder")
                    }
                    NavigationLink {
                        List {
                            Section {
                                HStack {
                                    Text("最大 Inode 扫描上限")
                                    TextField("15000000", value: $maxInode, format: .number)
                                        .multilineTextAlignment(.trailing)
                                }
                            } header: {
                                HeaderLabel("容器路径扫描", symbol: "externaldrive")
                            } footer: {
                                Text("控制扫描容器目录时的最大 Inode 范围。数值越小扫描越快，但可能遗漏高 Inode 容器（建议设为 15000000）。")
                            }
                            
                            Section {
                                Picker("列表样式", selection: $listStyle) {
                                    Text("默认").tag(1)
                                    Text("平铺").tag(2)
                                    Text("分组").tag(3)
                                }
                                Toggle("隐藏修改日期", isOn: $hideDates)
                            } header: {
                                HeaderLabel("显示选项", symbol: "eye")
                            }
                            
                            Section {
                                Stepper(value: $textViewerSize) {
                                    HStack {
                                        Text("字号大小")
                                        Spacer()
                                        Text(textViewerSize.description)
                                    }
                                }
                                Toggle("等宽字体", isOn: $useMonospaced)
                            } header: {
                                HeaderLabel("文本查看器", symbol: "doc.plaintext")
                            }
                        }
                        .navigationTitle("文件浏览设置")
                    } label: {
                        Label("浏览设置", systemImage: "gearshape")
                    }
                } label: {
                    Label("操作", systemImage: "ellipsis")
                }
                .labelStyle(.iconOnly)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            handleImport(result)
        }
        .refreshable {
            mgr.refreshFiles.toggle()
        }
        .onAppear {
            if !mgr.storedFiles.isEmpty && mgr.storedURL == path {
                let sorted = sortFiles(files: mgr.storedFiles)
                unfilteredFiles = sorted
                dirFiles = filterFiles(sorted, query: searchText)
            } else if isContainer && hasLoaded {
                // do nothing as it's already being stored in the variable
            } else {
                if shouldGrant {
                    let res = wq.grantAccess(path: path.path)
                    if res.0 {
                        loadFilesFromPath()
                    } else {
                        showFailure = true
                        failMsg = "无权访问该目录。"
                    }
                } else {
                    loadFilesFromPath()
                }
            }
        }
        .onChange(of: searchText) { _, newSearch in
            dirFiles = filterFiles(unfilteredFiles, query: newSearch)
        }
        .onChange(of: chosenSort) {
            loadFilesFromPath()
        }
        .onChange(of: filesAscend) {
            loadFilesFromPath()
        }
        .onChange(of: mgr.refreshFiles) {
            loadFilesFromPath()
        }
    }
    
    private func filterFiles(_ files: [FileItem], query: String) -> [FileItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return files }
        return files.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.fileURL.lastPathComponent.localizedCaseInsensitiveContains(trimmed)
        }
    }
    
    // MARK: handle files
    private func loadFilesFromPath() {
        isLoading = true
        let currentMaxInode = Int64(maxInode)
        let currentPath = path
        let containerMode = isContainer
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var unsortedFiles: [FileItem] = []
                if containerMode {
                    let paths = fsHandlers.getDirPaths(currentPath.path, maxInode: currentMaxInode)
                    for p in paths {
                        unsortedFiles.append(getFileItem(at: URL(fileURLWithPath: p), isContainer: true))
                    }
                } else {
                    let pathFiles = try fm.contentsOfDirectory(at: currentPath, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
                    
                    unsortedFiles = pathFiles.map { fileURL in
                        if currentPath == FSURL.appGroup || currentPath == FSURL.systemData {
                            return getFileItem(at: fileURL, isContainer: true)
                        } else {
                            return getFileItem(at: fileURL)
                        }
                    }
                }
                DispatchQueue.main.async {
                    let sorted = sortFiles(files: unsortedFiles)
                    unfilteredFiles = sorted
                    dirFiles = filterFiles(sorted, query: searchText)
                    if containerMode {
                        mgr.storedFiles = unsortedFiles
                        mgr.storedURL = currentPath
                    }
                    hasLoaded = true
                    isLoading = false
                }
            } catch {
                print("(fm) failed to load files from \(currentPath): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    showFailure = true
                    failMsg = "你可能没有查看此目录的权限，请前往主页查看运行日志了解详情。"
                    isLoading = false
                }
            }
        }
    }
    
    private func sortFiles(files: [FileItem]) -> [FileItem] {
        var sortedFiles: [FileItem]
        
        switch chosenSort {
        case .system:
            sortedFiles = files
        case .name:
            sortedFiles = files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            sortedFiles = files.sorted { $0.modifiedDate > $1.modifiedDate }
        case .type:
            sortedFiles = files.sorted { $0.type.sortOrder < $1.type.sortOrder }
        case .size:
            sortedFiles = files.sorted { $0.size < $1.size }
        }

        sortedFiles = filesAscend ? sortedFiles : sortedFiles.reversed()
        sortedFiles = sortedFiles.sorted { a, b in
            a.hidden && !b.hidden
        }
        return sortedFiles
    }
    
    // MARK: handle import
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let fileURL):
            do {
                let stopAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if stopAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: fileURL)
                
                let newURL = path.appendingPathComponent(fileURL.lastPathComponent)
                try? fm.removeItem(at: newURL)
                
                try data.write(to: newURL)
                mgr.refreshFiles.toggle()
            } catch {
                print("(fm) failed to import file: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "导入文件失败！", body: "\(error.localizedDescription)")
            }
        case .failure(let error):
            print("(fm) failed to import file: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "导入文件失败！", body: "\(error.localizedDescription)")
        }
    }
}

// MARK: user interface
extension View {
    @ViewBuilder
    func customListStyle(_ selection: Int) -> some View {
        switch selection {
        case 2: self.listStyle(.inset)
        case 3: self.listStyle(.grouped)
        default: self.listStyle(.insetGrouped)
        }
    }
    
    @ViewBuilder
    func adaptiveListMargin() -> some View {
        if #available(iOS 26.0, *) {
            self.contentMargins(.top, 1)
        }
    }
}

struct KeyboardDismissObserver: ViewModifier {
    var action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(Publishers.keyboardDismissed) { _ in
                action()
            }
    }
}

extension Publishers {
    static var keyboardDismissed: AnyPublisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardDidHideNotification)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
