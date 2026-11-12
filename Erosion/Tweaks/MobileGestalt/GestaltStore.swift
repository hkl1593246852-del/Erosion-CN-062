//
//  GestaltStore.swift
//  Erosion
//
//  Created by lunginspector on 8/19/26.
//

import SwiftUI

import Combine

enum MGURL {
    static let fsGestaltURL = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
    static let savedGestaltURL = URL.documentsDirectory.appendingPathComponent("OriginalGestalt.plist")
    static let savedGestaltSHA256URL = URL.documentsDirectory.appendingPathComponent("OriginalGestalt.sha256")
    static let preApplyGestaltURL = URL.documentsDirectory.appendingPathComponent("PreApplyGestalt.plist")
}

enum MGMsg {
    // warnings
    static let region = "开启后将自动把销售地区改为美版 (LL / LL/A) 并映射对应的美版监管型号 (Axxxx)，用于解锁国行/特定地区受限功能（如完整海外版 Apple 智能 + ChatGPT、快门静音等；注：台湾旗帜在简体中文系统字体下仍由 CoreText 拦截）。请遵守当地法律法规并自行承担使用风险。"
    static let ipadOS = "如果你当前设置了字母数字混合锁屏密码，请切勿开启此项！开启后也切勿关闭“在台前调度中显示程序坞”，否则会导致设备软砖（白苹果循环）。启用 iPadOS 界面后可能出现界面错位、部分应用不兼容等问题。"
    static let support = "请提前备份重要数据！如果某项修改未按预期生效，请勿向官方仓库提交支持请求。许多功能同时受限于设备硬件与 Apple 服务器策略，所有修改均需自行承担风险。"
    static let mgReset = "重置 MobileGestalt 将删除系统原始缓存文件并让系统在重启时重新生成。这有助于彻底清除无法还原的修改，但存在极低概率引发异常，请谨慎操作。"
    
    // info
    static let liquidGlass = "开启后将使用 iOS 26/27 液态玻璃 (Liquid Glass) 的低性能开销渲染模式，可降低 GPU 负载、减少机身发热并节省电量（注销或重启后生效）。"
    static let chinaCacheUnlock = "通过从本机内存加载的系统库 (libMobileGestalt.dylib) 实时动态解析二进制 CacheData 槽位偏移，将国行底层限制标记 green-tea 设为 false、not-green-tea 设为 true。\n\n• 可在国行设备上解锁 FaceTime 音频（语音通话）；\n• 在自带物理 eSIM 芯片的国行机型（如 iPhone 18 系列 / Air）上，可尝试解除系统层针对境外 eSIM 的地理围栏拦截（仍需硬件与运营商支持）。\n\n安全策略：仅当本机 CacheUUID、总长度、有效位及填充字节 100% 匹配通过时才允许修改；应用后请手动重启手机生效。"
    static let wapiToWifi = "通过本机系统库实时动态解析 wapi 布尔槽位偏移并设为 false，将系统“设置”与控制中心里的“无线局域网”统一显示为国际版的“Wi-Fi”。\n\n⚠️ 重要提示：开启后将会【丢失国行特有的“不允许联网”功能】（即“使用无线局域网与蜂窝网络的 App”中的“关闭”选项）！国际版逻辑仅允许单独关闭“蜂窝数据”，无法禁止单个应用使用 Wi-Fi 联网（如第三方输入法或离线应用将无法彻底断网），同时“启用 WAPI”开关也会隐藏。\n\n如需保留应用“不允许联网”权限控制，请保持此项关闭；若已开启，关闭此开关重新应用并手动重启手机即可原样恢复。"
    static let intInstall = "此选项将启用部分遗留在正式版 iOS 中的 Apple 内部调试特性。注意：开启后可能会影响部分正常功能（如无法从 App Store 重新安装自带系统应用），且与 Apple 智能互斥。"
    static let intBuild = "此开关主要用于在“设置”应用中显示内部存储调试信息。在部分设备（尤其是 iPadOS）上可能引发兼容性问题。"
    static let appleIntellInfo = "为不支持 Apple 智能的旧机型开启端侧生成式 AI 总开关 (DeviceSupportsGenerativeModelSystems)，并自动同步解锁以下 2 项在旧芯片上默认关闭的子能力标记：\n\n• 相册“消除”功能 (Photos Clean Up)\n• 备忘录“手写体合成” (Handwriting Synthesis)\n\n注：旧机型若需实际下载端侧 AI 模型，通常还需配合下方的“机型伪装”与上方的“解除地区限制”使用（修改后请手动重启手机生效）。"
    static let advAppleIntell = "一键解锁 2 项默认仅在最新代机型硬件设备树 (IODeviceTree:/product) 中开启的进阶端侧 AI 能力标记（在 iPhone 15 Pro / 16 / 17 系列上默认关闭；iPhone 18 系列硬件已原生开启，无需额外开启故默认不展示此选项）：\n\n1. 个人实时翻译 (Personal Translator)：解锁电话、FaceTime 与信息中的系统级实时同声传译及个人音色保留翻译能力；\n2. iOS 27 音频智能 (Audio Intelligence)：解锁语音备忘录与通话录音的端侧实时语音理解、流式智能摘要与环境人声分离能力。\n\n注：此开关仅解除 MobileGestalt 底层能力准入限制，实际运行仍取决于当前系统版本、地区设置及端侧模型状态（应用后请手动重启手机生效）。"
    static let spoofUseless = "伪装设备型号可能会导致面容 ID (Face ID) 等硬件功能失效！你的设备硬件本身已原生支持 Apple 智能，无需修改此项（国行设备只需开启上方“解除地区限制”即可）。"
    static let spoofAI = "对于不支持 Apple 智能的旧机型，仅开启开关无法下载端侧 AI 模型，还需伪装为支持的机型；但伪装机型可能导致面容 ID 失效。取消机型伪装后，请勿再次进入“设置 -> Apple 智能与 Siri”页面。"
    static let subtype = "仅在你想调整灵动岛纵向位置或屏幕分辨率特征时才修改设备子类型 (Subtype)。如需在非灵动岛机型开启灵动岛，请配合下方的“启用灵动岛”开关使用！"
    static let mgResetComp = "要完成 MobileGestalt 重置，请立即手动重启你的设备。"
    static let revertComp = "已恢复备份的原始 MobileGestalt 文件，建议重启一次设备以确保所有修改彻底还原。"

