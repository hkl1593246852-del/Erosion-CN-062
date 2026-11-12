//
//  MGCacheLayout.swift
//  Erosion
//
//  Strict runtime MobileGestalt CacheData descriptor resolver and byte-level validator.
//  Resolves offsets exclusively from the running device's loaded /usr/lib/libMobileGestalt.dylib.
//  Any ambiguity, mismatch, or validation failure strictly blocks modification.
//

import Foundation

struct MGCacheDataLayout: Codable, Equatable, Sendable {
    static let greenTeaKey = "iyfxmLogGVIaH7aEgqwcIA"      // green-tea
    static let notGreenTeaKey = "4snMZS8LJkSctKypt2m+xA"   // not-green-tea
    static let wapiKey = "hiHut/WR+B9Lx/vd0WyeNg"          // wapi (WLAN vs Wi-Fi)

    let uuid: String
    let slotCount: Int
    let greenTeaIndex: Int
    let notGreenTeaIndex: Int
    let wapiIndex: Int?

    var byteCount: Int { slotCount * 9 }
    var greenTeaOffset: Int { greenTeaIndex * 8 }
    var notGreenTeaOffset: Int { notGreenTeaIndex * 8 }
    var wapiOffset: Int? { wapiIndex.map { $0 * 8 } }

    func validityOffset(for slotIndex: Int) -> Int {
        return slotCount * 8 + slotIndex
    }

    var permittedMutableOffsets: Set<Int> {
        var set: Set<Int> = [greenTeaOffset, notGreenTeaOffset]
        if let wOff = wapiOffset {
            set.insert(wOff)
        }
        return set
    }

    // MARK: - Pure Runtime Descriptor Scanner (Zero Hardcoded Fallbacks)

