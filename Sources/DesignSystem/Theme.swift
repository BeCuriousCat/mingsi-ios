import SwiftUI

enum DS {
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemBackground)
    static let surfaceStrong = Color(.tertiarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let accent = Color(red: 0.16, green: 0.45, blue: 0.76)
    static let caution = Color(red: 0.82, green: 0.46, blue: 0.13)
    static let success = Color(red: 0.17, green: 0.58, blue: 0.36)
    static let border = Color.primary.opacity(0.08)

    static let cornerRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10
    static let pagePadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let cardSpacing: CGFloat = 10
    static let contentWidth: CGFloat = 720
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(DS.border, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
