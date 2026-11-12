//
//  PosterBoardView.swift
//  Erosion
//
//  Created by lunginspector on 8/19/26.
//

import SwiftUI

import UniformTypeIdentifiers

let pbHandler = PBHandler()

enum PBMsg {
    static var noTendies = "点击此处或底部按钮导入 .tendies 壁纸包，即可开始应用自定义锁屏壁纸。"
    static var tooManyTendies = "单次最多只能同时启用 15 张壁纸，请先取消勾选其他壁纸包后再试！"
    static var limitWarning = "你当前勾选了超过 5 张壁纸，可能导致部分壁纸无法正常显示。确定仍要继续应用吗？"
    static var corruption = "请确认所选壁纸包未损坏后重试。"
    static var finishApply = "点击继续后将自动打开 PosterBoard，请在后台多任务切换器中将其上滑关闭以完成加载。如果壁纸未显示，请在右上角“壁纸设置”中尝试重置“壁纸合集”、“水星壁纸”或“视频壁纸”。"
    static var applyInfo = "如果打开锁屏编辑后未看到导入的壁纸，请前往右上角菜单的“壁纸设置”中点击“重置壁纸合集 (Collections)”后再试。"
    static var imprtFailed = "请确认所选文件为有效的 .tendies 壁纸包后重试。"
}

struct PosterBoardView: View {
    @AppStorage("pbContainerPath") private var pbContainerPath = ""
    @State private var isReady = false
    @AppStorage("tendiesArray") private var tendiesArray: [TendiesObject] = []
    @AppStorage("hasShownFirstRunMsg") private var hasShownFirstRunMsg = false
    
    @State private var showImporter = false
    let columns = Array(repeating: GridItem(.flexible()), count: device.userInterfaceIdiom == .pad ? 4 : 2)
    