    static func resolveFromLoadedLibrary() -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        #if os(iOS) && !targetEnvironment(simulator)
        guard let image = MGCopyLoadedMobileGestaltImage() else {
            return .failure(.libraryUnavailable("无法从内存只读加载 /usr/lib/libMobileGestalt.dylib 段数据。"))
        }
        return scan(image: image)
        #else
        return .failure(.libraryUnavailable("当前运行环境不是 iOS 实机，已禁用二进制 CacheData 修改。"))
        #endif
    }

    static func scan(image: [String: Any]) -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        guard let strings = image["strings"] as? Data,
              let addressNum = image["stringAddress"] as? NSNumber,
              let constants = image["constants"] as? [Data] else {
            return .failure(.malformedImage("系统库镜像缺少必要的 __cstring 或 __const 段数据。"))
        }
        let extraUUIDs = (image["cfUUIDs"] as? [String]) ?? []
        return scan(
            strings: strings,
            stringAddress: addressNum.uint64Value,
            constants: constants,
            extraUUIDs: extraUUIDs
        )
    }

    /// Scans modern 64-byte MobileGestalt query descriptors:
    /// +0x00: pointer to 22-char obfuscated key string (canonical 48-bit user VA)
    /// +0x3A: signed Int16 cache slot index
    /// +0x3C: UInt32 query type (11 = Boolean)
    static func scan(
        strings: Data,
        stringAddress: UInt64,
        constants: [Data],
        extraUUIDs: [String] = []
    ) -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        guard !strings.isEmpty,
              strings.count <= 32 * 1024 * 1024,
              stringAddress > 0,
              stringAddress <= UInt64.max - UInt64(strings.count),
              !constants.isEmpty,
              constants.count <= 8,
              constants.allSatisfy({ $0.count <= 32 * 1024 * 1024 }) else {
            return .failure(.malformedImage("系统库段大小或地址范围异常，已拒绝解析。"))
        }

        var hashByAddress: [UInt64: String] = [:]
        var discoveredUUIDs = Set<String>()

        for u in extraUUIDs {
            if u.count == 36, let parsed = UUID(uuidString: u) {
                discoveredUUIDs.insert(parsed.uuidString.uppercased())
            }
        }

        strings.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = rawBuf.count
            var tokenStart = 0
            for idx in 0..<count where base[idx] == 0 {
                let len = idx - tokenStart
                if len == 22 {
                    var valid = true
                    for k in tokenStart..<idx {
                        let b = base[k]
                        if !((65...90).contains(b) || (97...122).contains(b) || (48...57).contains(b) || b == 43 || b == 47) {
                            valid = false
                            break
                        }
                    }
                    if valid {
                        let slice = UnsafeBufferPointer(start: base.advanced(by: tokenStart), count: 22)
                        hashByAddress[stringAddress + UInt64(tokenStart)] = String(decoding: slice, as: UTF8.self)
                    }
                } else if len == 36 {
                    let slice = UnsafeBufferPointer(start: base.advanced(by: tokenStart), count: 36)
                    if let text = String(bytes: slice, encoding: .utf8),
                       let parsedUUID = UUID(uuidString: text) {
                        discoveredUUIDs.insert(parsedUUID.uuidString.uppercased())
                    }
                }
                tokenStart = idx + 1
            }
        }

        guard !discoveredUUIDs.isEmpty else {
            return .failure(.uuidNotFound("未能在系统库中找到唯一的 CacheUUID 标识，已拒绝修改。"))
        }
        guard discoveredUUIDs.count == 1, let resolvedUUID = discoveredUUIDs.first else {
            return .failure(.ambiguousUUID("系统库中发现多个 UUID 候选（\(discoveredUUIDs.count) 个），拒绝猜测偏移！"))
        }

        var positiveIndices = Set<Int>()
        var targetIndices: [String: Set<Int>] = [:]
        var targetAlignments: [String: Set<String>] = [:]
        let watchedKeys: Set<String> = [greenTeaKey, notGreenTeaKey, wapiKey]

        for (secID, secData) in constants.enumerated() where secData.count >= 64 {
            let scanErr: MGCacheResolutionError? = secData.withUnsafeBytes { raw -> MGCacheResolutionError? in
                for off in stride(from: 0, through: secData.count - 64, by: 8) {
                    let rawPtr = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off, as: UInt64.self))
                    // Darwin arm64e userland VA space is 47-bit (0x0000_7FFF_FFFF_FFFF); strip bits 63:47 PAC tags
                    let canonicalPtr = rawPtr & 0x0000_7FFF_FFFF_FFFF
                    guard let key = hashByAddress[canonicalPtr] else { continue }

                    let slotIdx = Int(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3A, as: Int16.self)))
                    let queryType = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3C, as: UInt32.self))
                    guard (-1..<16384).contains(slotIdx), (1...11).contains(queryType) else { continue }

                    if slotIdx >= 0 {
                        positiveIndices.insert(slotIdx)
                    }

                    if watchedKeys.contains(key) {
                        guard queryType == 11, slotIdx >= 0 else {
                            return .invalidTargetDescriptor("目标键 \(key) 的描述符类型 (\(queryType)) 或槽位 (\(slotIdx)) 非有效布尔缓存项。")
                        }
                        targetIndices[key, default: []].insert(slotIdx)
                        targetAlignments[key, default: []].insert("\(secID):\(off % 64)")
                    }
                }
                return nil
            }
            if let scanErr {
                return .failure(scanErr)
            }
        }

        guard let maxSlotIndex = positiveIndices.max(), maxSlotIndex >= 1 else {
            return .failure(.descriptorTableNotFound("未能在系统库中定位有效的 MobileGestalt 查询描述符表。"))
        }
        let slotCount = maxSlotIndex + 1
        guard positiveIndices.count > slotCount / 2 else {
            return .failure(.sparseDescriptorTable("描述符表槽位覆盖率异常（\(positiveIndices.count)/\(slotCount)），已拒绝解析。"))
        }

        guard let gtSet = targetIndices[greenTeaKey], gtSet.count == 1, let gtIdx = gtSet.first,
              let ngtSet = targetIndices[notGreenTeaKey], ngtSet.count == 1, let ngtIdx = ngtSet.first,
              gtIdx != ngtIdx,
              (0..<slotCount).contains(gtIdx),
              (0..<slotCount).contains(ngtIdx),
              let gtAlign = targetAlignments[greenTeaKey], gtAlign.count == 1,
              gtAlign == targetAlignments[notGreenTeaKey] else {
            return .failure(.invalidTargetDescriptor("无法唯一确定 green-tea / not-green-tea 的缓存槽位或表对齐不一致，已拒绝修改。"))
        }

        var resolvedWapiIdx: Int? = nil
        if let wapiSet = targetIndices[wapiKey] {
            guard wapiSet.count == 1,
                  let wIdx = wapiSet.first,
                  (0..<slotCount).contains(wIdx),
                  wIdx != gtIdx,
                  wIdx != ngtIdx,
                  targetAlignments[wapiKey] == gtAlign else {
                return .failure(.invalidTargetDescriptor("wapi 描述符存在歧义或对齐不一致，已拒绝解析。"))
            }
            resolvedWapiIdx = wIdx
        }

        return .success(
            MGCacheDataLayout(
                uuid: resolvedUUID,
                slotCount: slotCount,
                greenTeaIndex: gtIdx,
                notGreenTeaIndex: ngtIdx,
                wapiIndex: resolvedWapiIdx
            )
        )
    }

    // MARK: - Strict Plist & Byte-Level Verification

    func validatePlist(_ dict: NSDictionary, checkWapiSlot: Bool = false) -> Result<Data, MGCacheResolutionError> {
        guard (1...16384).contains(slotCount),
              (0..<slotCount).contains(greenTeaIndex),
              (0..<slotCount).contains(notGreenTeaIndex),
              greenTeaIndex != notGreenTeaIndex else {
            return .failure(.invalidTargetDescriptor("缓存槽位索引超出合法范围。"))
        }

        guard let plistUUID = dict["CacheUUID"] as? String, !plistUUID.isEmpty else {
            return .failure(.plistMismatch("MobileGestalt 文件缺少 CacheUUID 字段，拒绝修改。"))
        }
        guard plistUUID.caseInsensitiveCompare(uuid) == .orderedSame else {
            return .failure(.plistMismatch("缓存文件 CacheUUID (\(plistUUID)) 与本机系统库 (\(uuid)) 不一致，拒绝修改！"))
        }

        guard let cacheData = dict["CacheData"] as? Data else {
            return .failure(.plistMismatch("MobileGestalt 文件缺少二进制 CacheData 字段，拒绝修改。"))
        }
        guard cacheData.count == byteCount else {
            return .failure(.plistMismatch("CacheData 长度 (\(cacheData.count) 字节) 与系统库计算的精确长度 (\(byteCount) 字节，\(slotCount) 槽位) 不一致，拒绝修改！"))
        }

        var slotsToVerify = [greenTeaIndex, notGreenTeaIndex]
        if let wIdx = wapiIndex {
            if checkWapiSlot || validateSingleBooleanSlot(wIdx, in: cacheData) {
                slotsToVerify.append(wIdx)
            }
        } else if checkWapiSlot {
            return .failure(.invalidTargetDescriptor("当前系统库未解析出有效的 wapi 槽位，拒绝修改该项。"))
        }

        for slotIdx in slotsToVerify {
            let valOff = slotIdx * 8
            let validOff = validityOffset(for: slotIdx)
            guard validOff < cacheData.count, valOff + 8 <= cacheData.count else {
                return .failure(.plistMismatch("槽位 \(slotIdx) 偏移越界，拒绝修改。"))
            }
            guard cacheData[validOff] == 1 else {
                return .failure(.slotInvalid("槽位 \(slotIdx)（有效位偏移 0x\(String(format: "%X", validOff))）未被系统标记为有效 (validity != 1)，拒绝修改！"))
            }
            guard cacheData[valOff] <= 1 else {
                return .failure(.slotInvalid("槽位 \(slotIdx)（偏移 0x\(String(format: "%X", valOff))）当前字节值 (\(cacheData[valOff])) 不是合法布尔值 (0/1)，拒绝修改！"))
            }
            for pad in (valOff + 1)..<(valOff + 8) {
                guard cacheData[pad] == 0 else {
                    return .failure(.slotInvalid("槽位 \(slotIdx) 填充字节非零（偏移 0x\(String(format: "%X", pad)) = \(cacheData[pad])），拒绝修改！"))
                }
            }
        }

        if let extra = dict["CacheExtra"] as? NSDictionary {
            var forbiddenKeys = [Self.greenTeaKey, Self.notGreenTeaKey, "green-tea", "not-green-tea"]
            if checkWapiSlot {
                forbiddenKeys.append(contentsOf: [Self.wapiKey, "wapi"])
            }
            for k in forbiddenKeys where extra[k] != nil {
                return .failure(.conflictingCacheExtra("检测到 CacheExtra 中已存在覆盖键 \(k)，为确保安全已拒绝修改 CacheData。"))
            }
        }

        return .success(cacheData)
    }

    func validateSingleBooleanSlot(_ slotIdx: Int, in cacheData: Data) -> Bool {
        let valOff = slotIdx * 8
        let validOff = validityOffset(for: slotIdx)
        guard cacheData.count == byteCount,
              (0..<slotCount).contains(slotIdx),
              validOff < cacheData.count,
              valOff + 8 <= cacheData.count,
              cacheData[validOff] == 1,
              cacheData[valOff] <= 1 else {
            return false
        }
        return cacheData[(valOff + 1)..<(valOff + 8)].allSatisfy { $0 == 0 }
    }
}

