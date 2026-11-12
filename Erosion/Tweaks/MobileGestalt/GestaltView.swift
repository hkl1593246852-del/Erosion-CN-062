//
//  GestaltView.swift
//  Erosion
//
//  Created by lunginspector on 8/14/26.
//

import SwiftUI

import UniformTypeIdentifiers

struct GestaltView: View {
    @EnvironmentObject private var mgr: ErosionManager
    @StateObject private var store = GestaltStore.shared
    @AppStorage("mgOverrideGates") private var mgOverrideGates = false
    @AppStorage("mgWriteAtomically") private var mgWriteAtomically = true
    @AppStorage("autoRespring") var autoRespring = false
    @AppStorage("hasShownSheet") private var hasShownSheet = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var mgSubtype = 0
    @State private var mgOgSubtype = 0
    @State private var mgOgDeviceName = ""
    @State private var mgEnableDeviceName = false
    @AppStorage("mgDeviceName") private var mgDeviceName = ""
    @AppStorage("ogMachineName") private var ogMachineName = ""
    @AppStorage("showRegionTweak") private var showRegionTweak = false
    @AppStorage("showCustomKeys") private var showCustomKeys = false
    @AppStorage("mgCustKeyArray") var customKeys: [MGCustomKey] = []
    @State private var mgProductType = ""
    
