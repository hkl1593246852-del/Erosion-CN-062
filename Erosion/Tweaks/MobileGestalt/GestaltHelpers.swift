//
//  mg.swift
//  mond
//
//  Created by ruter on 16.07.26.
//

import Foundation
import CoreFoundation
import CryptoKit
import Darwin
import MachO
import UIKit

struct MGDiffItem: Identifiable {
    let id: String
    let label: String
    let keyPath: String
    let beforeText: String
    let afterText: String
}

func mgValidatePlistData(_ data: Data) -> (Bool, String) {
    guard data.count > 256 else {
        return (false, "待写入的 MobileGestalt 数据过小（\(data.count) 字节），已拦截写入。")
    }
    guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
          let dict = obj as? NSDictionary else {
        return (false, "待写入的数据不是合法的 Plist 字典，已拦截写入。")
    }
    guard let cacheExtra = dict["CacheExtra"] as? NSDictionary, cacheExtra.count > 0 else {
        return (false, "待写入的 Plist 缺少有效的 CacheExtra 字典，已拦截写入。")
    }
    guard let cacheData = dict["CacheData"] as? Data, !cacheData.isEmpty else {
        return (false, "待写入的 Plist 缺少有效的 CacheData 二进制段，已拦截写入。")
    }
    return (true, "ok")
}

func mgPlistValuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (nil, _), (_, nil):
        return false
    case (let a?, let b?):
        if let numA = a as? NSNumber, let numB = b as? NSNumber {
            let isBoolA = CFGetTypeID(numA) == CFBooleanGetTypeID()
            let isBoolB = CFGetTypeID(numB) == CFBooleanGetTypeID()
            if isBoolA != isBoolB { return false }
            if isBoolA { return numA.boolValue == numB.boolValue }
            let isFloatA = CFNumberIsFloatType(numA)
            let isFloatB = CFNumberIsFloatType(numB)
            if isFloatA != isFloatB { return false }
            return isFloatA ? (numA.doubleValue == numB.doubleValue) : (numA.stringValue == numB.stringValue)
        }
        if let strA = a as? String, let strB = b as? String { return strA == strB }
        if let dataA = a as? Data, let dataB = b as? Data { return dataA == dataB }
        if let dateA = a as? Date, let dateB = b as? Date { return dateA == dateB }
        if let arrA = a as? NSArray, let arrB = b as? NSArray {
            guard arrA.count == arrB.count else { return false }
            for idx in 0..<arrA.count where !mgPlistValuesEqual(arrA[idx], arrB[idx]) {
                return false
            }
            return true
        }
        if let dictA = a as? NSDictionary, let dictB = b as? NSDictionary {
            guard dictA.count == dictB.count else { return false }
            for (k, valA) in dictA {
                guard let keyStr = k as? String else { return dictA.isEqual(to: dictB as? [AnyHashable: Any] ?? [:]) }
                if !mgPlistValuesEqual(valA, dictB[keyStr]) { return false }
            }
            return true
        }
        return (a as AnyObject).isEqual(b)
    }
}

func mgFormatValue(_ val: Any?) -> String {
    guard let val else { return "（不存在 / 已移除）" }
    if let num = val as? NSNumber {
        if CFGetTypeID(num) == CFBooleanGetTypeID() {
            return num.boolValue ? "true (Bool)" : "false (Bool)"
        }
        if CFNumberIsFloatType(num) {
            return "\(num.doubleValue) (Float)"
        }
        return num.stringValue
    }
    if let str = val as? String { return str.isEmpty ? "\"\"" : str }
    if let data = val as? Data { return "<Data: \(data.count) 字节>" }
    if let arr = val as? NSArray {
        let items = arr.map { mgFormatValue($0) }.joined(separator: ", ")
        return "[\(items)]"
    }
    if let dict = val as? NSDictionary { return "<Dict: \(dict.count) 项>" }
    return String(describing: val)
}

