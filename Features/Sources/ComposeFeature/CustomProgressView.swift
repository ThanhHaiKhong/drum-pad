//
//  CustomProgressView.swift
//  Features
//
//  Created by Thanh Hai Khong on 13/2/26.
//

import SwiftUI

public struct CustomProgressView: View {
    private let progress: CGFloat
    private let height: CGFloat
    
    public init(
        progress: CGFloat,
        height: CGFloat = 4
    ) {
        self.progress = progress
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: height)
                    .foregroundColor(.black.opacity(0.125))
                
                Rectangle()
                    .frame(width: min(progress * geometry.size.width, geometry.size.width), height: height)
                    .foregroundColor(.white)
            }
        }
        .frame(height: height)
    }
}
