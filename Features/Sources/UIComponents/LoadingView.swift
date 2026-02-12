//
//  LoadingView.swift
//  Features
//
//  Created by Thanh Hai Khong on 11/2/26.
//

import SwiftUI

public struct LoadingView: View {
    let isLoading: Bool
    let message: String
    
    public init(isLoading: Bool, message: String = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }
    
    public var body: some View {
        if isLoading {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text(message)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
    }
}
