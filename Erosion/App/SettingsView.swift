//
//  SettingsView.swift
//  Erosion
//
//  Created by lunginspector on 8/20/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoRespring") var autoRespring = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("应用修改后自动注销", isOn: $autoRespring)
                } header: {
                    HeaderLabel("应用设置", symbol: "gearshape")
                } footer: {
                    Text("在成功应用功能修改后自动触发设备注销 (Respring)。")
                }
                
                Section {
                    AppInfoCell(build: build)
                } header: {
                    HeaderLabel("关于", symbol: "info.circle")
                } footer: {
                    Text("由 [jailbreak.party](https://jailbreak.party) 团队倾情打造 · 简体中文汉化与国行适配修复版")
                }
                
                Section {
                    LinkCreditCell(image: Image("lunginspector"), name: "lunginspector", description: "主要开发者与项目维护者", url: "https://github.com/lunginspector")
                    LinkCreditCell(image: Image("forcequit"), name: "forcequit", description: "worse_query 沙盒逃逸漏洞作者", url: "https://github.com/forcequitOS")
                    LinkCreditCell(image: Image("0xjohnny"), name: "0xjohnny", description: "worse_query 沙盒逃逸漏洞作者", url: "https://github.com/0xjohnnydev")
                    LinkCreditCell(image: Image("skadz108"), name: "Skadz", description: "漏洞集成、后端核心功能与项目维护", url: "https://github.com/skadz108")
                    LinkCreditCell(image: Image("rooootdev"), name: "rooootdev", description: "多项后端组件支持", url: "https://github.com/rooootdev")
                    LinkCreditCell(image: Image("neonmodder123"), name: "neonmodder123", description: "WebView 免越狱注销方案作者", url: "https://github.com/neonmodder123")
                } header: {
                    HeaderLabel("上游项目作者 (jailbreak.party)", symbol: "star")
                }

                Section {
                    LinkCreditCell(name: "huamidev — GestaltX", description: "本机系统库动态缓存偏移解析、变更对比预览、写后校验与重签 App Group 探测等优秀设计参考", url: "https://github.com/huamidev/GestaltX")
                    LinkCreditCell(name: "KirbySD", description: "MobileGestalt CacheData 布尔槽位偏移研究思路分享", url: "https://www.v2ex.com/t/1246550")
                    LinkCreditCell(name: "PoomSmart — MGKeys", description: "MobileGestalt 混淆键值映射表维护与整理", url: "https://github.com/PoomSmart/MGKeys")
                } header: {
                    HeaderLabel("特别致谢与特性参考", symbol: "heart")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ToolbarLabel("关闭", symbol: "xmark")
                    }
                }
            }
        }
    }
}
