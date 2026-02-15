//
//  Color+Extensions.swift
//  ComposeFeature
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        switch hexSanitized.lowercased() {
        case "red":
            self = .red
            return
        case "blue":
            self = .blue
            return
        case "green":
            self = .green
            return
        case "yellow":
            self = .yellow
            return
        case "orange":
            self = .orange
            return
        case "purple":
            self = .purple
            return
        case "pink":
            self = .pink
            return
        case "brown":
            self = .brown
            return
        case "cyan":
            self = .cyan
            return
        case "gray", "grey":
            self = .gray
            return
        case "black":
            self = .black
            return
        case "white":
            self = .white
            return
        case "mint":
            self = .mint
            return
        case "teal":
            self = .teal
            return
        case "indigo":
            self = .indigo
            return
        default:
            break
        }
        
        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
