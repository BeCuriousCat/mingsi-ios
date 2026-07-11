import SwiftUI
import UIKit

// Design language: Calm Native Intelligence.
// Quiet working surface, restrained type scale, semantic cards.

enum DS {

    // MARK: - Colors

    static let background = dynamicColor(light: (0.958, 0.948, 0.922), dark: (0.080, 0.076, 0.066))
    static let cardBackground = dynamicColor(light: (0.992, 0.988, 0.972), dark: (0.132, 0.126, 0.112))
    static let surface = dynamicColor(light: (0.982, 0.976, 0.948), dark: (0.108, 0.104, 0.094))
    static let surfaceStrong = dynamicColor(light: (1.000, 0.996, 0.980), dark: (0.170, 0.160, 0.142))
    static let ink = dynamicColor(light: (0.080, 0.080, 0.075), dark: (0.925, 0.908, 0.860))
    static let mutedInk = dynamicColor(light: (0.420, 0.420, 0.380), dark: (0.675, 0.656, 0.600))
    static let hairline = dynamicColor(light: (0.000, 0.000, 0.000, 0.070), dark: (1.000, 0.960, 0.860, 0.120))

    static let accent = dynamicColor(light: (0.180, 0.340, 0.290), dark: (0.540, 0.720, 0.630))
    static let accentInk = dynamicColor(light: (0.090, 0.220, 0.190), dark: (0.700, 0.860, 0.780))
    static let caution = dynamicColor(light: (0.720, 0.360, 0.180), dark: (0.940, 0.620, 0.360))
    static let success = dynamicColor(light: (0.240, 0.450, 0.310), dark: (0.520, 0.760, 0.570))
    static let note = dynamicColor(light: (0.840, 0.660, 0.250), dark: (0.900, 0.720, 0.320))
    static let brick = dynamicColor(light: (0.620, 0.240, 0.180), dark: (0.880, 0.420, 0.340))
    static let graphite = dynamicColor(light: (0.250, 0.270, 0.260), dark: (0.700, 0.710, 0.680))
    static let principleBackground = dynamicColor(light: (0.990, 0.965, 0.880), dark: (0.190, 0.160, 0.100))

    // Type colors - subtle, not dominant
    static let typeFact = dynamicColor(light: (0.350, 0.380, 0.360), dark: (0.640, 0.690, 0.650))
    static let typeProblem = dynamicColor(light: (0.680, 0.360, 0.200), dark: (0.920, 0.560, 0.340))
    static let typeDecision = dynamicColor(light: (0.200, 0.390, 0.340), dark: (0.500, 0.760, 0.680))
    static let typeRisk = dynamicColor(light: (0.620, 0.240, 0.180), dark: (0.920, 0.480, 0.400))
    static let typeIdea = dynamicColor(light: (0.430, 0.510, 0.240), dark: (0.720, 0.800, 0.420))
    static let typeCommunication = dynamicColor(light: (0.380, 0.420, 0.360), dark: (0.680, 0.720, 0.640))
    static let typeTask = dynamicColor(light: (0.240, 0.430, 0.360), dark: (0.540, 0.780, 0.680))

    // MARK: - Spacing

    static let cornerRadius: CGFloat = 10
    static let smallRadius: CGFloat = 8
    static let pagePadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 18
    static let cardSpacing: CGFloat = 10
    static let cardInnerPadding: CGFloat = 14
    static let primaryScrollTopPadding: CGFloat = 12
    static let primaryScrollBottomReserve: CGFloat = 188
    static let todayScrollBottomReserve: CGFloat = 112
    static let topSafeAreaScrimExtra: CGFloat = 10

    // MARK: - Tab Bar