    // settings
    static let mgResetSavWarn = "重新生成原始备份前，请确保当前已还原所有修改，否则当前处于开启状态的修改会被写入新的原始备份中！"
    static let hidTweakWarn = "显示被隐藏的修改项后，你将能看到当前机型本已原生支持或不兼容的底层开关。盲目改动可能导致功能异常甚至数据丢失！"
}

enum MGKey {
    // bindings
    static let ipadosCacheEx = [
        "uKc7FPnEO++lVhHWHFlGbQ", // ipad
        "mG0AnH/Vy1veoqoLRAIgTA", // MedusaFloatingLiveAppCapability
        "UCG5MkVahJxG1YULbbd5Bg", // MedusaOverlayAppCapability
        "ZYqko/XM5zD3XBfN5RmaXA", // MedusaPinnedAppCapability
        "nVh/gwNpy7Jv1NOk00CMrw", // MedusaPIPCapability,
        "qeaj75wk3HF4DwQ8qbIi7g", // DeviceSupportsEnhancedMultitasking
    ]
    
    // hardware features
    static let island = "YlEtTtHlNesRBMal1CqRaA" // DeviceSupportsDynamicIsland
    static let AOTime = "j8/Omm6s1lsmTDFsXjsBfA" // DeviceSupportsAlwaysOnTime
    static let AOD = "2OOJf1VhaM7NxfRok3HbWQ" // DeviceSupportsAlwaysOnDisplay
    static let AODVibrancy = "ykpu7qyhqFweVMKtxNylWA" // DeviceSupportsAODVibrancy
    static let liquidGlassLowPower = "SAGvsp6O6kAQ4fEfDJpC4Q" // Liquid Glass Low-Power Rendering
    static let chargeLim = "37NVydb//GP/GrhuTN+exg" // DeviceSupports80ChargeLimit
    static let bootChime = "QHxt+hGLaBPbQJbXiUJX3w" // DeviceSupportsBootChime
    
