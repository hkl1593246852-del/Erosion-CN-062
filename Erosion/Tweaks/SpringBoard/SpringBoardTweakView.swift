//
//  SpringBoardTweakView.swift
//  Erosion
//
//  SpringBoard & UIKit animation speed and desktop behavior tweaks with safe backup and atomic write.
//

import SwiftUI

private enum SBTweakURL {
    static let prefsDir = URL(fileURLWithPath: "/var/mobile/Library/Preferences")
    static let sbPrefs = URL(fileURLWithPath: "/var/mobile/Library/Preferences/com.apple.springboard.plist")
    static let globalPrefs = URL(fileURLWithPath: "/var/mobile/Library/Preferences/.GlobalPreferences.plist")
    static let backupDir = URL.documentsDirectory.appendingPathComponent("SpringBoardBackup")
    static let sbBackup = URL.documentsDirectory.appendingPathComponent("SharedOriginal_com.apple.springboard.plist")
    static let globalBackup = URL.documentsDirectory.appendingPathComponent("SpringBoardBackup/Original_GlobalPreferences.plist")
}

struct SpringBoardTweakView: View {
    @EnvironmentObject private var mgr: ErosionManager
    @AppStorage("autoRespring") private var autoRespring = false
    @State private var isReady = false

    @State private var enableAnimSpeed = false
    @State private var animCoefficient: Double = 1.0

    @State private var hideLowPowerAlerts = false
    @State private var lockScreenDisableCC = false
    @State private var lockScreenDisableNC = false
    @State private var disableHomeRotation = false

