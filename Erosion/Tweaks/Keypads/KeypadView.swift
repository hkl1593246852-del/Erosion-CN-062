//
//  KeypadView.swift
//  Erosion
//
//  Created by lunginspector on 8/28/26.
//

import SwiftUI

import PhotosUI

struct KeypadView: View {
    @StateObject private var kpMgr = KeypadManager.shared
    @AppStorage("mpContainerPath") private var mpContainerPath = ""
    @State private var isReady = false
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    @State private var size: KPSize = KPSize.defSize
    @State private var showSizeAlert = false
    @State private var custW = 0
    @State private var custH = 0
    @State private var showFileImporter = false
    
    var body: some View {
        VStack {
            if !isReady {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.25)
                    Text("正在定位系统容器路径...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                    ForEach($kpMgr.mpKeypad) { $item in
                        KeyItem(size: $size, kpID: item.kpID, imgData: $item.imgData)
                            .environmentObject(kpMgr)
                    }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 2) {
                        Text("按键尺寸")
                        Picker("", selection: $size) {
                            ForEach(KPSize.allCases, id: \.self) { kpSize in
                                Text(kpSize.label + (kpSize == .custom ? " (\(custW)x\(custH))" : "")).tag(kpSize)
                            }
                        }
                        .alert("请输入自定义按键尺寸（像素）", isPresented: $showSizeAlert) {
                            TextField("宽度", value: $custW, format: .number)
                                .keyboardType(.numberPad)
                            TextField("高度", value: $custH, format: .number)
                                .keyboardType(.numberPad)
                            Button("取消", role: .cancel) {
                                size = .defSize
                            }
                            Button("设定") {
                                kpMgr.changeSizeOfKeypads(size: size, custW: custW, custH: custH)
                            }
                        }
                        .onChange(of: size) { _, newSize in
                            if newSize != KPSize.custom {
                                kpMgr.changeSizeOfKeypads(size: newSize)
                            } else {
                                showSizeAlert.toggle()
                            }
                        }
                    }
                    .padding(6)
                    .background(Color(.systemBackground), in: .rect(cornerRadius: cornerRad.component))
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        let res = kpMgr.applyKeypadItems()
                        if res {
                            Alertinator.shared.alert(title: "拨号键盘主题应用成功！", body: KPMsg.applyComp, actionLabel: "打开电话", action: {
                                openApp(withBID: SysBID.phone)
                            })
                            Haptic.shared.play(.soft)
                        } else {
                            Alertinator.shared.alert(title: "应用拨号键盘主题失败！", body: AppMsg.opFailed)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(KeypadButtonStyle(isConfirm: true))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                }
            }
        }
        .navigationTitle(isPad() ? "" : "拨号键盘美化")
        .frame(maxWidth: 325)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        kpMgr.maskKeysIntoCircle(size: size, custW: custW, custH: custH)
                    } label: {
                        Label("裁切为圆形按键", systemImage: "circle")
                    }
                    Button {
                        size = .defSize
                        kpMgr.getCurrentKeypads()
                    } label: {
                        Label("读取当前按键", systemImage: "externaldrive")
                    }
                    Button {
                        openApp(withBID: SysBID.phone)
                    } label: {
                        Label("打开电话应用", systemImage: "arrow.up.right.square")
                    }
                    Divider()
                    Button {
                        size = .defSize
                        kpMgr.clearKeypads()
                    } label: {
                        Label("清空当前编辑", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        Alertinator.shared.alert(title: "确定要重置拨号按键吗？", body: KPMsg.resetWarn, actionLabel: "确认", action: {
                            let res = kpMgr.resetKeypadItems()
                            if res {
                                kpMgr.mpKeypad = emptyKeypadArray
                                kpMgr.getCurrentKeypads()
                                Alertinator.shared.alert(title: "拨号键盘已恢复默认！", body: KPMsg.applyComp)
                            } else {
                                Alertinator.shared.alert(title: "重置拨号键盘失败！", body: AppMsg.opFailed)
                            }
                        })
                    } label: {
                        Label("恢复系统默认", systemImage: "trash")
                    }
                } label: {
                    Label("菜单", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                }
                .disabled(!isReady)
            }
            ToolbarSpacer(placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("导入主题") {
                    showFileImporter = true
                }
                .disabled(!isReady)
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                var targetPath = mpContainerPath
                if targetPath.isEmpty {
                    targetPath = fsHandlers.getContainerPath(forMatch: "com.apple.mobilephone")
                }
                if !targetPath.isEmpty && !fm.isReadableFile(atPath: targetPath) {
                    let _ = wq.grantAccess(path: targetPath)
                }
                DispatchQueue.main.async {
                    if mpContainerPath.isEmpty && !targetPath.isEmpty {
                        mpContainerPath = targetPath
                    }
                    kpMgr.getCurrentKeypads(size: size, saveOgData: true)
                    isReady = true
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            handleImport(result)
        }
    }
    
    private struct KeyItem: View {
        @EnvironmentObject private var kpMgr: KeypadManager
        @Binding var size: KPSize
        @State var kpID: KeypadID
        @Binding var imgData: Data
        @State private var showPicker = false
        
        var body: some View {
            Button {
                showPicker = true
            } label: {
                if let img = UIImage(data: imgData) {
                    let denoVal: Float = isPad() ? 2.1 : 3.0
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: CGFloat(Float(img.size.width)/denoVal), height: CGFloat(Float(img.size.height)/denoVal))
                        .background {
                            Circle()
                                .fill(Color.clear)
                                .glassEffect(.clear, in: .circle)
                                .frame(width: 78, height: 78)
                        }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .frame(width: 78, height: 78)
                        .foregroundStyle(Color(.label))
                        .fontWeight(.medium)
                        .glassEffect(.clear.interactive(), in: .circle)
                }
            }
            .frame(width: 80, height: 80)
            .sheet(isPresented: $showPicker) {
                ImagePickerView() { data in
                    imgData = data
                    guard let img = UIImage(data: imgData) else { return }
                    let imgData = {
                        switch size {
                        case .defSize: return kpMgr.resizeAndRet(withData: data, isDefault: true)
                        case .custom: return kpMgr.resizeAndRet(withData: data, customSize: CGSize(width: Int(img.size.width), height: Int(img.size.height)))
                        default: return kpMgr.resizeAndRet(withData: data, newSize: size.float)
                        }
                    }()
                    kpMgr.updateKeypadItem(forID: kpID, withData: imgData, ogData: imgData)
                }
            }
        }
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
                let res = kpMgr.importTheme(fromURL: fileURL)
                if res {
                    Haptic.shared.play(.soft)
                } else {
                    throw "failed to import theme!"
                }
            } catch {
                print("(kp) failed to import theme: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "导入主题失败！", body: AppMsg.opFailed)
            }
        case .failure(let error):
            print("(kp) failed to import file: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "导入主题失败！", body: "\(error.localizedDescription)")
        }
    }
    
}

// MARK: UI
struct KeypadButtonStyle: ButtonStyle {
    var isConfirm = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24))
            .frame(width: 75, height: 75)
            .foregroundStyle(Color(.label))
            .fontWeight(.medium)
            .glassEffect(.clear.tint(isConfirm ? Color.accentColor : Color.clear).interactive(), in: .circle)
    }
}