func mgKeyDisplayName(_ key: String) -> String {
    let names: [String: String] = [
        MGKey.regionCode: "地区代码 (RegionCode)",
        MGKey.regionInfo: "销售地区 (RegionInfo)",
        MGKey.regionSysconfig: "系统销售地区 (RegionInfoFromSysconfig)",
        MGKey.regModelNumber: "监管型号 (RegulatoryModelNumber)",
        MGKey.appIntell: "Apple 智能总开关",
        MGKey.photosCleanUp: "相册“消除”功能 (Photos Clean Up)",
        MGKey.handwritingSynth: "备忘录手写体合成 (Handwriting Synthesis)",
        MGKey.audioIntell: "iOS 27 音频智能 (Audio Intelligence)",
        MGKey.personalTranslator: "个人实时翻译 (Personal Translator)",
        MGKey.liquidGlassLowPower: "液态玻璃低功耗渲染",
        MGKey.island: "灵动岛特性",
        MGKey.AOD: "全天候显示 (AOD)",
        MGKey.AOTime: "全天候显示时间",
        MGKey.AODVibrancy: "AOD 鲜艳度",
        MGKey.chargeLim: "80% 充电上限",
        MGKey.bootChime: "开关机提示音",
        MGKey.intInstall: "Apple 内部安装模式",
        MGKey.intBuild: "内部版本标识",
        MGKey.srd: "安全研究设备 (SRD)",
        MGKey.prodType: "机型标识符 (ProductType)",
        MGKey.modelNameOuter1: "设备产品名称",
        MGKey.modelNameOuter2: "设备市场名称",
        MGKey.crashDet: "车祸检测",
        MGKey.pwm: "PWM 调光开关",
        MGKey.appPencil: "Apple Pencil 支持",
        MGKey.camButton: "相机控制按键",
        MGKey.grapPefr: "图形性能等级",
        MGKey.actButton: "操作按钮",
        MGKey.tapToWake: "轻点唤醒",
        MGKey.stageMgr: "台前调度",
        "uKc7FPnEO++lVhHWHFlGbQ": "iPad 设备模式",
        "mG0AnH/Vy1veoqoLRAIgTA": "多任务浮动应用",
        "UCG5MkVahJxG1YULbbd5Bg": "多任务侧拉覆盖",
        "ZYqko/XM5zD3XBfN5RmaXA": "多任务固定分屏",
        "nVh/gwNpy7Jv1NOk00CMrw": "多任务画中画",
        "ArtworkDeviceSubType": "屏幕子类型 (Subtype)",
        "ArtworkDeviceProductDescription": "自定义机型名称"
    ]
    return names[key] ?? key
}

func mgComputeDiff(from beforeDict: NSDictionary, to afterDict: NSDictionary) -> [MGDiffItem] {
    var items: [MGDiffItem] = []

    let beforeCacheData = beforeDict["CacheData"] as? Data
    let afterCacheData = afterDict["CacheData"] as? Data
    if beforeCacheData != afterCacheData {
        let slotDiffs = MGCacheDataCoordinator.shared.diffDetails(from: beforeDict, to: afterDict)
        if !slotDiffs.isEmpty {
            for d in slotDiffs {
                items.append(MGDiffItem(
                    id: d.id,
                    label: d.label,
                    keyPath: d.keyPath,
                    beforeText: d.beforeText,
                    afterText: d.afterText
                ))
            }
        } else {
            items.append(MGDiffItem(
                id: "root.CacheData",
                label: "底层二进制缓存 (CacheData)",
                keyPath: "CacheData",
                beforeText: mgFormatValue(beforeCacheData),
                afterText: mgFormatValue(afterCacheData)
            ))
        }
    }

    let beforeExtra = beforeDict["CacheExtra"] as? NSDictionary ?? [:]
    let afterExtra = afterDict["CacheExtra"] as? NSDictionary ?? [:]
    var allKeys = Set<String>()
    for k in beforeExtra.allKeys { if let s = k as? String { allKeys.insert(s) } }
    for k in afterExtra.allKeys { if let s = k as? String { allKeys.insert(s) } }

    for key in allKeys.sorted() {
        let oldVal = beforeExtra[key]
        let newVal = afterExtra[key]
        if mgPlistValuesEqual(oldVal, newVal) { continue }

        if key == MGKey.artwork,
           let oldArt = oldVal as? NSDictionary,
           let newArt = newVal as? NSDictionary {
            var artKeys = Set<String>()
            for k in oldArt.allKeys { if let s = k as? String { artKeys.insert(s) } }
            for k in newArt.allKeys { if let s = k as? String { artKeys.insert(s) } }
            for aKey in artKeys.sorted() {
                if !mgPlistValuesEqual(oldArt[aKey], newArt[aKey]) {
                    items.append(MGDiffItem(
                        id: "Artwork.\(aKey)",
                        label: mgKeyDisplayName(aKey),
                        keyPath: "\(MGKey.artwork) → \(aKey)",
                        beforeText: mgFormatValue(oldArt[aKey]),
                        afterText: mgFormatValue(newArt[aKey])
                    ))
                }
            }
            continue
        }

        items.append(MGDiffItem(
            id: "CacheExtra.\(key)",
            label: mgKeyDisplayName(key),
            keyPath: key,
            beforeText: mgFormatValue(oldVal),
            afterText: mgFormatValue(newVal)
        ))
    }

    return items
}