    // internal
    static let intInstall = "EqrsVvjcYDdxHBiQmGhAWw" // apple-internal-install
    static let intBuild = "LBJfwOEzExRxzlAnSuI7eg" // InternalBuild
    
    // eligibility
    static let srd = "XYlJKKkj2hztRP1NWWnhlw" // ResearchFuse
    static let appIntell = "A62OafQ85EJAiiqKn4agtg" // DeviceSupportsGenerativeModelSystems
    static let photosCleanUp = "XNCjqOupLM/S8fNyxRNQTA" // Photos Clean Up
    static let handwritingSynth = "YgYIIViDt1kgzyIsIV61vA" // Handwriting Synthesis
    static let appIntellAllKeys = [
        "A62OafQ85EJAiiqKn4agtg", // DeviceSupportsGenerativeModelSystems
        "XNCjqOupLM/S8fNyxRNQTA", // Photos Clean Up
        "YgYIIViDt1kgzyIsIV61vA", // Handwriting Synthesis
    ]
    static let audioIntell = "rb2tKZxlj0Gm2tBmUQSLqQ" // supports-audio-intelligence
    static let personalTranslator = "M1n2sAqf33NAOgZRGxQYBA" // supports-personal-translator
    static let advAppIntellKeys = [
        "rb2tKZxlj0Gm2tBmUQSLqQ", // Audio Intelligence
        "M1n2sAqf33NAOgZRGxQYBA", // Personal Translator
    ]
    static let regionCode = "h63QSdBCiT/z0WU6rdQv6Q" // RegionCode
    static let regionInfo = "zHeENZu+wbg7PUprwNwBWg" // RegionInfo
    static let regionSysconfig = "yK+xavymRGZ3xWc1tb8XDg" // RegionInfoFromSysconfig
    static let regModelNumber = "97JDvERpVwO+GHtthIh7hA" // RegulatoryModelNumber
    
    // prefs
    static let crashDet = "HCzWusHQwZDea6nNhaKndw" // DeviceSupportsCollisionSOS
    static let pwm = "6IejgN+1Fmu5/QrZFOIeNw" // DeviceSupportsPulseWidthMaximization
    static let appPencil = "yhHcB0iH0d1XzPO/CFd3ow" // DeviceSupportsApplePencil
    static let camButton = "CwvKxM2cEogD3p+HYgaW0Q" // CameraButtonCapability
    static let grapPefr = "oOV1jhJbdV3AddkcCg0AEA" // apple-graphics-performance-tier
    static let actButton = "cT44WE1EohiwRzhsZ8xEsw" // RingerButtonCapability
    static let tapToWake = "yZf3GTRMGTuwSV/lD7Cagw" // DeviceSupportsTapToWake
    
    // ipados
    static let stageMgr = "qeaj75wk3HF4DwQ8qbIi7g" // DeviceSupportsEnhancedMultitasking
    
    // lookup
    static let deviceClass = "+3Uf0Pm5F8Xy7Onyvko0vA" // DeviceClass
    static let artwork = "oPeik/9e8lQWMszEjbPzng" // ArtworkTraits
    static let prodType = "h9jDsbgj7xIVeIQ8S3/X3Q" // ProductType
    static let modelNameOuter1 = "Z/dqyWS6OZTRy10UcmUAhw" // DeviceProductDescription
    static let modelNameOuter2 = "bbtR9jQx50Fv5Af/affNtA" // MarketingNameString
}

final class GestaltStore: ObservableObject {
    static let shared = GestaltStore()
    
    @Published var mgCurrentDict = NSMutableDictionary()
    var cacheExtra: NSMutableDictionary {
        return mgCurrentDict["CacheExtra"] as? NSMutableDictionary ?? NSMutableDictionary()
    }
    
    init() {}
    
    // MARK: helpers
    func originalCacheExtraValue(forKey key: String) -> Any? {
        guard let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
              let ogCacheExtra = ogDict["CacheExtra"] as? NSDictionary else {
            return nil
        }
        return ogCacheExtra[key]
    }
    