    static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = dynamicUIColor(light: (0.958, 0.948, 0.922, 0.970), dark: (0.080, 0.076, 0.066, 0.970))
        appearance.shadowColor = .separator

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.normal.iconColor = .secondaryLabel

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: dynamicUIColor(light: (0.160, 0.300, 0.260, 1.000), dark: (0.540, 0.720, 0.630, 1.000))
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = dynamicUIColor(light: (0.160, 0.300, 0.260, 1.000), dark: (0.540, 0.720, 0.630, 1.000))

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func dynamicColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(dynamicUIColor(
            light: (light.0, light.1, light.2, 1.0),
            dark: (dark.0, dark.1, dark.2, 1.0)
        ))
    }

    private static func dynamicColor(
        light: (Double, Double, Double, Double),
        dark: (Double, Double, Double, Double)
    ) -> Color {
        Color(dynamicUIColor(light: light, dark: dark))
    }

    private static func dynamicUIColor(
        light: (Double, Double, Double, Double),
        dark: (Double, Double, Double, Double)
    ) -> UIColor {
        UIColor { traitCollection in
            let value = traitCollection.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(value.0),
                green: CGFloat(value.1),
                blue: CGFloat(value.2),
                alpha: CGFloat(value.3)
            )
        }
    }
}

// MARK: - Card Modifier

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.cardInnerPadding)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.025), radius: 1.5, y: 1)
    }
}

enum EvidenceSurfaceBase {
    case plain
    case quest(isMain: Bool)
    case principle
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    func pageBackground() -> some View {
        background(DS.background)
    }

    func topSafeAreaScrim() -> some View {
        modifier(TopSafeAreaScrim())
    }

    func thinkingCardSurface(type: ThinkingCardType, isExcluded: Bool) -> some View {
        padding(DS.cardInnerPadding)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isExcluded ? Color.secondary.opacity(0.35) : type.color)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func questSurface(isMain: Bool) -> some View {
        padding(DS.cardInnerPadding)
            .background(
                isMain ? DS.accent.opacity(0.09) : Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(isMain ? DS.accent.opacity(0.22) : Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func questionSurface() -> some View {
        padding(DS.cardInnerPadding)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                Image(systemName: "questionmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.accent.opacity(0.55))
                    .padding(10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func principleSurface() -> some View {
        padding(DS.cardInnerPadding)
            .background(DS.principleBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(DS.caution.opacity(0.18), lineWidth: 1)
            )
    }

    func modeSurface(isSelected: Bool) -> some View {
        padding(DS.cardInnerPadding)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func lensSurface(isSelected: Bool) -> some View {
        padding(DS.cardInnerPadding)
            .background(
                isSelected ? DS.accent.opacity(0.07) : Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.25) : Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    func summarySurface() -> some View {
        padding(DS.cardInnerPadding)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
    }

    @ViewBuilder
    func evidenceSurface(isHighlighted: Bool, base: EvidenceSurfaceBase = .plain) -> some View {
        let strokeColor = isHighlighted ? DS.note.opacity(0.75) : Color.primary.opacity(0.05)
        let highlightFill = isHighlighted ? DS.note.opacity(0.10) : Color.clear

        switch base {
        case .plain:
            padding(DS.cardInnerPadding)
                .background {
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(highlightFill)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: isHighlighted ? 1.5 : 1)
                )
        case .quest(let isMain):
            padding(DS.cardInnerPadding)
                .background {
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .fill(isMain ? DS.accent.opacity(0.09) : Color(.systemBackground))
                        .overlay(highlightFill)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(isHighlighted ? strokeColor : (isMain ? DS.accent.opacity(0.22) : Color.primary.opacity(0.05)), lineWidth: isHighlighted ? 1.5 : 1)
                )
        case .principle:
            padding(DS.cardInnerPadding)
                .background {
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .fill(DS.principleBackground)
                        .overlay(highlightFill)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(isHighlighted ? strokeColor : DS.caution.opacity(0.18), lineWidth: isHighlighted ? 1.5 : 1)
                )
        }
    }
}

struct TopSafeAreaScrim: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            GeometryReader { proxy in
                DS.background
                    .frame(height: proxy.safeAreaInsets.top + DS.topSafeAreaScrimExtra)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
        }
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
