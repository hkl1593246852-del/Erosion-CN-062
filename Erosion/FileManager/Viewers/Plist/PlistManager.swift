//
//  PlistManager.swift
//  Filos
//
//  Created by lunginspector on 7/25/26.
//

import SwiftUI
import Combine
import CoreFoundation

final class PlistManager: ObservableObject {
    static let shared = PlistManager()
    
    @Published var plistArray: [PlistItem] = []
    @Published var url: URL = URL.documentsDirectory.appendingPathComponent("oops")
    @Published var isWritable = false
    private var rootIsArray = false
    private var detectedFormat: PropertyListSerialization.PropertyListFormat = .binary
    
    init() {}
    
    func loadPlistItems() -> Bool {
        rootIsArray = false
        detectedFormat = .binary
        guard let rawData = try? Data(contentsOf: url) else {
            return false
        }
        var fmt: PropertyListSerialization.PropertyListFormat = .binary
        guard let plistObj = try? PropertyListSerialization.propertyList(from: rawData, options: [], format: &fmt) else {
            print("(fm) failed to deserialize plist at \(url.path)")
            return false
        }
        detectedFormat = fmt

        if let rawDict = plistObj as? [String : Any] {
            plistArray = [PlistItem(key: "Root", value: [:], isExpanded: true)]
            for key in rawDict.keys {
                if let value = rawDict[key] {
                    plistArray[0].dictVal.append(PlistItem(key: key, value: value))
                }
            }
            plistArray[0].dictVal.sort(by: { $0.key < $1.key })
            return true
        } else if let rawArr = plistObj as? [Any] {
            rootIsArray = true
            var rootItem = PlistItem(key: "Root", value: rawArr, isExpanded: true)
            rootItem.type = .array
            plistArray = [rootItem]
            return true
        } else {
            print("(fm) unsupported plist root type")
            return false
        }
    }
    
    func writePlistItems(newItem: PlistItem? = nil, delItem: PlistItem? = nil) -> Bool {
        if var newItem {
            newItem.isModified = true
            let res = replacePlistItem(items: &plistArray, newItem: newItem)
            if !res {
                print("(fm) failed to write plist: couldn't find \(newItem.key) in dictionary.")
            }
        }
        
        if let delItem {
            let res = deletePlistItem(items: &plistArray, target: delItem)
            if !res {
                print("(fm) failed to write plist: couldn't find \(delItem.key) in dictionary.")
            }
        }
        
        let rootObjectToSerialize: Any
        if rootIsArray {
            rootObjectToSerialize = plistArray[0].dictVal.map { $0.getRawValue() }
        } else {
            var dictToWrite: [String : Any] = [:]
            for item in plistArray[0].dictVal {
                dictToWrite[item.key] = item.getRawValue()
            }
            rootObjectToSerialize = dictToWrite
        }
    
        do {
            let outFormat: PropertyListSerialization.PropertyListFormat = (detectedFormat == .xml) ? .xml : .binary
            let data = try PropertyListSerialization.data(fromPropertyList: rootObjectToSerialize, format: outFormat, options: 0)
            // Block dangerous direct edits to live MobileGestalt if malformed
            if url.lastPathComponent == "com.apple.MobileGestalt.plist" {
                let res = mgWriteDetailed(data)
                return res.0
            }
            if fm.fileExists(atPath: url.path) {
                // Never fall through to bare non-atomic write on existing files (SEC-M4-02)
                let atomicRes = writeFileAtomically(data, to: url)
                if !atomicRes.0 {
                    print("(fm) atomic plist write failed: \(atomicRes.1)")
                }
                return atomicRes.0
            } else {
                try data.write(to: url, options: .atomic)
                return true
            }
        } catch {
            print("(fm) failed to write plist: \(error.localizedDescription)")
        }
        return false
    }
    
    // not a huge fan of any of this...
    func replacePlistItem(items: inout [PlistItem], newItem: PlistItem) -> Bool {
        for item in items.indices {
            if items[item].id == newItem.id {
                var updated = newItem
                let old = items[item]
                if old.type == updated.type && old.stringVal == updated.stringVal && old.boolVal == updated.boolVal && old.type != .dict && old.type != .array {
                    updated.isModified = old.isModified
                }
                items[item] = updated
                return true
            }
            
            if replacePlistItem(items: &items[item].dictVal, newItem: newItem) {
                return true
            }
        }
        return false
    }
    
