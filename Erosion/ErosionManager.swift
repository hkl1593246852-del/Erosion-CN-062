//
//  ErosionManager.swift
//  Erosion
//
//  Created by lunginspector on 8/24/26.
//

import Foundation
import Combine

var build: String {
    "zh.\(AppInfo.appBuild) 汉化修复版"
}

enum Errors {
    static var checkLogs = "请前往主页查看运行日志以获取详细错误信息。"
}

enum AppURL {
    static let pb = URL.documentsDirectory.appendingPathComponent("PosterBoard")
    static let pbFolders = AppURL.pb.appendingPathComponent("Wallpapers")
    static let ps = URL.documentsDirectory.appendingPathComponent("Passcode Themes")
}

enum AppMsg {
    static let opFailed = "请重启应用后重试。如果问题仍然存在，说明你的设备可能暂不支持，或该修改项不适用于当前设备。"
    static let applied = "请注销设备以使修改生效。"
    static let unsupported = "非常抱歉，Erosion 依赖的沙盒逃逸漏洞在当前系统版本中已被修复，请退出应用。"
}

final class ErosionManager: ObservableObject {
    static let shared = ErosionManager()
    @Published var logOutput = ""
    @Published var shouldRespring = false
    @Published var refreshFiles = false
    
    @Published var storedFiles = [FileItem]()
    @Published var storedURL: URL = URL(fileURLWithPath: "/")
    
    init() {}
}
