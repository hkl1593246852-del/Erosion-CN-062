//
//  FMRootView.swift
//  Erosion
//
//  Created by lunginspector on 8/26/26.
//

import SwiftUI

enum FSPaths {
    static let appContainers = "/var/mobile/Containers/Data/Application"
    static var appBundles = "/var/containers/Bundle/Application"
}

enum FSURL {
    static let appContainers = URL(fileURLWithPath: FSPaths.appContainers)
    static var sysGroup = URL(fileURLWithPath: "/var/containers/Shared/SystemGroup")
    static var configProfiles = FSURL.sysGroup.appendingPathComponent("systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles")
    static var internalDaemons = URL(fileURLWithPath: "/var/mobile/Containers/Data/InternalDaemon")
    static var appPlugins = URL(fileURLWithPath: "/var/mobile/Containers/Data/PluginKitPlugin")
    static var appGroup = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup")
    static var systemData = URL(fileURLWithPath: "/var/containers/Data/System")
}

struct FMRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("MobileGestalt 缓存目录", destination: FileBrowserView(path: MGURL.fsGestaltURL.deletingLastPathComponent(), shouldGrant: true))
                    NavigationLink("系统配置描述文件目录", destination: FileBrowserView(path: FSURL.configProfiles, shouldGrant: true))
                    NavigationLink("本应用文档目录 (Documents)", destination: FileBrowserView(path: URL.documentsDirectory))
                } header: {
                    HeaderLabel("快捷访问", symbol: "bolt")
                }
                
                Section {
                    NavigationLink("应用数据容器 (Data)", destination: FileBrowserView(path: FSURL.appContainers, isContainer: true))
                    NavigationLink("插件数据容器 (Plugin)", destination: FileBrowserView(path: FSURL.appPlugins, isContainer: true))
                    NavigationLink("共享应用组 (App Groups)", destination: FileBrowserView(path: FSURL.appGroup, shouldGrant: true))
                } header: {
                    HeaderLabel("应用程序", symbol: "square.grid.2x2")
                }
                
                Section {
                    NavigationLink("守护进程容器 (Daemon)", destination: FileBrowserView(path: FSURL.internalDaemons, isContainer: true))
                    NavigationLink("系统数据容器 (System)", destination: FileBrowserView(path: FSURL.systemData, shouldGrant: true))
                    NavigationLink("系统共享组容器 (SystemGroup)", destination: FileBrowserView(path: FSURL.sysGroup, isContainer: true))
                } header: {
                    HeaderLabel("系统容器", symbol: "gear")
                }
            }
            .navigationTitle("文件浏览")
        }
    }
}
