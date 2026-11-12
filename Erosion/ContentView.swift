//
//  ContentView.swift
//  Erosion
//
//  Created by lunginspector on 8/14/26.
//

import SwiftUI


struct ContentView: View {
    @AppStorage("ogMachineName") var ogMachineName = ""
    @EnvironmentObject var mgr: ErosionManager
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LogView()
                        .modifier(TerminalPlatter())
                } header: {
                    HeaderLabel("运行日志", symbol: "apple.terminal")
                } footer: {
                    Text("v\(AppInfo.appVersion) (Build \(AppInfo.appBuild)) · \(UIDevice.current.systemName) \(UIDevice.current.systemVersion) (\(buildNumber())) · \(machineName())")
                }
                
                Section {
                    Button("注销设备 (Respring)") {
                        mgr.shouldRespring = true
                    }
                } header: {
                    HeaderLabel("快捷操作", symbol: "gearshape")
                }
            }
            .navigationTitle("Erosion")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("设置", systemImage: "gear")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if ogMachineName.isEmpty {
                    ogMachineName = machineName()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