enum MGCacheResolutionError: LocalizedError, Equatable {
    case libraryUnavailable(String)
    case malformedImage(String)
    case uuidNotFound(String)
    case ambiguousUUID(String)
    case descriptorTableNotFound(String)
    case sparseDescriptorTable(String)
    case invalidTargetDescriptor(String)
    case plistMismatch(String)
    case slotInvalid(String)
    case conflictingCacheExtra(String)
    case unauthorizedByteMutation(String)

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable(let m),
             .malformedImage(let m),
             .uuidNotFound(let m),
             .ambiguousUUID(let m),
             .descriptorTableNotFound(let m),
             .sparseDescriptorTable(let m),
             .invalidTargetDescriptor(let m),
             .plistMismatch(let m),
             .slotInvalid(let m),
             .conflictingCacheExtra(let m),
             .unauthorizedByteMutation(let m):
            return m
        }
    }
}

// MARK: - Original Per-UUID Flag Snapshot & Runtime Coordinator

struct MGCacheRecordedFlags: Codable, Equatable {
    let layoutUUID: String
    let cacheVersion: String
    let greenTea: Bool
    let notGreenTea: Bool
    let wapi: Bool?
}

struct MGCacheDataDiffDetail {
    let id: String
    let label: String
    let keyPath: String
    let beforeText: String
    let afterText: String
}