    func restoreOrRemoveKey(_ key: String) {
        if let ogVal = originalCacheExtraValue(forKey: key) {
            self.cacheExtra[key] = ogVal
        } else {
            self.cacheExtra.removeObject(forKey: key)
        }
    }
    
    // MARK: actions
    func mgPullKeys(_ keys: [String]) {
        for key in keys {
            restoreOrRemoveKey(key)
        }
    }
    
    func isEnabled(_ keys: [String], enableValue: Int = 1) -> Bool {
        guard !keys.isEmpty else { return false }
        return keys.allSatisfy { (self.cacheExtra[$0] as? Int) == enableValue }
    }
    
    func strVal(forKey key: String) -> String {
        let value = self.cacheExtra[key] as? String ?? ""
        return value
    }
    
    // MARK: bindings
    func mgKeyBinding(_ keys: [String], defaultValue: Int = 0, enableValue: Int = 1) -> Binding<Bool> {
        return Binding(get: {
            guard let firstKey = keys.first,
                  let value = self.cacheExtra[firstKey] as? Int else {
                return false
            }
            return value == enableValue
        }, set: { enabled in
            self.objectWillChange.send()
            for key in keys {
                if enabled {
                    self.cacheExtra[key] = enableValue
                } else {
                    self.restoreOrRemoveKey(key)
                }
            }
        })
    }
    
    func mgTrollPadBinding() -> Binding<Bool> {
        return Binding(get: {
            guard let firstKey = MGKey.ipadosCacheEx.first,
                  let value = self.cacheExtra[firstKey] as? Int else {
                return false
            }
            return value == 1
        }, set: { enabled in
            if enabled {
                Alertinator.shared.alert(
                    title: "安全护栏已拦截高危操作！",
                    body: "在 iPhone 上强制启用 iPadOS 界面需篡改未经验证的 CacheData 偏移，在锁屏密码或横竖屏切换时极易引发无限白苹果重启与触控冻结，防白苹果护栏已永久禁用该功能。"
                )
            } else {
                self.objectWillChange.send()
                for key in MGKey.ipadosCacheEx {
                    self.restoreOrRemoveKey(key)
                }
            }
        })
    }
    
