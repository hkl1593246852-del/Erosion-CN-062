//
//  PlainToggle.swift
//  PartyUI
//
//  Created by lunginspector on 3/8/26.
//

import SwiftUI

enum ToggleInfoType: Codable {
    case none, info, warning
}

struct PlainToggle: View {
    var text: String
    var subtitle: String
    var icon: String
    var infoType: ToggleInfoType
    var infoTitle: String
    var infoMessage: String
    var minVrs: Double
    var maxVrs: Double
    @Binding var isOn: Bool
    
    public init(_ text: String, subtitle: String = "", icon: String = "", infoType: ToggleInfoType = .none, infoTitle: String = "提示说明", infoMessage: String = "", minVrs: Double = 0.0, maxVrs: Double = 100.0, isOn: Binding<Bool>) {
        self.text = text
        self.subtitle = subtitle
        self.icon = icon
        self.infoType = infoType
        self.infoTitle = infoTitle
        self.infoMessage = infoMessage
        self._isOn = isOn
        self.minVrs = minVrs
        self.maxVrs = maxVrs
    }
    
    public var body: some View {
        if doubleSysVrs() >= minVrs && doubleSysVrs() <= maxVrs {
            Toggle(isOn: $isOn) {
                HStack(spacing: 10) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .frame(width: 22, height: 22, alignment: .center)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(text)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(infoType == .warning ? Color.orange : Color.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if infoType == .info || infoType == .warning {
                        Button(action: {
                            Alertinator.shared.alert(title: infoTitle, body: infoMessage)
                        }) {
                            Image(systemName: infoType == .info ? "info.circle" : "exclamationmark.triangle")
                                .foregroundStyle(infoType == .warning ? Color.orange : Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 6)
                    }
                }
            }
        }
    }
}