    var body: some View {
        List {
            if !isReady {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在读取桌面与动画偏好设置...")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    PlainToggle(
                        "启用全局 UI 过渡动画调速",
                        subtitle: "调节 UIAnimationDragCoefficient 缩放系数",
                        infoType: .info,
                        infoTitle: "全局动画调速说明",
                        infoMessage: "通过向 com.apple.springboard.plist 与 .GlobalPreferences.plist 写入 UIAnimationDragCoefficient，调整系统应用打开/关闭与页面过渡动画时长。数值越小动画越快（1.0x 为原厂默认，0.5x 为两倍速，关闭即可恢复原厂动画时长）。",
                        isOn: $enableAnimSpeed
                    )

                    if enableAnimSpeed {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("当前动画时长系数")
                                Spacer()
                                Text(String(format: "%.2fx", animCoefficient))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                            Slider(value: $animCoefficient, in: 0.15...1.50, step: 0.05)

                            HStack(spacing: 8) {
                                ForEach([
                                    ("0.25x 瞬开", 0.25),
                                    ("0.50x 极速", 0.50),
                                    ("0.75x 轻快", 0.75),
                                    ("1.00x 默认", 1.00)
                                ], id: \.0) { item in
                                    Button {
                                        animCoefficient = item.1
                                    } label: {
                                        Text(item.0)
                                            .font(.caption)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(abs(animCoefficient - item.1) < 0.02 ? Color.accentColor.opacity(0.2) : Color(.secondarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HeaderLabel("系统动画速度", symbol: "hare")
                } footer: {
                    Text("推荐使用 0.50x～0.75x，兼顾丝滑视觉与极速响应。")
                }

                Section {
                    PlainToggle(
                        "屏蔽 20% / 10% 低电量弹窗打断",
                        subtitle: "游戏或全屏观影时不再弹出低电量模态框",
                        infoType: .info,
                        infoTitle: "屏蔽低电量弹窗说明",
                        infoMessage: "启用 SBHideLowPowerAlerts 后，电量降至 20% 或 10% 时不会再弹出阻断操作的全屏确认弹窗（状态栏电池图标仍会正常变色提醒）。",
                        isOn: $hideLowPowerAlerts
                    )
                    PlainToggle(
                        "锁屏界面禁止下拉控制中心",
                        subtitle: "防止设备遗失时被他人下拉开启飞行模式断网",
                        isOn: $lockScreenDisableCC
                    )
                    PlainToggle(
                        "锁屏界面禁止下拉通知中心",
                        subtitle: "未解锁时禁止下拉查看历史通知列表",
                        isOn: $lockScreenDisableNC
                    )
                    PlainToggle(
                        "锁定主屏幕桌面横屏旋转",
                        subtitle: "对应 SBDisableHomeScreenRotation（主要针对 Plus / Max / iPad）",
                        isOn: $disableHomeRotation
                    )
                } header: {
                    HeaderLabel("桌面与防打扰偏好", symbol: "sparkles.rectangle.stack")
                } footer: {
                    Text("点击右上角“应用”并注销设备后即可生效；随时可通过右上角重置按钮恢复默认。")
                }
            }
        }
        .navigationTitle("桌面与系统动画调优")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Alertinator.shared.alert(
                        title: "确定恢复默认桌面与动画设置吗？",
                        body: "将移除所有动画速度与桌面偏好修改，恢复系统默认行为。",
                        actionLabel: "确认恢复",
                        action: {
                            restoreDefaults()
                        }
                    )
                } label: {
                    Label("恢复默认", systemImage: "gobackward")
                        .labelStyle(.iconOnly)
                }
                .disabled(!isReady)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("应用", role: .adaptiveConfirm) {
                    applyChanges()
                }
                .disabled(!isReady)
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                loadCurrentState()
            }
        }
    }

    private func ensureBackupDir() {
        try? fm.createDirectory(at: SBTweakURL.backupDir, withIntermediateDirectories: true)
        mgExcludeFromCloudBackup(SBTweakURL.backupDir)
    }

    private func loadCurrentState() {
        ensureBackupDir()
        _ = wq.grantAccess(path: SBTweakURL.prefsDir.path)
        _ = wq.grantAccess(path: SBTweakURL.sbPrefs.path)
        _ = wq.grantAccess(path: SBTweakURL.globalPrefs.path)

        var loadedCoeff: Double? = nil
        var lowPower = false
        var noCC = false
        var noNC = false
        var noRot = false

        if let data = try? Data(contentsOf: SBTweakURL.sbPrefs),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            if let num = dict["UIAnimationDragCoefficient"] as? NSNumber {
                loadedCoeff = num.doubleValue
            }
            lowPower = (dict["SBHideLowPowerAlerts"] as? Bool) ?? false
            if let cc = dict["SBControlCenterEnabledInLockScreen"] as? Bool {
                noCC = !cc
            }
            if let nc = dict["SBNotificationCenterEnabledInLockScreen"] as? Bool {
                noNC = !nc
            }
            noRot = (dict["SBDisableHomeScreenRotation"] as? Bool) ?? false
        }

        if loadedCoeff == nil,
           let gData = try? Data(contentsOf: SBTweakURL.globalPrefs),
           let gDict = try? PropertyListSerialization.propertyList(from: gData, options: [], format: nil) as? [String: Any],
           let num = gDict["UIAnimationDragCoefficient"] as? NSNumber {
            loadedCoeff = num.doubleValue
        }

        DispatchQueue.main.async {
            if let coeff = loadedCoeff {
                self.enableAnimSpeed = true
                self.animCoefficient = min(max(coeff, 0.15), 1.50)
            } else {
                self.enableAnimSpeed = false
                self.animCoefficient = 0.75
            }
            self.hideLowPowerAlerts = lowPower
            self.lockScreenDisableCC = noCC
            self.lockScreenDisableNC = noNC
            self.disableHomeRotation = noRot
            self.isReady = true
        }
    }

