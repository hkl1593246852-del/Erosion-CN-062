//
//  FSHandlers.swift
//  Erosion
//
//  Created by lunginspector on 8/19/26.
//

import Foundation
import UIKit

let fsHandlers = FSHandlers()

class FSHandlers {
    func getDirPaths(_ path: String, maxInode: Int64 = 15000000) -> [String] {
        let baselineURL = fm.temporaryDirectory.appendingPathComponent(".baseline_\(UUID().uuidString)")
        var baselineInode: UInt64 = 0

        do {
            try "baseline".write(to: baselineURL, atomically: true, encoding: .utf8)
            var baselineInfo = stat()
            if stat(baselineURL.path, &baselineInfo) == 0 {
                baselineInode = baselineInfo.st_ino
                print("(fs) 动态探测本机当前最大 Inode 基线: \(baselineInode)")
            }
            try? fm.removeItem(at: baselineURL)
        } catch {
            print("(fs) 获取动态 Inode 基线失败，回退至预设上限: \(error.localizedDescription)")
        }

        let targetMaxInode = baselineInode > 0 ? baselineInode : UInt64(max(maxInode, 15000000))
        print("(fs) 正在通过 pathleak 枚举目录: \(path) (上限: \(targetMaxInode))")
        let leakedPaths = pathleak(path, targetMaxInode) ?? []
        print("(fs) pathleak 枚举完成，共找到 \(leakedPaths.count) 个容器路径")
        return leakedPaths
    }
    
    func getContainerPath(at containerURL: URL = FSURL.appContainers, forMatch match: String, hashOnly: Bool = false) -> String {
        let containers = getDirPaths(containerURL.path)
        for path in containers {
            let url = URL(fileURLWithPath: path)
            if let appName = getBIDFromXattr(url) {
                if appName == match {
                    if hashOnly {
                        return url.lastPathComponent
                    }
                    return url.path
                }
            }
        }
        print("(fs) failed to get container for \(match)! containers: \(containerURL.path)")
        return ""
    }
    
    func openInFilesApp(_ fileURL: URL) {
        guard var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) else { return }
        components.scheme = "shareddocuments"
        guard let filesAppURL = components.url else { return }
        UIApplication.shared.open(filesAppURL)
    }
}