    func deletePlistItem(items: inout [PlistItem], target: PlistItem) -> Bool {
        for item in items.indices {
            if items[item].id == target.id {
                items.removeAll() { $0.id == target.id }
                return true
            }
            
            if deletePlistItem(items: &items[item].dictVal, target: target) {
                return true
            }
        }
        return false
    }
}

struct PlistItem: Identifiable {
    var id = UUID()
    var key: String
    var rawVal: Any?
    var type: PlistItemType = .unknown
    var index: Int?
    var isExpanded: Bool
    var isModified: Bool = false
    
    var stringVal: String = ""
    var boolVal: Bool = false
    var dictVal: [PlistItem] = []
    
    init(key: String, value: Any, isExpanded: Bool = false, isModified: Bool = false) {
        self.key = key
        self.rawVal = value
        self.isExpanded = isExpanded
        self.isModified = isModified
        self.type = Self.detectType(of: value)
        
        switch self.type {
        case .string:
            self.stringVal = value as? String ?? ""
        case .bool:
            let b = (value as? Bool) ?? ((value as? NSNumber)?.boolValue ?? false)
            self.boolVal = b
            self.stringVal = b ? "true" : "false"
        case .int:
            if let num = value as? NSNumber {
                self.stringVal = num.stringValue
            } else if let v = value as? Int {
                self.stringVal = String(v)
            }
        case .double:
            if let num = value as? NSNumber {
                self.stringVal = String(num.doubleValue)
            } else if let v = value as? Double {
                self.stringVal = String(v)
            }
        case .data:
            if let v = value as? Data {
                self.stringVal = v.base64EncodedString()
            }
        case .dict:
            if let v = value as? [String : Any] {
                self.dictVal = v.map {
                    PlistItem(key: $0.key, value: $0.value)
                }.sorted(by: { $0.key < $1.key })
                self.stringVal = v.description
            }
        case .array:
            if let v = value as? [Any] {
                self.dictVal = v.enumerated().map { index, elem in
                    var newItem = PlistItem(key: "Item \(index)", value: elem)
                    newItem.index = index
                    return newItem
                }
                self.stringVal = v.description
            }
        case .unknown:
            if let rawVal {
                self.stringVal = String(describing: rawVal)
            }
        }
    }
    
    private static func detectType(of value: Any) -> PlistItemType {
        let cfObj = value as AnyObject
        if CFGetTypeID(cfObj) == CFBooleanGetTypeID() {
            return .bool
        }
        if let num = value as? NSNumber {
            return CFNumberIsFloatType(num) ? .double : .int
        }
        switch value {
        case is String: return .string
        case is Data: return .data
        case is [String : Any]: return .dict
        case is [Any]: return .array
        default: return .unknown
        }
    }
    
    func getRawValue() -> Any {
        switch type {
        case .dict:
            var rawDict = [String : Any]()
            for item in dictVal {
                rawDict[item.key] = item.getRawValue()
            }
            return rawDict
        case .array:
            var rawArray = [Any]()
            for item in dictVal {
                rawArray.append(item.getRawValue())
            }
            return rawArray
        case .string, .int, .double, .bool, .data, .unknown:
            if !isModified, let rawVal {
                return rawVal
            }
            switch type {
            case .string: return stringVal
            case .int:
                if let i64 = Int64(stringVal) {
                    return NSNumber(value: i64)
                }
                if let u64 = UInt64(stringVal) {
                    return NSNumber(value: u64)
                }
                return 0
            case .double: return Double(stringVal) ?? 0.0
            case .bool: return boolVal
            case .data: return rawVal ?? Data()
            default: return rawVal ?? ""
            }
        }
    }
}

enum PlistItemType: String, CaseIterable {
    case string, int, double, bool, data, dict, array, unknown
    
    var label: String {
        switch self {
        case .string: return "字符串 (String)"
        case .int: return "整数 (Integer)"
        case .double: return "浮点数 (Double)"
        case .bool: return "布尔值 (Boolean)"
        case .data: return "二进制数据 (Data)"
        case .dict: return "字典 (Dictionary)"
        case .array: return "数组 (Array)"
        default: return "未知"
        }
    }
}
