//
//  ConfigView.swift
//  Erosion
//
//  Created by lunginspector on 8/21/26.
//

import SwiftUI


enum CNURL {
    static var sharedDevConfig = FSURL.configProfiles.appendingPathComponent("SharedDeviceConfiguration.plist")
    static var cloudConfig = FSURL.configProfiles.appendingPathComponent("CloudConfigurationDetails.plist")
    static var cloudConfigBackup = URL.documentsDirectory.appendingPathComponent("OriginalCloudConfigurationDetails.plist")
}

enum CNMsg {
    static var supWarning = "在个人零售版 iOS 设备上强行写入 IsSupervised=true 极易触发 Setup.app 远程管理向导无限循环锁死（Setup Assistant Loop）甚至无法进入桌面！防白苹果护栏已永久禁用开启监管模式；如曾误开启过，可点击右上角恢复默认进行清理。"
    static var resetInfo = "点击“确认”后，将安全清除锁屏底部文字，并恢复或清理残留的监管配置文件。"
}

struct ConfigView: View {
    @EnvironmentObject private var mgr: ErosionManager
    @AppStorage("autoRespring") var autoRespring = false
    @State private var ftCurrentDict = NSMutableDictionary()
    @State private var ccCurrentDict = NSMutableDictionary()
    @State private var footnoteText = ""
    @State private var supervised = false
    @State private var orgName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "flashlight.off.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding()
                                .modifier(QuickActionBackground())
                            Spacer()
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding()
                                .modifier(QuickActionBackground())
                        }
                        .padding(.horizontal, 35)
                        
                        VStack {
                            Text(footnoteText)
                                .font(.system(size: 9))
                                .frame(height: 10)
                            Capsule()
                                .frame(width: 145, height: 4)
                        }
                    }
                    .padding(.top, 25)
                    .padding(.bottom, 10)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(
                        Group {
                            Image("solarium")
                                .resizable()
                                .scaledToFill()
                                .offset(y: 10)
                        }
                    )
                    
                    TextField("自定义锁屏底部文字", text: $footnoteText)
                }
                
                Section {
                    PlainToggle("开启监管模式（防设置向导死循环护栏已锁定）", infoType: .warning, infoTitle: "监管模式保护说明", infoMessage: CNMsg.supWarning, isOn: $supervised)
                        .disabled(true)
                } header: {
                    HeaderLabel("监管设置", symbol: "eye")
                }
            }
            .navigationTitle("系统配置与监管")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Alertinator.shared.alert(title: "确定要重置配置修改吗？", body: CNMsg.resetInfo, actionLabel: "确认", action: {
                            reset()
                        })
                    } label: {
                        Label("恢复默认", systemImage: "gobackward")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("应用", role: .adaptiveConfirm) {
                        apply()
                    }
                }
            }
            .onAppear {
                doSetup()
            }
        }
    }
    
    private func doSetup() {
        if !fm.isWritableFile(atPath: CNURL.sharedDevConfig.path) {
            let res = wq.grantAccess(path: FSURL.configProfiles.path)
            if !res.0 {
                Alertinator.shared.alert(title: "获取写入权限失败！", body: AppMsg.opFailed)
                return
            }
        }
        if UserDefaults.standard.object(forKey: "cn_cloud_config_originally_existed") == nil {
            let existed = fm.fileExists(atPath: CNURL.cloudConfig.path)
            UserDefaults.standard.set(existed, forKey: "cn_cloud_config_originally_existed")
            if existed && !fm.fileExists(atPath: CNURL.cloudConfigBackup.path) {
                try? fm.copyItem(at: CNURL.cloudConfig, to: CNURL.cloudConfigBackup)
                mgExcludeFromCloudBackup(CNURL.cloudConfigBackup)
            }
        }
        if !fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
            do {
                let dict = ["LockScreenFootnote" : ""]
                let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
                try data.write(to: CNURL.sharedDevConfig, options: .atomic)
            } catch {
                print("(cn) failed to create footnote file: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "创建锁屏文字配置文件失败！", body: AppMsg.opFailed)
            }
        }
        loadData()
    }
    
    private func loadData() {
        if let ftDict = NSMutableDictionary(contentsOf: CNURL.sharedDevConfig) {
            ftCurrentDict = ftDict
            footnoteText = ftDict["LockScreenFootnote"] as? String ?? ""
        }
        if let ccDict = NSMutableDictionary(contentsOf: CNURL.cloudConfig) {
            ccCurrentDict = ccDict
            supervised = ccDict["IsSupervised"] as? Bool ?? false
            orgName = ccDict["OrganizationName"] as? String ?? ""
        } else {
            supervised = false
            orgName = ""
        }
    }
    
    private func apply() {
        let ftDict = NSMutableDictionary(dictionary: ftCurrentDict)
        ftDict["LockScreenFootnote"] = footnoteText
        do {
            let ftData = try PropertyListSerialization.data(fromPropertyList: ftDict, format: .binary, options: 0)
            if fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
                let res = writeFileAtomically(ftData, to: CNURL.sharedDevConfig)
                if !res.0 {
                    throw res.1
                }
            } else {
                try ftData.write(to: CNURL.sharedDevConfig, options: .atomic)
            }
            print("(cn) successfully applied footnote tweak safely!")
            Haptic.shared.play(.soft)
            if autoRespring {
                mgr.shouldRespring = true
            } else {
                Alertinator.shared.alert(title: "系统配置修改已成功应用！", body: AppMsg.applied, actionLabel: "立即注销", action: { mgr.shouldRespring = true })
            }
        } catch {
            print("(cn) failed to write config files: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "应用修改失败！", body: "\(error.localizedDescription)")
        }
    }
    
    private func reset() {
        do {
            if fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
                try fm.removeItem(at: CNURL.sharedDevConfig)
            }
            let originallyExisted = UserDefaults.standard.bool(forKey: "cn_cloud_config_originally_existed")
            if originallyExisted, fm.fileExists(atPath: CNURL.cloudConfigBackup.path) {
                let backupData = try Data(contentsOf: CNURL.cloudConfigBackup)
                if fm.fileExists(atPath: CNURL.cloudConfig.path) {
                    let res = writeFileAtomically(backupData, to: CNURL.cloudConfig)
                    if !res.0 { throw res.1 }
                } else {
                    try backupData.write(to: CNURL.cloudConfig, options: .atomic)
                }
            } else if !originallyExisted && fm.fileExists(atPath: CNURL.cloudConfig.path) {
                // Remove spurious CloudConfigurationDetails.plist left on retail devices (SEC-M4-01)
                try fm.removeItem(at: CNURL.cloudConfig)
            }
            print("(cn) successfully reset config tweaks!")
            Haptic.shared.play(.soft)
            loadData()
            footnoteText = ""
            Alertinator.shared.alert(title: "系统配置修改已成功重置！", body: AppMsg.applied, actionLabel: "立即注销", action: { mgr.shouldRespring = true })
        } catch {
            print("(cn) failed to reset config files: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "重置修改失败！", body: "\(error.localizedDescription)")
        }
    }
}

// MARK: ui
struct QuickActionBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 19.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: .circle)
        }
    }
}
