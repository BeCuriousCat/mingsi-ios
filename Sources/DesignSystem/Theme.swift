import SwiftUI

// Design language: "Calm Native Intelligence"
// Inspired by Apple Notes / Bear / Paper
// Cards are white on grouped background, no borders, type indicated by color dot

enum DS {

    // MARK: - Colors

    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.white)
    static let surface = Color(.secondarySystemBackground)
    static let surfaceStrong = Color(.tertiarySystemBackground)

    static let accent = Color(red: 0.22, green: 0.42, blue: 0.68)
    static let caution = Color(red: 0.78, green: 0.47, blue: 0.14)
    static let success = Color(red: 0.20, green: 0.56, blue: 0.34)

    // Type colors - subtle, not dominant
    static let typeFact = Color(red: 0.45, green: 0.51, blue: 0.58)
    static let typeProblem = Color(red: 0.72, green: 0.45, blue: 0.25)
    static let typeDecision = Color(red: 0.35, green: 0.47, blue: 0.70)
    static let typeRisk = Color(red: 0.75, green: 0.35, blue: 0.32)
    static let typeIdea = Color(red: 0.35, green: 0.60, blue: 0.42)
    static let typeCommunication = Color(red: 0.55, green: 0.38, blue: 0.62)
    static let typeTask = Color(red: 0.25, green: 0.47, blue: 0.62)

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 16
    static let smallRadius: CGFloat = 12
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    static let cardInnerPadding: CGFloat = 16

    // MARK: - Tab Bar

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .separator

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.normal.iconColor = .secondaryLabel

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(red: 0.22, green: 0.42, blue: 0.68, alpha: 1.0)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.22, green: 0.42, blue: 0.68, alpha: 1.0)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Card Modifier: White card, no border, subtle shadow

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.cardInnerPadding)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}

// MARK: - Type Color

extension ThinkingCardType {
    var color: Color {
        switch self {
        case .fact: return DS.typeFact
        case .problem: return DS.typeProblem
        case .decision: return DS.typeDecision
        case .risk: return DS.typeRisk
        case .idea: return DS.typeIdea
        case .communication: return DS.typeCommunication
        case .task: return DS.typeTask
        }
    }
}