    private func applyChanges() {
        ensureBackupDir()
        _ = wq.grantAccess(path: SBTweakURL.prefsDir.path)
        _ = wq.grantAccess(path: SBTweakURL.sbPrefs.path)
        _ = wq.grantAccess(path: SBTweakURL.globalPrefs.path)

        if fm.fileExists(atPath: SBTweakURL.sbPrefs.path) && !fm.fileExists(atPath: SBTweakURL.sbBackup.path) {
            try? fm.copyItem(at: SBTweakURL.sbPrefs, to: SBTweakURL.sbBackup)
            mgExcludeFromCloudBackup(SBTweakURL.sbBackup)
        }
        if fm.fileExists(atPath: SBTweakURL.globalPrefs.path) && !fm.fileExists(atPath: SBTweakURL.globalBackup.path) {
            try? fm.copyItem(at: SBTweakURL.globalPrefs, to: SBTweakURL.globalBackup)
            mgExcludeFromCloudBackup(SBTweakURL.globalBackup)
        }

        // 1. Update com.apple.springboard.plist
        var sbFormat: PropertyListSerialization.PropertyListFormat = .binary
        let sbDict: NSMutableDictionary
        if fm.fileExists(atPath: SBTweakURL.sbPrefs.path) {
            guard let data = try? Data(contentsOf: SBTweakURL.sbPrefs),
                  let parsed = try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: &sbFormat) as? NSMutableDictionary else {
                Alertinator.shared.alert(title: "安全护栏拦截！", body: "无法读取或解析现有的 com.apple.springboard.plist，为防止覆盖丢失原有桌面配置，已中止写入。")
                return
            }
            sbDict = parsed
        } else {
            sbDict = NSMutableDictionary()
        }

        var originalSBValues: [String: Any] = [:]
        if fm.fileExists(atPath: SBTweakURL.sbBackup.path),
           let ogData = try? Data(contentsOf: SBTweakURL.sbBackup),
           let ogDict = try? PropertyListSerialization.propertyList(from: ogData, options: [], format: nil) as? [String: Any] {
            originalSBValues = ogDict
        }
        func restoreOrRemoveSBKey(_ key: String) {
            if let ogVal = originalSBValues[key] {
                sbDict[key] = ogVal
            } else {
                sbDict.removeObject(forKey: key)
            }
        }

        if enableAnimSpeed {
            sbDict["UIAnimationDragCoefficient"] = Float(animCoefficient)
        } else {
            restoreOrRemoveSBKey("UIAnimationDragCoefficient")
        }

        if hideLowPowerAlerts {
            sbDict["SBHideLowPowerAlerts"] = true
        } else {
            restoreOrRemoveSBKey("SBHideLowPowerAlerts")
        }

        if lockScreenDisableCC {
            sbDict["SBControlCenterEnabledInLockScreen"] = false
        } else {
            restoreOrRemoveSBKey("SBControlCenterEnabledInLockScreen")
        }

        if lockScreenDisableNC {
            sbDict["SBNotificationCenterEnabledInLockScreen"] = false
        } else {
            restoreOrRemoveSBKey("SBNotificationCenterEnabledInLockScreen")
        }

        if disableHomeRotation {
            sbDict["SBDisableHomeScreenRotation"] = true
        } else {
            restoreOrRemoveSBKey("SBDisableHomeScreenRotation")
        }

        do {
            let sbData = try PropertyListSerialization.data(fromPropertyList: sbDict, format: sbFormat, options: 0)
            let res = fm.fileExists(atPath: SBTweakURL.sbPrefs.path)
                ? writeFileAtomically(sbData, to: SBTweakURL.sbPrefs)
                : writeFileTemp(sbData, to: SBTweakURL.sbPrefs)
            if !res.0 {
                Alertinator.shared.alert(title: "写入桌面配置失败！", body: res.1)
                return
            }
        } catch {
            Alertinator.shared.alert(title: "序列化桌面配置失败！", body: error.localizedDescription)
            return
        }

