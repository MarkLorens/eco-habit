//
//  AppSearchBar.swift
//  Eco-Habbit
//
//  Created by Max on 13/08/26.
//

import SwiftUI

struct AppSearchBar: View{
    @Binding var text: String
    var prompt: String = "Search"
    
    @FocusState private var isFocused: Bool
    
    var body: some View{
        HStack{
            Image(systemName: "leaf.fill")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)
                .padding(Tokens.Spacing.md)
                .glassed(in: .circle, fallback: Tokens.Semantic.buttonTintDefault)
            HStack (spacing: Tokens.Spacing.sm){
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.Semantic.footnote)
                
                TextField(prompt, text: $text)
                    .font(.system (size: 16, weight: .regular))
                    .foregroundStyle(Tokens.Semantic.text)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Image(systemName: "microphone")
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.md)
            .glassed(in: .capsule, fallback: Tokens.Semantic.buttonTintDefault)
            
            if !text.isEmpty{
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .glassed(in: .circle, fallback: Tokens.Semantic.buttonTintDefault)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func glassed(in shape: some Shape, fallback: Color) -> some View {
        if #available(iOS 26.0, *){
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill(fallback.opacity(0.5)))
                .overlay(shape.stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}

#Preview {
    struct Harness: View {
        @State private var text = ""
        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<12, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Tokens.Palette.white)
                            .frame(height: 80)
                    }
                }
                .padding()
            }
            .background(Tokens.Palette.orangeCard)
            .safeAreaInset(edge: .bottom) {
                AppSearchBar(text: $text)
                    .padding(.horizontal, Tokens.Spacing.md)
                    .padding(.bottom, Tokens.Spacing.sm)
            }
        }
    }
    return Harness()
}