final class MGCacheDataCoordinator {
    static let shared = MGCacheDataCoordinator()

    private let defaultsKey = "mgRecordedOriginalCacheFlagsByUUID_v1"
    private let lock = NSLock()
    private var cachedVerifiedLayout: MGCacheDataLayout?

    private init() {}

    func libraryLayout() -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        lock.lock()
        if let existing = cachedVerifiedLayout {
            lock.unlock()
            return .success(existing)
        }
        lock.unlock()

        let resolved = MGCacheDataLayout.resolveFromLoadedLibrary()
        if case .success(let layout) = resolved {
            lock.lock()
            cachedVerifiedLayout = layout
            lock.unlock()
        }
        return resolved
    }

    /// Resolves layout from live libMobileGestalt.dylib AND validates against the given plist dictionary.
    func resolveValidated(for dict: NSDictionary, checkWapiSlot: Bool = false) -> Result<(MGCacheDataLayout, Data), MGCacheResolutionError> {
        switch libraryLayout() {
        case .failure(let err):
            return .failure(err)
        case .success(let layout):
            switch layout.validatePlist(dict, checkWapiSlot: checkWapiSlot) {
            case .failure(let err):
                return .failure(err)
            case .success(let data):
                return .success((layout, data))
            }
        }
    }

    /// Records the earliest observed valid flags for a CacheUUID (preferring OriginalGestalt.plist if its UUID matches).
    func recordBaselineIfNeeded(liveDict: NSDictionary, savedOriginalDict: NSDictionary?) {
        // Prefer OriginalGestalt.plist if it matches this exact CacheUUID & layout
        if let saved = savedOriginalDict,
           case .success((let layout, let savedData)) = resolveValidated(for: saved) {
            saveInitialFlagsIfAbsent(from: saved, data: savedData, layout: layout)
            return
        }
        if case .success((let layout, let liveData)) = resolveValidated(for: liveDict) {
            saveInitialFlagsIfAbsent(from: liveDict, data: liveData, layout: layout)
        }
    }

    private func saveInitialFlagsIfAbsent(from dict: NSDictionary, data: Data, layout: MGCacheDataLayout) {
        lock.lock()
        defer { lock.unlock() }
        var map = loadRecordedMap()
        let key = layout.uuid.uppercased()
        guard map[key] == nil else { return }

        let gt = data[layout.greenTeaOffset] == 1
        let ngt = data[layout.notGreenTeaOffset] == 1
        var wapiVal: Bool? = nil
        if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: data) {
            wapiVal = (data[wIdx * 8] == 1)
        }
        let build = dict["CacheVersion"] as? String ?? ""
        map[key] = MGCacheRecordedFlags(
            layoutUUID: key,
            cacheVersion: build,
            greenTea: gt,
            notGreenTea: ngt,
            wapi: wapiVal
        )
        saveRecordedMap(map)
    }

    func originalFlags(for layout: MGCacheDataLayout, savedOriginalDict: NSDictionary?) -> MGCacheRecordedFlags? {
        if let saved = savedOriginalDict,
           case .success(let savedData) = layout.validatePlist(saved) {
            let gt = savedData[layout.greenTeaOffset] == 1
            let ngt = savedData[layout.notGreenTeaOffset] == 1
            var wVal: Bool? = nil
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: savedData) {
                wVal = (savedData[wIdx * 8] == 1)
            }
            let build = saved["CacheVersion"] as? String ?? ""
            return MGCacheRecordedFlags(
                layoutUUID: layout.uuid.uppercased(),
                cacheVersion: build,
                greenTea: gt,
                notGreenTea: ngt,
                wapi: wVal
            )
        }
        return loadRecordedMap()[layout.uuid.uppercased()]
    }

    private func loadRecordedMap() -> [String: MGCacheRecordedFlags] {
        guard let raw = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: MGCacheRecordedFlags].self, from: raw) else {
            return [:]
        }
        return decoded
    }

    private func saveRecordedMap(_ map: [String: MGCacheRecordedFlags]) {
        if let encoded = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    // MARK: - Strict Transition Audit & Diff Generation

    /// Ensures that ANY CacheData byte mutation ONLY touches dynamically resolved & validated Boolean offsets.
    /// Zero privilege bypasses: any unresolved layout or unrelated byte change is strictly blocked.
    func validateTransition(from beforeDict: NSDictionary, to afterDict: NSDictionary, using customLayout: MGCacheDataLayout? = nil) -> Result<Void, MGCacheResolutionError> {
        let beforeData = beforeDict["CacheData"] as? Data
        let afterData = afterDict["CacheData"] as? Data
        guard beforeData != afterData else {
            return .success(())
        }

        let layout: MGCacheDataLayout
        if let customLayout {
            layout = customLayout
        } else {
            switch libraryLayout() {
            case .failure(let err):
                return .failure(err)
            case .success(let resolved):
                layout = resolved
            }
        }

        guard case .success(let validBefore) = layout.validatePlist(beforeDict),
              case .success(let validAfter) = layout.validatePlist(afterDict),
              validBefore.count == validAfter.count else {
            switch layout.validatePlist(afterDict) {
            case .failure(let err):
                return .failure(err)
            case .success:
                if case .failure(let err2) = layout.validatePlist(beforeDict) {
                    return .failure(err2)
                }
                return .failure(.plistMismatch("修改前后 CacheData 校验未通过，已拒绝写入。"))
            }
        }

        let allowedOffsets = layout.permittedMutableOffsets
        if let wOff = layout.wapiOffset, validBefore[wOff] != validAfter[wOff] {
            if case .failure(let wErr) = layout.validatePlist(afterDict, checkWapiSlot: true) {
                return .failure(wErr)
            }
        }

        for idx in validBefore.indices where validBefore[idx] != validAfter[idx] {
            guard allowedOffsets.contains(idx) else {
                return .failure(.unauthorizedByteMutation(String(format: "检测到未授权的无关缓存字节变动（偏移 0x%X：0x%02X -> 0x%02X），已强制中止写入！", idx, validBefore[idx], validAfter[idx])))
            }
        }

        return .success(())
    }

    func diffDetails(from beforeDict: NSDictionary, to afterDict: NSDictionary, using customLayout: MGCacheDataLayout? = nil) -> [MGCacheDataDiffDetail] {
        guard let beforeData = beforeDict["CacheData"] as? Data,
              let afterData = afterDict["CacheData"] as? Data,
              beforeData != afterData,
              beforeData.count == afterData.count else {
            return []
        }

        let resolvedLayout: MGCacheDataLayout? = customLayout ?? {
            if case .success(let l) = libraryLayout() { return l }
            return nil
        }()

        guard let layout = resolvedLayout,
              case .success = layout.validatePlist(beforeDict),
              case .success = layout.validatePlist(afterDict) else {
            return []
        }

        var details: [MGCacheDataDiffDetail] = []
        var describedOffsets = Set<Int>()

        let slots: [(id: String, label: String, key: String, slot: Int, trueHint: String, falseHint: String)] = {
            var arr: [(String, String, String, Int, String, String)] = [
                ("green-tea", "国行限制标记 (green-tea)", MGCacheDataLayout.greenTeaKey, layout.greenTeaIndex, "true (0x01 · 受限)", "false (0x00 · 已解除)"),
                ("not-green-tea", "非国行设备标记 (not-green-tea)", MGCacheDataLayout.notGreenTeaKey, layout.notGreenTeaIndex, "true (0x01 · 非国行)", "false (0x00 · 国行默认)")
            ]
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: beforeData) && layout.validateSingleBooleanSlot(wIdx, in: afterData) {
                arr.append(("wapi", "无线局域网显示标记 (wapi)", MGCacheDataLayout.wapiKey, wIdx, "true (0x01 · 无线局域网)", "false (0x00 · Wi-Fi)"))
            }
            return arr
        }()

        for entry in slots {
            let off = entry.slot * 8
            if beforeData[off] != afterData[off] {
                describedOffsets.insert(off)
                details.append(
                    MGCacheDataDiffDetail(
                        id: "CacheData.\(entry.id)",
                        label: entry.label,
                        keyPath: String(format: "CacheData[0x%X] · 槽位 %d (%@)", off, entry.slot, entry.key),
                        beforeText: beforeData[off] != 0 ? entry.trueHint : entry.falseHint,
                        afterText: afterData[off] != 0 ? entry.trueHint : entry.falseHint
                    )
                )
            }
        }

        let otherChangedCount = beforeData.indices.filter { !describedOffsets.contains($0) && beforeData[$0] != afterData[$0] }.count
        if otherChangedCount > 0 {
            details.append(
                MGCacheDataDiffDetail(
                    id: "CacheData.other",
                    label: "底层二进制缓存其他偏移 (CacheData)",
                    keyPath: "CacheData",
                    beforeText: "<Data: \(beforeData.count) 字节>",
                    afterText: "<已变更 \(otherChangedCount) 个字节>"
                )
            )
        }

        return details
    }

    func diagnosticReport(for dict: NSDictionary) -> String {
        switch resolveValidated(for: dict) {
        case .failure(let err):
            return "状态：❌ 动态解析未通过（已拒绝并锁定修改）\n原因：\(err.localizedDescription)"
        case .success((let layout, let data)):
            let gtVal = data[layout.greenTeaOffset] == 1
            let ngtVal = data[layout.notGreenTeaOffset] == 1
            var lines: [String] = [
                "状态：✅ 已精确匹配本机系统库与缓存文件",
                "CacheUUID：\(layout.uuid)",
                "总槽位数：\(layout.slotCount) 个（共 \(layout.byteCount) 字节）",
                String(format: "green-tea：槽位 %d，偏移 0x%X（有效位 0x%X），当前值 = %@",
                       layout.greenTeaIndex, layout.greenTeaOffset, layout.validityOffset(for: layout.greenTeaIndex), gtVal ? "true" : "false"),
                String(format: "not-green-tea：槽位 %d，偏移 0x%X（有效位 0x%X），当前值 = %@",
                       layout.notGreenTeaIndex, layout.notGreenTeaOffset, layout.validityOffset(for: layout.notGreenTeaIndex), ngtVal ? "true" : "false")
            ]
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: data) {
                let wOff = wIdx * 8
                let wVal = data[wOff] == 1
                lines.append(String(format: "wapi (WLAN/Wi-Fi)：槽位 %d，偏移 0x%X（有效位 0x%X），当前值 = %@",
                                    wIdx, wOff, layout.validityOffset(for: wIdx), wVal ? "true (无线局域网)" : "false (Wi-Fi)"))
            } else {
                lines.append("wapi (WLAN/Wi-Fi)：当前系统未解析出有效槽位（已单独禁用）")
            }
            return lines.joined(separator: "\n")
        }
    }
}