func mgExcludeFromCloudBackup(_ url: URL) {
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? target.setResourceValues(values)
}

func mgComputeSHA256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

func mgSaveOriginalBackupWithDigest(_ data: Data) throws {
    try data.write(to: MGURL.savedGestaltURL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.savedGestaltURL)
    let hex = mgComputeSHA256Hex(data)
    try Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
}

func mgVerifyOriginalBackupIntegrity() -> (Bool, String) {
    guard let data = try? Data(contentsOf: MGURL.savedGestaltURL), !data.isEmpty else {
        return (false, "找不到或无法读取原始备份文件 OriginalGestalt.plist！")
    }
    let check = mgValidatePlistData(data)
    guard check.0 else {
        return (false, "原始备份文件结构已损坏：\(check.1)")
    }
    if FileManager.default.fileExists(atPath: MGURL.savedGestaltSHA256URL.path),
       let savedHexData = try? Data(contentsOf: MGURL.savedGestaltSHA256URL),
       let savedHex = String(data: savedHexData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       savedHex.count == 64 {
        let actualHex = mgComputeSHA256Hex(data)
        if actualHex.caseInsensitiveCompare(savedHex) != .orderedSame {
            return (false, "原始备份文件 SHA-256 完整性摘要校验未通过（预期 \(savedHex.prefix(12))...，实际 \(actualHex.prefix(12))...），可能已被意外篡改或损坏，已拦截还原！")
        }
    }
    return (true, "ok")
}

func mgIsDangerousCacheExtraKey(_ key: String) -> String? {
    let blocked: [String: String] = [
        "zHeENZu+wbg7PUprwNwBWg": "RegionInfo（iOS 27 非缓存键，注入将触发开机缓存重置）",
        "0L5PkT61qoH1b/B1USWqjQ": "RegionalBehaviorChinaBrick（非缓存硬件键，注入将触发开机重置）",
        "gD8SNRcHQeIxCAvsp+2vjA": "WSKU（无线电射频校准数据，篡改可致 Wi-Fi/蓝牙瘫痪）",
        "sFTm4FEVKVfdZ0ChdwQY1g": "WifiAntennaSKUVersion（天线校准参数，禁止篡改）",
        "91LyMcx4z1w3SGVeqteMnA": "BasebandRegionSKU（基带射频参数，篡改可致基带死锁）",
        "iyfxmLogGVIaH7aEgqwcIA": "green-tea（属于 CacheData 二进制槽位，禁止注入 CacheExtra）",
        "4snMZS8LJkSctKypt2m+xA": "not-green-tea（属于 CacheData 二进制槽位，禁止注入 CacheExtra）",
        "hiHut/WR+B9Lx/vd0WyeNg": "wapi（属于 CacheData 二进制槽位，禁止注入 CacheExtra）",
        "green-tea": "green-tea（明文冲突键，禁止注入 CacheExtra）",
        "not-green-tea": "not-green-tea（明文冲突键，禁止注入 CacheExtra）",
        "wapi": "wapi（明文冲突键，禁止注入 CacheExtra）",
        "CacheData": "顶层系统保留字段",
        "CacheUUID": "顶层系统保留字段",
        "CacheVersion": "顶层系统保留字段"
    ]
    return blocked[key]
}

func mgWriteDetailed(_ data: Data) -> (Bool, String) {
    let preCheck = mgValidatePlistData(data)
    guard preCheck.0 else {
        print("(mg) pre-write validation failed: \(preCheck.1)")
        return preCheck
    }

    guard let originalBytes = try? Data(contentsOf: MGURL.fsGestaltURL), !originalBytes.isEmpty else {
        let msg = "读取设备当前 MobileGestalt 原始文件失败（文件为空或无权限），已中止写入以保护系统！"
        print("(mg) \(msg)")
        return (false, msg)
    }

    // Strict pre-write CacheData transition verification against live on-disk plist
    if let liveDiskDict = try? PropertyListSerialization.propertyList(from: originalBytes, options: [], format: nil) as? NSDictionary,
       let targetDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary {
        if case .failure(let cacheErr) = MGCacheDataCoordinator.shared.validateTransition(from: liveDiskDict, to: targetDict) {
            print("[!] (mg) CacheData pre-write check rejected write: \(cacheErr.localizedDescription)")
            return (false, cacheErr.localizedDescription)
        }
    }

    // Save pre-apply snapshot before touching system file (excluded from iCloud/Finder device migration)
    try? originalBytes.write(to: MGURL.preApplyGestaltURL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.preApplyGestaltURL)

    // Unconditionally enforce safe in-place write (pwrite + tail truncate + F_FULLFSYNC) to preserve Inode & POSIX attributes
    let res = writeFileAtomically(data, to: MGURL.fsGestaltURL)
    if !res.0 {
        print("(mg) write failed: \(res.1)")
        return (false, "写入系统文件失败：\(res.1)")
    }

    // Full readback & plist structural/type verification
    do {
        let readbackBytes = try Data(contentsOf: MGURL.fsGestaltURL)
        let readbackCheck = mgValidatePlistData(readbackBytes)
        guard readbackBytes == data,
              readbackCheck.0,
              let expectedDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary,
              let actualDict = try PropertyListSerialization.propertyList(from: readbackBytes, options: [], format: nil) as? NSDictionary,
              mgPlistValuesEqual(expectedDict, actualDict) else {
            throw NSError(domain: "Erosion.MGVerify", code: -1, userInfo: [NSLocalizedDescriptionKey: "磁盘读回数据与预期键值/类型不一致"])
        }
        print("(mg) readback verified (\(readbackBytes.count) bytes)")
        return (true, "succeeded")
    } catch {
        print("(mg) readback verification failed (\(error.localizedDescription))! Rolling back previous bytes...")
        let rollbackOK = writeFileAtomically(originalBytes, to: MGURL.fsGestaltURL).0
        let verifiedRollback = ((try? Data(contentsOf: MGURL.fsGestaltURL)) == originalBytes)
        if rollbackOK && verifiedRollback {
            return (false, "写后读回校验未通过（\(error.localizedDescription)），已自动原位安全回滚至修改前状态！")
        } else {
            return (false, "写后读回校验失败且自动回滚异常，请勿重启并前往高级设置检查缓存！")
        }
    }
}

func mgWrite(_ data: Data) -> Bool {
    return mgWriteDetailed(data).0
}

func currentOriginalMachineName() -> String {
    if let saved = UserDefaults.standard.string(forKey: "ogMachineName"), !saved.isEmpty {
        return saved
    }
    return machineName()
}

/// Maps Mainland China / International models & ProductTypes to US (LL/A) RegulatoryModelNumber (97JDvERpVwO+GHtthIh7hA)
func usRegulatoryModelNumber(productType: String, originalRegModel: String = "") -> String? {
    let regModelMap: [String: String] = [
        // iPhone 18 / Duo Series (China / HK / Intl -> US)
        "A3718": "A3473", "A3717": "A3473", "A3716": "A3473", // iPhone 18 Pro Max -> US A3473
        "A3715": "A3472", "A3714": "A3472", "A3713": "A3472", // iPhone 18 Pro -> US A3472
        "A3721": "A3447", "A3720": "A3447", "A3719": "A3447", // iPhone Duo -> US A3447
        // iPhone 17 / Air / 17e Series
        "A3520": "A3258", "A3519": "A3258",                   // iPhone 17 -> US A3258
        "A3523": "A3256", "A3522": "A3256",                   // iPhone 17 Pro -> US A3256
        "A3526": "A3257", "A3525": "A3257",                   // iPhone 17 Pro Max -> US A3257
        "A3518": "A3260", "A3517": "A3260",                   // iPhone Air -> US A3260
        "A3635": "A3575", "A3634": "A3575",                   // iPhone 17e -> US A3575
        // iPhone 16 / 16e Series
        "A3288": "A3081", "A3287": "A3081",                   // iPhone 16 -> US A3081
        "A3291": "A3082", "A3290": "A3082",                   // iPhone 16 Plus -> US A3082
        "A3294": "A3083", "A3293": "A3083",                   // iPhone 16 Pro -> US A3083
        "A3297": "A3084", "A3296": "A3084",                   // iPhone 16 Pro Max -> US A3084
        "A3410": "A3212", "A3409": "A3212",                   // iPhone 16e -> US A3212
        // iPhone 15 Series
        "A3092": "A2846", "A3090": "A2846",                   // iPhone 15 -> US A2846
        "A3096": "A2847", "A3094": "A2847",                   // iPhone 15 Plus -> US A2847
        "A3104": "A2848", "A3102": "A2848",                   // iPhone 15 Pro -> US A2848
        "A3108": "A2849", "A3106": "A2849"                    // iPhone 15 Pro Max -> US A2849
    ]
    
    if let mapped = regModelMap[originalRegModel] {
        return mapped
    }
    
    let productTypeMap: [String: String] = [
        // iPhone 14 Series
        "iPhone14,7": "A2649",
        "iPhone14,8": "A2632",
        "iPhone15,2": "A2650",
        "iPhone15,3": "A2651",
        // iPhone 15 Series
        "iPhone15,4": "A2846",
        "iPhone15,5": "A2847",
        "iPhone16,1": "A2848",
        "iPhone16,2": "A2849",
        // iPhone 16 Series
        "iPhone17,1": "A3083",
        "iPhone17,2": "A3084",
        "iPhone17,3": "A3081",
        "iPhone17,4": "A3082",
        "iPhone17,5": "A3212",
        // iPhone 17 / Air / 17e Series
        "iPhone18,1": "A3256",
        "iPhone18,2": "A3257",
        "iPhone18,3": "A3258",
        "iPhone18,4": "A3260",
        "iPhone18,5": "A3575",
        // iPhone 18 / Duo Series (including regional/China board ProductTypes)
        "iPhone19,1": "A3471",
        "iPhone19,2": "A3472",
        "iPhone19,3": "A3473",
        "iPhone19,4": "A3447",
        "iPhone19,5": "A3471",
        "iPhone19,6": "A3472",
        "iPhone19,7": "A3473",
        "iPhone19,8": "A3447",
        // Apple Intelligence iPads
        "iPad13,4": "A2377", "iPad13,5": "A2301", "iPad13,6": "A2301", "iPad13,7": "A2301",
        "iPad13,8": "A2378", "iPad13,9": "A2379", "iPad13,10": "A2379", "iPad13,11": "A2379",
        "iPad13,16": "A2588", "iPad13,17": "A2589",
        "iPad14,3": "A2759", "iPad14,4": "A2435",
        "iPad14,5": "A2436", "iPad14,6": "A2764",
        "iPad14,8": "A2902", "iPad14,9": "A2903",
        "iPad14,10": "A2898", "iPad14,11": "A2899",
        "iPad15,3": "A3266", "iPad15,4": "A3267",
        "iPad15,5": "A3268", "iPad15,6": "A3269",
        "iPad16,1": "A2993", "iPad16,2": "A2995",
        "iPad16,3": "A2836", "iPad16,4": "A2837",
        "iPad16,5": "A2925", "iPad16,6": "A2926"
    ]
    
    return productTypeMap[productType]
}

// device info getters
// HD - hardware device
func isDynamIslandHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isAODHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isChargeLimitHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5", "iPad16,1", "iPad16,2", "iPad15,7", "iPad15,8", "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11", "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6", "iPad16,8", "iPad16,9", "iPad16,10", "iPad16,11", "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6", "iPad17,1", "iPad17,2", "iPad17,3", "iPad17,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isBootChimeHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isHomeButtonHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices: [String] = ["iPhone12,8", "iPhone14,6"]
    return hdDevices.contains(m)
}

// fun...
func isAppleIntellHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5", "iPad16,1", "iPad16,2", "iPad13,16", "iPad13,17", "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11", "iPad14,3", "iPad14,4", "iPad14,5", "iPad14,6", "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11", "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6", "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6", "iPad16,8", "iPad16,9", "iPad16,10", "iPad16,11", "iPad17,1", "iPad17,2", "iPad17,3", "iPad17,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isAdvAppleIntellHD() -> Bool {
    let m = currentOriginalMachineName()
    return m.hasPrefix("iPhone19,")
}

func isCrashDectHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isPWMHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isCamControlHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isActionButtonHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}