    var body: some View {
        Group {
            if !isReady {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.25)
                    Text("正在定位系统容器路径...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    if tendiesArray.isEmpty {
                        Button {
                            showImporter = true
                        } label: {
                            VStack(alignment: .leading) {
                                CompactAlert(title: "尚未导入壁纸包", symbol: "exclamationmark.triangle.fill", text: PBMsg.noTendies)
                                    .padding(.horizontal, 15)
                            }
                            .frame(alignment: .leading)
                            .multilineTextAlignment(.leading)
                        }
                    }
                    LazyVGrid(columns: columns) {
                        ForEach($tendiesArray) { $tendies in
                            Button {
                                if !tendies.isOn && tendiesArray.filter({ $0.isOn }).flatMap({ $0.descrNames }).count > 15 {
                                    Alertinator.shared.alert(title: "已达壁纸数量上限！", body: PBMsg.tooManyTendies)
                                } else {
                                    tendies.isOn.toggle()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: tendies.targetDescr == .photos ? "play.rectangle" : "photo")
                                        .imageScale(.large)
                                        .foregroundStyle(Color.accentColor)
                                    VStack {
                                        Text(tendies.name)
                                            .lineLimit(1)
                                            .fontWeight(.medium)
                                        Text("共 \(tendies.descrNames.count) 张壁纸")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .padding(.vertical, 10)
                                .background {
                                    if tendies.targetDescr == .mercury {
                                        VStack {
                                            Text("M")
                                                .font(.footnote)
                                                .padding(6)
                                                .background(Color.accentColor)
                                                .clipShape(.circle)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .frame(maxHeight: .infinity)
                                        .padding(12)
                                    }
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 26)
                                        .fill(Color(.secondarySystemBackground))
                                        .overlay {
                                            if tendies.isOn {
                                                RoundedRectangle(cornerRadius: 26)
                                                    .fill(Color.clear)
                                                    .strokeBorder(lineWidth: 2)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                }
                                .contextMenu {
                                    Button {
                                        let url = AppURL.pbFolders.appendingPathComponent(tendies.folderName)
                                        fsHandlers.openInFilesApp(url)
                                    } label: {
                                        Label("在“文件”中查看目录", systemImage: "folder")
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            let url = AppURL.pbFolders.appendingPathComponent(tendies.folderName)
                                            try? fm.removeItem(at: url)
                                            tendiesArray.removeAll { $0.id == tendies.id }
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .foregroundStyle(Color(.label))
                }
            }
        }
        .navigationTitle("自定义锁屏壁纸")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                doSetupStuff()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isReady {
                VStack {
                    Button {
                        showImporter = true
                    } label: {
                        ButtonLabel("导入 .tendies 壁纸包", symbol: "arrow.down.doc")
                    }
                }
                .buttonStyle(ActionButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(device.userInterfaceIdiom == .pad ? 0 : 15)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入 .tendies 壁纸包", systemImage: "arrow.down.doc")
                    }
                    .disabled(!isReady)
                    
                    Button {
                        openApp(withBID: SysBID.poster)
                    } label: {
                        Label("打开 PosterBoard", systemImage: "arrow.up.right.square")
                    }
                    
                    Divider()
                    
                    NavigationLink {
                        List {
                            Section {
                                TextField("PosterBoard 容器路径", text: $pbContainerPath, axis: .vertical)
                                Button("重新获取路径") {
                                    pbContainerPath = fsHandlers.getContainerPath(forMatch: "com.apple.PosterBoard")
                                }
                            } header: {
                                HeaderLabel("PosterBoard", symbol: "photo")
                            }
                            
                            Section {
                                Button("清空已导入列表") {
                                    for object in tendiesArray {
                                        let url = AppURL.pbFolders.appendingPathComponent(object.folderName)
                                        try? fm.removeItem(at: url)
                                    }
                                    tendiesArray.removeAll()
                                }
                                Button("重置壁纸合集 (Collections)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.wpKit)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                                Button("重置水星壁纸 (MercuryPoster)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.mercury)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                                Button("重置视频壁纸 (Videos)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.photos)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                            } header: {
                                HeaderLabel("数据管理", symbol: "loupe")
                            } footer: {
                                Text("如果应用自定义壁纸后无法正常显示，可尝试重置上方任意对应类型的壁纸扩展缓存。")
                            }
                        }
                        .navigationTitle("壁纸设置")
                    } label: {
                        Label("壁纸设置", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("应用", role: .adaptiveConfirm) {
                    if !hasShownFirstRunMsg {
                        Alertinator.shared.alert(title: "操作提示", body: PBMsg.applyInfo, actionLabel: "继续", action: {
                            hasShownFirstRunMsg = true
                            proceed()
                        })
                    } else if tendiesArray.filter({ $0.isOn }).flatMap({ $0.descrNames }).count > 5 {
                        Alertinator.shared.alert(title: "操作提示", body: PBMsg.limitWarning, actionLabel: "确认", action: {
                            proceed()
                        })
                    } else {
                        proceed()
                    }
                    
                    @MainActor
                    func proceed() {
                        let res = applyObjects(tendiesArray.filter { $0.isOn })
                        if !res.0 {
                            if res.1.contains("an item with the same name already exists") {
                                Alertinator.shared.alert(title: "应用壁纸失败！", body: "所选的部分壁纸此前已添加过，请勿重复添加。")
                            } else {
                                Alertinator.shared.alert(title: "应用壁纸失败！", body: PBMsg.corruption)
                            }
                        } else {
                            Haptic.shared.play(.soft)
                            Alertinator.shared.alert(title: "请重启 PosterBoard 以完成应用！", body: PBMsg.finishApply, showCancel: false, actionLabel: "继续", action: { openApp(withBID: SysBID.poster) })
                        }
                    }
                }
                .disabled(tendiesArray.filter({ $0.isOn }).isEmpty)
                .disabled(pbContainerPath.isEmpty || !fm.fileExists(atPath: AppURL.pb.path))
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            let res = handleImport(result)
            if !res {
                Alertinator.shared.alert(title: "导入 .tendies 壁纸包失败！", body: PBMsg.imprtFailed)
            }
        }
    }
    
    private func doSetupStuff() {
        let fetchedPath: String? = pbContainerPath.isEmpty ? fsHandlers.getContainerPath(forMatch: "com.apple.PosterBoard") : nil
        DispatchQueue.main.async {
            if let fetchedPath, !fetchedPath.isEmpty {
                pbContainerPath = fetchedPath
            }
            if !fm.fileExists(atPath: AppURL.pb.path) {
                do {
                    try fm.createDirIfNeeded(at: AppURL.pb)
                    try fm.createDirIfNeeded(at: AppURL.pbFolders)
                } catch {
                    Alertinator.shared.alert(title: "初始化壁纸目录失败！", body: AppMsg.opFailed)
                }
            }
            isReady = true
        }
    }
    
    private func applyObjects(_ objects: [TendiesObject]) -> (Bool, String) {
        let descrTargets = Set(objects.map(\.targetDescr))
        for descrTarget in descrTargets {
            let target = "\(pbContainerPath)/\(descrTarget.path)"
            let res = wq.grantAccess(path: target)
            if !res.0 {
                print("(mg) failed to grant access at \(target): \(res.2)")
                return (false, res.2)
            }
        }
        
        for object in objects {
            let container = "\(pbContainerPath)/\(object.targetDescr.path)"
            for descr in object.descrNames {
                let descrURL = AppURL.pbFolders.appendingPathComponent(object.folderName).appendingPathComponent(descr)
                let target = object.targetDescr == .mercury ? URL(fileURLWithPath: container).appendingPathComponent(descrURL.lastPathComponent) : URL(fileURLWithPath: container).appendingPathComponent(UUID().uuidString)
                do {
                    try fm.copyItem(at: descrURL, to: target)
                } catch {
                    print("(mg) failed to copy descriptor (folder: \(object.folderName)): \(error.localizedDescription)")
                    return (false, error.localizedDescription)
                }
            }
        }
        return (true, "")
    }
    
    private func resetWallpapers(for item: PBPath) -> Bool {
        do {
            let target = URL(fileURLWithPath: "\(pbContainerPath)/\(item.path)")
            let contents = try fm.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
            
            for url in contents {
                try fm.removeItem(at: url)
            }
            return true
        } catch {
            print("(pb) failed to reset \(item.rawValue): \(error.localizedDescription)")
            return false
        }
    }
    
    private func handleImport(_ result: Result<URL, Error>) -> Bool {
        switch result {
        case .success(let fileURL):
            let stopAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if stopAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            if let tendies = pbHandler.makeObjectFromTendies(at: fileURL) {
                withAnimation {
                    tendiesArray.append(tendies)
                }
            }
            return true
        case .failure(let error):
            print("(pb) failed to import file: \(error.localizedDescription)")
            return false
        }
    }
}