    @State private var showInfoSheet = false
    @State private var idiotButtonTimerComplete = false
    @State private var mgBaselineDict: NSDictionary = [:]
    @State private var showDiffSheet = false
    @State private var pendingDiffs: [MGDiffItem] = []
    @State private var pendingCandidateDict: NSMutableDictionary? = nil
    @State private var hasPromptedBuildMismatch = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if mgOverrideGates {
                        HStack {
                            Picker("屏幕子类型", selection: $mgSubtype) {
                                Text("原始默认 (\(mgOgSubtype))").tag(mgOgSubtype)
                                if isDynamIslandHD() && doubleSysVrs() < 19.0 {
                                    Text("禁用灵动岛").tag(2436)
                                }
                                Text("iPhone 14 Pro").tag(2436)
                                Text("iPhone 14 Pro Max").tag(2796)
                                Text("iPhone 15 Pro Max").tag(2976)
                                if doubleSysVrs() >= 18.0 {
                                    Text("iPhone 16 Pro").tag(2622)
                                    Text("iPhone 16 Pro Max").tag(2868)
                                }
                                if doubleSysVrs() >= 26.0 {
                                    Text("iPhone Air").tag(2736)
                                }
                                if doubleSysVrs() >= 27.0 {
                                    Text("iPhone 18 Pro Max").tag(2670)
                                }
                                if isHomeButtonHD() {
                                    Text("iPhone X 全面屏手势").tag(2436)
                                }
                            }
                            Spacer()
                            Button {
                                Alertinator.shared.alert(title: "屏幕子类型说明", body: MGMsg.subtype)
                            } label: {
                                Image(systemName: "info.circle")
                                    .frame(width: 24, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("自定义机型名称", isOn: $mgEnableDeviceName)
                    if mgEnableDeviceName {
                        TextField("输入自定义机型名称", text: $mgDeviceName)
                    }
                    PlainToggle("液态玻璃低功耗渲染（省电模式）", infoType: .info, infoMessage: MGMsg.liquidGlass, minVrs: 26.0, isOn: store.mgKeyBinding([MGKey.liquidGlassLowPower]))
                } header: {
                    HeaderLabel("外观与显示特征", symbol: "paintbrush.pointed")
                }
                
                if !isDynamIslandHD() || !isAODHD() || !isBootChimeHD() || !isChargeLimitHD() || mgOverrideGates {
                    Section {
                        if !isDynamIslandHD() || mgOverrideGates {
                            PlainToggle("启用灵动岛", minVrs: 19.0, isOn: store.mgKeyBinding([MGKey.island]))
                        }
                        if !isAODHD() || mgOverrideGates {
                            PlainToggle("启用全天候显示 (AOD)", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.AOD, MGKey.AOTime]))
                            if store.isEnabled([MGKey.AOD]) {
                                PlainToggle("启用全天候显示鲜艳度", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.AODVibrancy]))
                            }
                        }
                        if !isChargeLimitHD() || mgOverrideGates {
                            PlainToggle("启用 80% 充电上限", minVrs: 17.0, isOn: store.mgKeyBinding([MGKey.chargeLim]))
                        }
                        if !isBootChimeHD() || mgOverrideGates {
                            PlainToggle("启用开机提示音", isOn: store.mgKeyBinding([MGKey.bootChime]))
                        }
                    } header: {
                        HeaderLabel("硬件特性解锁", symbol: "gearshape")
                    }
                }
                
                Section {
                    PlainToggle("启用 Apple 内部安装模式", infoType: .info, infoMessage: MGMsg.intInstall, isOn: store.mgKeyBinding([MGKey.intInstall]))
                    PlainToggle("启用内部版本标识 (Internal Build)", infoType: .info, infoMessage: MGMsg.intBuild, isOn: store.mgKeyBinding([MGKey.intBuild]))
                } header: {
                    HeaderLabel("内部调试选项", symbol: "ant")
                }
                .disabled(store.isEnabled([MGKey.appIntell]))
                
                Section {
                    PlainToggle("启用安全研究设备界面 (SRD UI)", minVrs: 26.0, isOn: store.mgKeyBinding([MGKey.srd]))
                    if showRegionTweak || mgOverrideGates {
                        PlainToggle("解除地区限制（国行 AI / 美版 LL/A）", isOn: store.mgRegionRestrictionsBinding())
                        if store.mgRegionRestrictionsBinding().wrappedValue {
                            HStack {
                                Text("美版监管型号")
                                Spacer()
                                TextField("如 A3473", text: store.mgRegModelBinding())
                                    .multilineTextAlignment(.trailing)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                    if !isAppleIntellHD() || mgOverrideGates {
                        PlainToggle(
                            "启用 Apple 智能开关",
                            subtitle: "自动同步解锁相册“消除”与备忘录“手写体合成”",
                            infoType: .info,
                            infoTitle: "启用 Apple 智能说明",
                            infoMessage: MGMsg.appleIntellInfo,
                            minVrs: 18.1,
                            isOn: store.mgKeyBinding(MGKey.appIntellAllKeys)
                        )
                        .onChange(of: store.mgKeyBinding(MGKey.appIntellAllKeys).wrappedValue) { (_, newVal) in
                            if newVal {
                                store.mgPullKeys([MGKey.intBuild, MGKey.intInstall])
                            }
                        }
                    }
                    if !isAdvAppleIntellHD() || mgOverrideGates {
                        PlainToggle(
                            "解锁 iOS 27 进阶 AI 能力",
                            subtitle: "开启端侧个人实时翻译与通话/录音音频智能摘要",
                            infoType: .info,
                            infoTitle: "iOS 27 进阶 AI 能力说明",
                            infoMessage: MGMsg.advAppleIntell,
                            minVrs: 27.0,
                            isOn: store.mgKeyBinding(MGKey.advAppIntellKeys)
                        )
                    }
                    if !isAppleIntellHD() || mgOverrideGates {
                        HStack(spacing: 10) {
                            Picker("机型伪装", selection: $mgProductType) {
                                Text("保持默认").tag(ogMachineName)
                                if ogMachineName.contains("Pad") {
                                    if doubleSysVrs() >= 17.4 {
                                        Text("iPad Pro 11 英寸 (M4)").tag("iPad16,3")
                                        Text("iPad Pro 11 英寸 (M4, 蜂窝网络)").tag("iPad16,4")
                                    }
                                    Text("iPad Pro 11 英寸 (第 4 代)").tag("iPad14,3")
                                    Text("iPad Pro 11 英寸 (第 4 代, 蜂窝网络)").tag("iPad14,4")
                                } else {
                                    Text("iPhone 15 Pro").tag("iPhone16,1")
                                    Text("iPhone 15 Pro Max").tag("iPhone16,2")
                                    if doubleSysVrs() >= 18.0 {
                                        Text("iPhone 16").tag("iPhone17,3")
                                        Text("iPhone 16 Plus").tag("iPhone17,4")
                                        Text("iPhone 16 Pro").tag("iPhone17,1")
                                        Text("iPhone 16 Pro Max").tag("iPhone17,2")
                                    }
                                    if doubleSysVrs() >= 19.0 {
                                        Text("iPhone 17").tag("iPhone18,3")
                                        Text("iPhone 17 Pro").tag("iPhone18,1")
                                        Text("iPhone 17 Pro Max").tag("iPhone18,2")
                                        Text("iPhone Air").tag("iPhone18,4")
                                    }
                                    if doubleSysVrs() >= 27.0 {
                                        Text("iPhone 18 Pro").tag("iPhone19,2")
                                        Text("iPhone 18 Pro Max").tag("iPhone19,3")
                                        Text("iPhone Duo").tag("iPhone19,4")
                                    }
                                }
                            }
                            Button {
                                Alertinator.shared.alert(title: "机型伪装说明", body: isAppleIntellHD() ? MGMsg.spoofUseless : MGMsg.spoofAI)
                            } label: {
                                Image(systemName: "info.circle")
                                    .frame(width: 24, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HeaderLabel("地区与功能准入 (Eligibility)", symbol: "flag")
                } footer: {
                    Text("注：iPhone 18 系列硬件设备树已原生开启全部 Apple 智能与 iOS 27 进阶 AI 能力（个人实时翻译 / 音频智能），无需额外开启，故默认不展示相关选项（国行机型仅需开启“解除地区限制”即可完整激活）。")
                }

                Section {
                    let greenTeaReady = store.canModifyGreenTeaCache()
                    let wapiReady = store.canModifyWapiCache()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: greenTeaReady ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .foregroundStyle(greenTeaReady ? Color.green : Color.red)
                            Text(greenTeaReady ? "已精确匹配本机缓存布局" : "动态解析未通过（已拒绝修改）")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(greenTeaReady ? Color.primary : Color.red)
                            Spacer()
                            Button {
                                let report = MGCacheDataCoordinator.shared.diagnosticReport(for: store.mgCurrentDict)
                                Alertinator.shared.alert(title: "本机 CacheData 动态解析详情", body: report)
                            } label: {
                                HStack(spacing: 3) {
                                    Text("查看偏移")
                                        .font(.caption)
                                    Image(systemName: "info.circle")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                        if let failReason = store.cacheResolutionFailureReason() {
                            Text(failReason)
                                .font(.caption)
                                .foregroundStyle(Color.red)
                        }
                    }
                    .padding(.vertical, 2)

                    PlainToggle(
                        "解除国行底层限制（eSIM / FaceTime 音频）",
                        infoType: .info,
                        infoTitle: "解除国行底层限制说明",
                        infoMessage: MGMsg.chinaCacheUnlock,
                        isOn: store.mgChinaRestrictionCacheBinding()
                    )
                    .disabled(!greenTeaReady)

                    PlainToggle(
                        "将“无线局域网”显示为“Wi-Fi”",
                        subtitle: "⚠️ 开启后会丢失国行特有的单应用“不允许联网”功能",
                        infoType: .warning,
                        infoTitle: "无线局域网改 Wi-Fi 重要提示",
                        infoMessage: MGMsg.wapiToWifi,
                        isOn: store.mgWapiWifiBinding()
                    )
                    .disabled(!wapiReady)
                } header: {
                    HeaderLabel("国行底层缓存限制 (CacheData 动态解析)", symbol: "antenna.radiowaves.left.and.right")
                } footer: {
                    Text("运行时从本机内存中的 libMobileGestalt.dylib 实时解析偏移并严格核对 CacheUUID、长度与有效位；解析失败时严禁修改任何字节。注意：将“无线局域网”改为“Wi-Fi”会丢失国行的“不允许联网”功能（仅保留蜂窝数据开关）。应用本组开关后请手动重启手机生效。")
                }
                
                Section {
                    if !isCrashDectHD() || mgOverrideGates {
                        PlainToggle("车祸检测设置项", isOn: store.mgKeyBinding([MGKey.crashDet]))
                    }
                    if !isPWMHD() || mgOverrideGates {
                        PlainToggle("PWM 调光开关", minVrs: 19.0, isOn: store.mgKeyBinding([MGKey.pwm]))
                    }
                    if ogMachineName.contains("iPhone") || mgOverrideGates {
                        PlainToggle("Apple Pencil 设置项", isOn: store.mgKeyBinding([MGKey.appPencil]))
                    }
                    if !isCamControlHD() || mgOverrideGates {
                        PlainToggle("相机控制按键设置项", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.camButton, MGKey.grapPefr]))
                    }
                    if !isActionButtonHD() || mgOverrideGates {
                        PlainToggle("操作按钮 (Action Button)", minVrs: 17.0, isOn: store.mgKeyBinding([MGKey.actButton]))
                    }
                    if isHomeButtonHD() || mgOverrideGates {
                        PlainToggle("轻点唤醒 (Tap to Wake)", isOn: store.mgKeyBinding([MGKey.tapToWake]))
                    }
                } header: {
                    HeaderLabel("系统设置偏好面板", symbol: "gear")
                }
                
                if machineName().contains("iPad") || mgOverrideGates {
                    Section {
                        PlainToggle("启用台前调度 (Stage Manager)", isOn: store.mgKeyBinding([MGKey.stageMgr]))
                        if !machineName().contains("iPad") {
                            PlainToggle("启用 iPadOS 界面与分屏（已由防白苹果护栏永久禁用）", infoType: .warning, infoMessage: MGMsg.ipadOS, isOn: store.mgTrollPadBinding())
                                .disabled(true)
                        }
                    } header: {
                        HeaderLabel("iPadOS 多任务特性", symbol: "ipad")
                    }
                }
            }
            .navigationTitle("MobileGestalt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.mgCurrentDict = mgLoadData()
                            Haptic.shared.play(.soft)
                        } label: {
                            Label("放弃未保存修改", systemImage: "arrow.counterclockwise")
                        }
                        
                        Button {
                            mgRevert()
                        } label: {
                            Label("还原原始备份", systemImage: "xmark")
                        }
                        
                        Button(role: .destructive) {
                            Alertinator.shared.alert(title: "确定要彻底重置 MobileGestalt 吗？", body: MGMsg.mgReset, actionLabel: "确认重置", action: {
                                do {
                                    // Never destroy OriginalGestalt.plist during system cache rebuild (SEC-M1-05)
                                    if fm.fileExists(atPath: MGURL.savedGestaltURL.path) {
                                        let archiveURL = URL.documentsDirectory.appendingPathComponent("ArchivedOriginalGestalt_\(Int(Date().timeIntervalSince1970)).plist")
                                        try? fm.copyItem(at: MGURL.savedGestaltURL, to: archiveURL)
                                        mgExcludeFromCloudBackup(archiveURL)
                                    }
                                    try fm.removeItem(at: MGURL.fsGestaltURL)
                                    store.mgCurrentDict = NSMutableDictionary()
                                    Alertinator.shared.alert(title: "已重置 MobileGestalt！", body: MGMsg.mgResetComp, showCancel: false, actionLabel: "退出应用", action: { exitinator() })
                                } catch {
                                    print("(mg) failed to reset mobilegestalt: \(error.localizedDescription)")
                                    Alertinator.shared.alert(title: "重置 MobileGestalt 失败！", body: AppMsg.opFailed)
                                }
                            })
                        } label: {
                            Label("清除并重建缓存", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        if showCustomKeys {
                            NavigationLink(destination: CustomKeyView()) {
                                Label("自定义键值", systemImage: "pencil")
                            }
                        }
                        
                        // tweak-specific settings
                        NavigationLink {
                            List {
                                Section {
                                    Button("导出当前 MobileGestalt") {
                                        presentShareSheet(with: MGURL.fsGestaltURL)
                                    }
                                    Button("导出原始备份 (OriginalGestalt)") {
                                        presentShareSheet(with: MGURL.savedGestaltURL)
                                    }
                                    if fm.fileExists(atPath: MGURL.preApplyGestaltURL.path) {
                                        Button("导出上次写入前快照 (PreApply)") {
                                            presentShareSheet(with: MGURL.preApplyGestaltURL)
                                        }
                                    }
                                    Button("重新生成原始备份", role: .destructive) {
                                        Alertinator.shared.alert(title: "警告！", body: MGMsg.mgResetSavWarn, actionLabel: "确认覆盖", action: {
                                            try? fm.removeItem(at: MGURL.savedGestaltURL)
                                            try? fm.removeItem(at: MGURL.savedGestaltSHA256URL)
                                            store.mgCurrentDict = mgLoadData()
                                        })
                                    }
                                } header: {
                                    HeaderLabel("数据备份与导出", symbol: "loupe")
                                }
                                
                                Section {
                                    PlainToggle("显示被隐藏的修改项", infoType: .warning, infoMessage: MGMsg.hidTweakWarn, isOn: $mgOverrideGates)
                                    Toggle("启用自定义键值功能", isOn: $showCustomKeys)
                                    HStack {
                                        Text("安全原位写入 + 物理刷盘 (F_FULLFSYNC)")
                                        Spacer()
                                        Text("已强制锁定")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } footer: {
                                    Text("防白苹果安全协议已永久锁定无零字节窗口原位覆盖（pwrite + F_FULLFSYNC），完整保留系统文件 Inode 与 POSIX 权限属性，并在任何校验异常时自动原位回滚。")
                                }
                            }
                            .navigationTitle("Gestalt 设置")
                        } label: {
                            Label("高级设置", systemImage: "gear")
                        }
                    } label: {
                        Label("菜单", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("应用", role: .adaptiveConfirm) {
                        if !hasShownSheet {
                            showInfoSheet = true
                        } else {
                            prepareApplyPreview()
                        }
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                NavigationStack {
                    VStack {
                        InfoSheet(title: "使用前必读") {
                            InfoSheetCell(title: "重要风险提示！", symbol: "exclamationmark.triangle.fill", context: MGMsg.support)
                                .modifier(SectionPlatter())
                            InfoSheetCell(title: "Apple 智能与机型伪装", symbol: "apple.intelligence", context: MGMsg.spoofAI)
                            InfoSheetCell(title: "iPadOS 界面模式", symbol: "ipad", context: MGMsg.ipadOS)
                            InfoSheetCell(title: "解除地区限制（国行解锁）", symbol: "map", context: MGMsg.region)
                        } button: {
                            Button(idiotButtonTimerComplete ? "我已知晓，查看变更预览" : "请阅读上方提示（4 秒）...") {
                                showInfoSheet = false
                                hasShownSheet = true
                                idiotButtonTimerComplete = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    prepareApplyPreview(isFromSheet: true)
                                }
                            }
                            .buttonStyle(ConfirmButtonStyle())
                            .padding(.horizontal, 30)
                            .padding(.bottom, device.userInterfaceIdiom == .pad ? 25 : 0)
                            .disabled(!idiotButtonTimerComplete)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            idiotButtonTimerComplete = true
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("取消") {
                                showInfoSheet = false
                                idiotButtonTimerComplete = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showDiffSheet) {
                NavigationStack {
                    List {
                        Section {
                            ForEach(pendingDiffs) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.label)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.keyPath)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("修改前：")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(item.beforeText)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("修改后：")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.accentColor)
                                        Text(item.afterText)
                                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text("共 \(pendingDiffs.count) 项键值变更")
                        } footer: {
                            Text("点击“确认写入”后将自动备份当前缓存、执行原位写入并进行完整读回校验；若校验异常将自动回滚原文件。")
                        }
                    }
                    .navigationTitle("变更对比预览")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") {
                                showDiffSheet = false
                                pendingCandidateDict = nil
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("确认写入") {
                                let candidate = pendingCandidateDict
                                showDiffSheet = false
                                pendingCandidateDict = nil
                                if let candidate {
                                    mgCommit(candidate)
                                }
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .onAppear {
                if ogMachineName.isEmpty {
                    ogMachineName = machineName()
                }
                let isWritable = fm.isWritableFile(atPath: MGURL.fsGestaltURL.path)
                if !isWritable {
                    let res = wq.grantAccess(path: MGURL.fsGestaltURL.deletingLastPathComponent().path)
                    if !res.0 {
                        Alertinator.shared.alert(title: "获取 MobileGestalt 写入权限失败！", body: "修改将无法保存生效，请尝试重启本应用后再试。")
                    }
                }
                store.mgCurrentDict = mgLoadData()
            }
        }
    }
    
    private func mgLoadData() -> NSMutableDictionary {
        do {
            let mgData = try Data(contentsOf: MGURL.fsGestaltURL)
            let preCheck = mgValidatePlistData(mgData)
            guard preCheck.0 else {
                throw preCheck.1
            }
            if !fm.fileExists(atPath: MGURL.savedGestaltURL.path) {
                try mgSaveOriginalBackupWithDigest(mgData)
            } else if !fm.fileExists(atPath: MGURL.savedGestaltSHA256URL.path),
                      let existingOgData = try? Data(contentsOf: MGURL.savedGestaltURL),
                      mgValidatePlistData(existingOgData).0 {
                let hex = mgComputeSHA256Hex(existingOgData)
                try? Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
                mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
            }
            mgExcludeFromCloudBackup(MGURL.savedGestaltURL)
            
            guard let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
                  let ogCacheExtra = ogDict["CacheExtra"] as? NSDictionary,
                  let ogArtwork = ogCacheExtra[MGKey.artwork] as? NSDictionary else {
                throw "无法从 MobileGestalt 读取原始硬件配置"
            }
            
            mgOgSubtype = ogArtwork["ArtworkDeviceSubType"] as? Int ?? 0
            mgOgDeviceName = ogArtwork["ArtworkDeviceProductDescription"] as? String ?? ""
            
            let ogRegionCode = ogCacheExtra[MGKey.regionCode] as? String ?? ""
            let ogRegionSysconfig = ogCacheExtra[MGKey.regionSysconfig] as? String ?? ""
            let localeRegion = Locale.current.region?.identifier ?? ""
            if ogRegionCode != "LL" || ogRegionSysconfig != "LL/A" || localeRegion != "US" {
                showRegionTweak = true
            }
            
            guard let parsedBaseline = try PropertyListSerialization.propertyList(from: mgData, options: [], format: nil) as? NSDictionary,
                  let currentDict = try PropertyListSerialization.propertyList(from: mgData, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary else {
                throw "无法解析 MobileGestalt 字典数据"
            }
            mgBaselineDict = parsedBaseline
            MGCacheDataCoordinator.shared.recordBaselineIfNeeded(liveDict: currentDict, savedOriginalDict: ogDict)
            switch MGCacheDataCoordinator.shared.resolveValidated(for: currentDict) {
            case .success((let layout, _)):
                let wapiDesc = layout.wapiOffset.map { String(format: "0x%X", $0) } ?? "N/A"
                print(String(format: "[*] (mg-cache) 本机动态解析成功：UUID=%@, 槽位=%d (%d字节), green-tea=0x%X, not-green-tea=0x%X, wapi=%@",
                             layout.uuid, layout.slotCount, layout.byteCount, layout.greenTeaOffset, layout.notGreenTeaOffset, wapiDesc))
            case .failure(let err):
                print("[!] (mg-cache) 本机动态解析未通过，已锁定二进制缓存修改：\(err.localizedDescription)")
            }
            
            if let cacheExtra = currentDict["CacheExtra"] as? NSDictionary,
               let artwork = cacheExtra[MGKey.artwork] as? NSDictionary {
                mgSubtype = artwork["ArtworkDeviceSubType"] as? Int ?? 0
                mgDeviceName = artwork["ArtworkDeviceProductDescription"] as? String ?? ""
                mgEnableDeviceName = (!mgDeviceName.isEmpty && mgDeviceName != mgOgDeviceName)
                mgProductType = cacheExtra[MGKey.prodType] as? String ?? currentOriginalMachineName()
                
                // Detect OS upgrade build mismatch between OriginalGestalt.plist and live MobileGestalt
                let ogBuild = ogDict["CacheVersion"] as? String ?? ""
                let curBuild = currentDict["CacheVersion"] as? String ?? ""
                let curRegCode = cacheExtra[MGKey.regionCode] as? String ?? ""
                let curProd = cacheExtra[MGKey.prodType] as? String ?? ""
                if !hasPromptedBuildMismatch && !ogBuild.isEmpty && !curBuild.isEmpty && ogBuild != curBuild {
                    hasPromptedBuildMismatch = true
                    if curRegCode != "LL" && (curProd.isEmpty || curProd == currentOriginalMachineName()) {
                        Alertinator.shared.alert(
                            title: "检测到系统版本已更新",
                            body: "原始备份文件来自旧版系统 (\(ogBuild))，而当前系统已更新至 \(curBuild)（当前缓存处于原厂未修改状态）。\n\n建议立即将原始备份同步更新为 \(curBuild) 的原厂文件，以免后续误用旧版备份覆盖。",
                            actionLabel: "更新原始备份",
                            action: {
                                try? mgSaveOriginalBackupWithDigest(mgData)
                                store.mgCurrentDict = mgLoadData()
                            }
                        )
                    } else {
                        print("(mg) notice: savedGestalt CacheVersion (\(ogBuild)) differs from current (\(curBuild))")
                    }
                }
            }
            
            return currentDict
        } catch {
            print("(mg) failed to get mobilegestalt: \(error.localizedDescription)")
            Haptic.shared.play(.heavy)
            Alertinator.shared.alert(title: "读取 MobileGestalt 失败！", body: "当前无法正常加载配置文件，请返回上一页并检查日志。", showCancel: false, actionLabel: "返回", action: { dismiss() })
        }
        
        return [:]
    }
    
    private func buildCandidateDict() throws -> NSMutableDictionary {
        let snapshotData = try PropertyListSerialization.data(fromPropertyList: store.mgCurrentDict, format: .binary, options: 0)
        guard let candidate = try PropertyListSerialization.propertyList(from: snapshotData, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary,
              let cacheExtra = candidate["CacheExtra"] as? NSMutableDictionary else {
            throw "无法构建待写入的 CacheExtra 字典！"
        }
        guard let artwork = cacheExtra[MGKey.artwork] as? NSMutableDictionary else {
            throw "检测到 ArtworkTraits (\(MGKey.artwork)) 字段缺失或非有效字典结构，为防止丢失屏幕特征已拦截写入！"
        }
        
        let targetSubtype = mgOverrideGates ? mgSubtype : mgOgSubtype
        if targetSubtype > 0 {
            artwork["ArtworkDeviceSubType"] = targetSubtype
        }
        let trimmedName = mgDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if mgEnableDeviceName {
            guard !trimmedName.isEmpty else {
                throw "开启“自定义机型名称”时名称不能为空！"
            }
            artwork["ArtworkDeviceProductDescription"] = trimmedName
            cacheExtra[MGKey.modelNameOuter1] = trimmedName
            cacheExtra[MGKey.modelNameOuter2] = trimmedName
        } else {
            if !mgOgDeviceName.isEmpty {
                artwork["ArtworkDeviceProductDescription"] = mgOgDeviceName
            }
            for outerKey in [MGKey.modelNameOuter1, MGKey.modelNameOuter2] {
                if let ogVal = store.originalCacheExtraValue(forKey: outerKey) {
                    cacheExtra[outerKey] = ogVal
                } else {
                    cacheExtra.removeObject(forKey: outerKey)
                }
            }
        }
        
        let safeProdType = (!isAppleIntellHD() || mgOverrideGates) ? mgProductType : currentOriginalMachineName()
        if !safeProdType.isEmpty {
            cacheExtra[MGKey.prodType] = safeProdType
        }
        for item in customKeys {
            if let blockedReason = mgIsDangerousCacheExtraKey(item.key) {
                if item.isOn {
                    throw "自定义键 \(item.key) 已被防白苹果护栏拦截：\(blockedReason)"
                }
                continue
            }
            if item.isOn {
                cacheExtra[item.key] = item.plistValue
            } else if let ogVal = store.originalCacheExtraValue(forKey: item.key) {
                cacheExtra[item.key] = ogVal
            } else {
                cacheExtra.removeObject(forKey: item.key)
            }
        }

        // Self-healing sanitizer: strip non-cached iOS 27 keys and binary CacheData slot keys from CacheExtra
        // in case the device was previously polluted by an older third-party tool before installing Erosion-CN.
        if raveSupported() {
            cacheExtra.removeObject(forKey: MGKey.regionInfo)
            cacheExtra.removeObject(forKey: "0L5PkT61qoH1b/B1USWqjQ")
        }
        for conflictKey in ["iyfxmLogGVIaH7aEgqwcIA", "4snMZS8LJkSctKypt2m+xA", "hiHut/WR+B9Lx/vd0WyeNg", "green-tea", "not-green-tea", "wapi"] {
            cacheExtra.removeObject(forKey: conflictKey)
        }
        return candidate
    }
    
    private func prepareApplyPreview(isFromSheet: Bool = false) {
        do {
            let candidate = try buildCandidateDict()
            if case .failure(let cacheErr) = MGCacheDataCoordinator.shared.validateTransition(from: mgBaselineDict, to: candidate) {
                throw cacheErr.localizedDescription
            }
            let diffs = mgComputeDiff(from: mgBaselineDict, to: candidate)
            if diffs.isEmpty {
                Alertinator.shared.alert(title: "没有待应用的更改", body: "当前各项配置与系统缓存文件中的内容完全一致，无需重复写入。", showCancel: true)
                return
            }
            pendingCandidateDict = candidate
            pendingDiffs = diffs
            showDiffSheet = true
        } catch {
            Alertinator.shared.alert(title: "无法生成变更预览", body: "\(error.localizedDescription)")
        }
    }

    private func mgCommit(_ mgDictToApply: NSMutableDictionary) {
        do {
            let cacheDataChanged = (mgBaselineDict["CacheData"] as? Data) != (mgDictToApply["CacheData"] as? Data)
            let data = try PropertyListSerialization.data(fromPropertyList: mgDictToApply, format: .binary, options: 0)
            let res = mgWriteDetailed(data)
            
            if res.0 {
                print("[*] successfully overwrote and verified mobilegestalt!")
                Haptic.shared.play(.soft)
                store.mgCurrentDict = mgLoadData()
                if autoRespring && !cacheDataChanged {
                    mgr.shouldRespring = true
                } else {
                    let needsRebootHint = store.isEnabled([MGKey.appIntell]) || store.mgRegionRestrictionsBinding().wrappedValue
                    var extraHint = ""
                    if cacheDataChanged {
                        extraHint = "\n\n⚠️ 本次修改了底层二进制缓存（国行底层限制 / Wi-Fi 显示），仅注销无法刷新蜂窝基带与系统通话守护进程，请务必【手动重启一次手机】使其生效！"
                    } else if needsRebootHint {
                        extraHint = "\n\n若修改了地区限制或 Apple 智能，注销后建议手动重启一次设备以使 eligibilityd 完全刷新。"
                    }
                    Alertinator.shared.alert(
                        title: "写入并读回校验成功！",
                        body: AppMsg.applied + extraHint,
                        actionLabel: "立即注销",
                        action: { mgr.shouldRespring = true }
                    )
                }
            } else {
                throw res.1
            }
        } catch {
            print("(mg) failed to apply mobilegestalt: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "应用 MobileGestalt 失败！", body: "\(error.localizedDescription)")
        }
    }
    
    private func mgRevert() {
        do {
            let integrityCheck = mgVerifyOriginalBackupIntegrity()
            guard integrityCheck.0 else {
                Alertinator.shared.alert(title: "原始备份完整性校验未通过！", body: integrityCheck.1, showCancel: true)
                return
            }
            guard let mgDictToApply = NSMutableDictionary(contentsOf: MGURL.savedGestaltURL) else {
                throw "找不到原始备份文件 OriginalGestalt.plist！"
            }
            
            if let liveDict = NSDictionary(contentsOf: MGURL.fsGestaltURL) {
                let ogBuild = mgDictToApply["CacheVersion"] as? String ?? ""
                let liveBuild = liveDict["CacheVersion"] as? String ?? ""
                if !ogBuild.isEmpty && !liveBuild.isEmpty && ogBuild != liveBuild {
                    Alertinator.shared.alert(
                        title: "已拦截跨系统版本还原！",
                        body: "原始备份来自旧版系统 (\(ogBuild))，与当前系统 (\(liveBuild)) 二进制缓存结构不同，直接覆盖可能导致异常。\n\n如需恢复当前系统的原厂状态，请关闭对应功能开关后点“应用”，或使用菜单中的“清除并重建缓存”并重启设备。",
                        showCancel: true
                    )
                    return
                }

                let ogUUID = mgDictToApply["CacheUUID"] as? String ?? ""
                let liveUUID = liveDict["CacheUUID"] as? String ?? ""
                if !ogUUID.isEmpty && !liveUUID.isEmpty && ogUUID.caseInsensitiveCompare(liveUUID) != .orderedSame {
                    Alertinator.shared.alert(
                        title: "已拦截不匹配的缓存布局还原！",
                        body: "原始备份的 CacheUUID (\(ogUUID)) 与当前设备系统 (\(liveUUID)) 不一致，直接覆盖存在白苹果与丢 eSIM 风险，安全护栏已阻止还原。",
                        showCancel: true
                    )
                    return
                }

                let ogCacheLen = (mgDictToApply["CacheData"] as? Data)?.count ?? 0
                let liveCacheLen = (liveDict["CacheData"] as? Data)?.count ?? 0
                if ogCacheLen > 0 && liveCacheLen > 0 && ogCacheLen != liveCacheLen {
                    Alertinator.shared.alert(
                        title: "已拦截长度不一致的二进制缓存还原！",
                        body: "原始备份的 CacheData 长度 (\(ogCacheLen) 字节) 与当前系统 (\(liveCacheLen) 字节) 不一致，直接写入会破坏基带与 eSIM 槽位，已强制拦截！",
                        showCancel: true
                    )
                    return
                }

                let ogExtra = mgDictToApply["CacheExtra"] as? NSDictionary
                let ogProd = ogExtra?[MGKey.prodType] as? String ?? ""
                let actualHW = currentOriginalMachineName()
                if !ogProd.isEmpty && !actualHW.isEmpty && ogProd != actualHW && ogProd != machineName() {
                    Alertinator.shared.alert(
                        title: "已拦截跨机型备份还原！",
                        body: "检测到该备份文件来自其他机型 (\(ogProd))，与当前设备硬件 (\(actualHW)) 不符（可能由旧机备份迁移带入），直接写入会导致白苹果软砖，已强制拦截！",
                        showCancel: true
                    )
                    return
                }
            }
            
            let data = try PropertyListSerialization.data(fromPropertyList: mgDictToApply, format: .binary, options: 0)
            let res = mgWriteDetailed(data)
            
            if res.0 {
                print("[*] successfully reverted and verified mobilegestalt!")
                Haptic.shared.play(.soft)
                store.mgCurrentDict = mgLoadData()
                Alertinator.shared.alert(title: "已还原并校验原始备份！", body: MGMsg.revertComp, actionLabel: "立即注销", action: { mgr.shouldRespring = true })
            } else {
                throw res.1
            }
        } catch {
            print("(mg) failed to revert mobilegestalt: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "还原 MobileGestalt 失败！", body: "\(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
