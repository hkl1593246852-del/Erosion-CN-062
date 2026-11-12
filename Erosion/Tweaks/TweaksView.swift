//
//  TweaksView.swift
//  Erosion
//
//  Created by lunginspector on 8/26/26.
//

import SwiftUI


struct TweaksView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("状态栏与运营商自定义", destination: StatusBarView())
                    NavigationLink("桌面与系统动画调优", destination: SpringBoardTweakView())
                    NavigationLink("自定义锁屏壁纸", destination: PosterBoardView())
                    NavigationLink("拨号键盘美化", destination: KeypadView())
                } header: {
                    HeaderLabel("外观与桌面定制", symbol: "paintbrush")
                }

                Section {
                    NavigationLink("应用与游戏存档管理", destination: AppDataBackupView())
                    NavigationLink("容器缓存扫描与清理", destination: CacheCleanerView())
                } header: {
                    HeaderLabel("应用存档与空间清理", symbol: "externaldrive.badge.checkmark")
                }
                
                Section {
                    if raveSupported() || weOnADebugBuild {
                        NavigationLink("MobileGestalt 修改", destination: GestaltView())
                    }
                    NavigationLink("系统配置与监管", destination: ConfigView())
                    NavigationLink("任意文件替换", destination: OperationsView())
                } header: {
                    HeaderLabel("系统底层", symbol: "gear")
                }
            }
            .navigationTitle("功能修改")
        }
    }
}