        // 2. Sync UIAnimationDragCoefficient to .GlobalPreferences.plist if readable/writable
        if fm.fileExists(atPath: SBTweakURL.globalPrefs.path) {
            var gFormat: PropertyListSerialization.PropertyListFormat = .binary
            if let gData = try? Data(contentsOf: SBTweakURL.globalPrefs),
               let gDict = try? PropertyListSerialization.propertyList(from: gData, options: [.mutableContainersAndLeaves], format: &gFormat) as? NSMutableDictionary {
                if enableAnimSpeed {
                    gDict["UIAnimationDragCoefficient"] = Float(animCoefficient)
                } else {
                    gDict.removeObject(forKey: "UIAnimationDragCoefficient")
                }
                if let outGData = try? PropertyListSerialization.data(fromPropertyList: gDict, format: gFormat, options: 0) {
                    _ = writeFileAtomically(outGData, to: SBTweakURL.globalPrefs)
                }
            }
        }

        Haptic.shared.play(.soft)
        if autoRespring {
            mgr.shouldRespring = true
        } else {
            Alertinator.shared.alert(
                title: "桌面与动画调优已写入！",
                body: "注销设备（Respring）后即可生效。是否立即注销？",
                actionLabel: "立即注销",
                action: {
                    mgr.shouldRespring = true
                }
            )
        }
    }

    private func restoreDefaults() {
        _ = wq.grantAccess(path: SBTweakURL.sbPrefs.path)
        _ = wq.grantAccess(path: SBTweakURL.globalPrefs.path)

        let managedKeys = [
            "UIAnimationDragCoefficient",
            "SBHideLowPowerAlerts",
            "SBControlCenterEnabledInLockScreen",
            "SBNotificationCenterEnabledInLockScreen",
            "SBDisableHomeScreenRotation"
        ]
        var originalSBValues: [String: Any] = [:]
        if fm.fileExists(atPath: SBTweakURL.sbBackup.path),
           let ogData = try? Data(contentsOf: SBTweakURL.sbBackup),
           let ogDict = try? PropertyListSerialization.propertyList(from: ogData, options: [], format: nil) as? [String: Any] {
            for key in managedKeys {
                if let val = ogDict[key] {
                    originalSBValues[key] = val
                }
            }
        }

        if fm.fileExists(atPath: SBTweakURL.sbPrefs.path) {
            var sbFormat: PropertyListSerialization.PropertyListFormat = .binary
            if let data = try? Data(contentsOf: SBTweakURL.sbPrefs),
               let dict = try? PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: &sbFormat) as? NSMutableDictionary {
                for key in managedKeys {
                    if let ogVal = originalSBValues[key] {
                        dict[key] = ogVal
                    } else {
                        dict.removeObject(forKey: key)
                    }
                }
                if let outData = try? PropertyListSerialization.data(fromPropertyList: dict, format: sbFormat, options: 0) {
                    _ = writeFileAtomically(outData, to: SBTweakURL.sbPrefs)
                }
            }
        }

        if fm.fileExists(atPath: SBTweakURL.globalPrefs.path) {
            var gFormat: PropertyListSerialization.PropertyListFormat = .binary
            if let gData = try? Data(contentsOf: SBTweakURL.globalPrefs),
               let gDict = try? PropertyListSerialization.propertyList(from: gData, options: [.mutableContainersAndLeaves], format: &gFormat) as? NSMutableDictionary {
                gDict.removeObject(forKey: "UIAnimationDragCoefficient")
                if let outGData = try? PropertyListSerialization.data(fromPropertyList: gDict, format: gFormat, options: 0) {
                    _ = writeFileAtomically(outGData, to: SBTweakURL.globalPrefs)
                }
            }
        }

        enableAnimSpeed = false
        animCoefficient = 1.0
        hideLowPowerAlerts = false
        lockScreenDisableCC = false
        lockScreenDisableNC = false
        disableHomeRotation = false

        Haptic.shared.play(.soft)
        Alertinator.shared.alert(
            title: "已恢复默认桌面与动画设置！",
            body: "是否立即注销（Respring）使恢复生效？",
            actionLabel: "立即注销",
            action: {
                mgr.shouldRespring = true
            }
        )
    }
}
