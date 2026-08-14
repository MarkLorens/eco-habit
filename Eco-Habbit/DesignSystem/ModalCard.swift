//
//  ModalCard.swift
//  Eco-Habbit
//
//  Created by Max on 14/08/26.
//

import SwiftUI

extension View {
    func modalCard<Item: Identifiable, CardContent: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> CardContent
    ) -> some View {
        modifier(ModalCardModifier(item: item, card: content))
    }
}

private struct ModalCardModifier<Item: Identifiable, CardContent: View>: ViewModifier {
    
    @Binding var item: Item?
    @ViewBuilder var card: (Item) -> CardContent
    
    func body(content: Content) -> some View {
        content
            .overlay{
                if let item {
                    ZStack{
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .onTapGesture {
                                dismiss()
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Close")
                        
                        card(item)
                            .frame(maxWidth: 300)
                            .background{
                                RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                                    .fill(Tokens.Palette.white)
                            }
                            .padding(.horizontal, Tokens.Spacing.xl)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                            .onTapGesture {}
                    }
                    .accessibilityAddTraits(.isModal)
                }
            }
    }
    
    private func dismiss() {
        item = nil
    }
}