    func mgRegionRestrictionsBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return self.cacheExtra[MGKey.regionCode] as? String == "LL" &&
                    self.cacheExtra[MGKey.regionSysconfig] as? String == "LL/A"
            },
            set: { enabled in
                self.objectWillChange.send()
                if enabled {
                    Alertinator.shared.alert(title: "解除地区限制提示", body: MGMsg.region)
                    self.cacheExtra[MGKey.regionCode] = "LL"
                    self.cacheExtra[MGKey.regionSysconfig] = "LL/A"
                    // Only write MGKey.regionInfo (zHeENZu+wbg7PUprwNwBWg) on iOS < 27 if present in factory CacheExtra.
                    // On iOS 27 (raveSupported()), zHeENZu+wbg7PUprwNwBWg has slot == -1 (non-cached);
                    // even if a previous third-party tool polluted OriginalGestalt.plist with it, always strip it on iOS 27
                    // so boot-time mobilegestaltd validation never invalidates or resets the cache.
                    if !raveSupported(), self.originalCacheExtraValue(forKey: MGKey.regionInfo) != nil {
                        self.cacheExtra[MGKey.regionInfo] = "LL/A"
                    } else {
                        self.cacheExtra.removeObject(forKey: MGKey.regionInfo)
                    }
                    
                    let prodType = (self.cacheExtra[MGKey.prodType] as? String) ?? currentOriginalMachineName()
                    let ogRegModel = (self.originalCacheExtraValue(forKey: MGKey.regModelNumber) as? String) ?? (self.cacheExtra[MGKey.regModelNumber] as? String) ?? ""
                    if let usModel = usRegulatoryModelNumber(productType: prodType, originalRegModel: ogRegModel) {
                        self.cacheExtra[MGKey.regModelNumber] = usModel
                    }
                } else {
                    self.restoreOrRemoveKey(MGKey.regionCode)
                    if raveSupported() {
                        self.cacheExtra.removeObject(forKey: MGKey.regionInfo)
                    } else {
                        self.restoreOrRemoveKey(MGKey.regionInfo)
                    }
                    self.restoreOrRemoveKey(MGKey.regionSysconfig)
                    self.restoreOrRemoveKey(MGKey.regModelNumber)
                }
            }
        )
    }
    
    func mgRegModelBinding() -> Binding<String> {
        return Binding<String>(
            get: {
                return self.cacheExtra[MGKey.regModelNumber] as? String ?? ""
            },
            set: { newValue in
                self.objectWillChange.send()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.restoreOrRemoveKey(MGKey.regModelNumber)
                } else {
                    self.cacheExtra[MGKey.regModelNumber] = trimmed
                }
            }
        )
    }

    // MARK: - Dynamic CacheData Resolution & Strictly Gated Bindings

    func canModifyGreenTeaCache() -> Bool {
        if case .success = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) {
            return true
        }
        return false
    }

    func canModifyWapiCache() -> Bool {
        if case .success((let layout, _)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict, checkWapiSlot: true),
           layout.wapiOffset != nil {
            return true
        }
        return false
    }

    func cacheResolutionFailureReason() -> String? {
        switch MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) {
        case .success:
            return nil
        case .failure(let err):
            return err.localizedDescription
        }
    }

    func mgChinaRestrictionCacheBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) else {
                    return false
                }
                return data[layout.greenTeaOffset] == 0 && data[layout.notGreenTeaOffset] == 1
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure(let err):
                    print("[!] (mg-cache) 拒绝修改 green-tea：\(err.localizedDescription)")
                    Alertinator.shared.alert(title: "动态解析失败，已拒绝修改！", body: err.localizedDescription)
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    if enabled {
                        data[layout.greenTeaOffset] = 0
                        data[layout.notGreenTeaOffset] = 1
                    } else {
                        if let orig = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig),
                           !(orig.greenTea == false && orig.notGreenTea == true) {
                            data[layout.greenTeaOffset] = orig.greenTea ? 1 : 0
                            data[layout.notGreenTeaOffset] = orig.notGreenTea ? 1 : 0
                        } else {
                            data[layout.greenTeaOffset] = 1
                            data[layout.notGreenTeaOffset] = 0
                        }
                    }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict) {
                    case .failure(let err):
                        print("[!] (mg-cache) 修改后自检未通过，拒绝修改：\(err.localizedDescription)")
                        Alertinator.shared.alert(title: "缓存数据校验未通过，已拒绝修改！", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func mgWapiWifiBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict, checkWapiSlot: true),
                      let wOff = layout.wapiOffset else {
                    return false
                }
                return data[wOff] == 0
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict, checkWapiSlot: true) {
                case .failure(let err):
                    print("[!] (mg-cache) 拒绝修改 wapi：\(err.localizedDescription)")
                    Alertinator.shared.alert(title: "动态解析失败，已拒绝修改！", body: err.localizedDescription)
                case .success((let layout, var data)):
                    guard let wOff = layout.wapiOffset else {
                        Alertinator.shared.alert(title: "动态解析失败，已拒绝修改！", body: "当前系统库未能唯一解析 wapi 槽位偏移。")
                        return
                    }
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    if enabled {
                        data[wOff] = 0
                    } else {
                        if let orig = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig),
                           let origWapi = orig.wapi,
                           origWapi == true {
                            data[wOff] = 1
                        } else {
                            data[wOff] = 1
                        }
                    }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict, checkWapiSlot: true) {
                    case .failure(let err):
                        print("[!] (mg-cache) 修改后自检未通过，拒绝修改：\(err.localizedDescription)")
                        Alertinator.shared.alert(title: "缓存数据校验未通过，已拒绝修改！", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        self.mgCurrentDict["CacheData"] = data
                        if enabled {
                            Alertinator.shared.alert(title: "无线局域网改 Wi-Fi 重要提示", body: MGMsg.wapiToWifi)
                        }
                    }
                }
            }
        )
    }
    
    // MARK: particular non-binded modifications
    // Disabled permanently by anti-bootloop security audit (SEC-M3-01): blind regex CacheData slicing causes soft-bricks.
    func mgSetiPadOS(enable: Bool) -> Bool {
        print("[!] (mg) blocked unsafe mgSetiPadOS regex CacheData mutation")
        return false
    }
}
