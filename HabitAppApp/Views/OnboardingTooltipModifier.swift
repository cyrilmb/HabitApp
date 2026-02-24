//
//  OnboardingTooltipModifier.swift
//  HabitTracker
//
//  Interactive tooltip overlay that walks through HomeView buttons
//

import SwiftUI

// MARK: - Preference Key

struct OnboardingAnchorKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func onboardingAnchor(step: Int) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: OnboardingAnchorKey.self,
                    value: [step: geo.frame(in: .global)]
                )
            }
        )
    }
}

// MARK: - Tooltip Modifier

struct OnboardingTooltipModifier: ViewModifier {
    @Binding var isActive: Bool
    @State private var currentStep = 0
    @State private var anchors: [Int: CGRect] = [:]

    private let tooltips: [String] = [
        "Tap here to start timing an activity",
        "Record substance use here",
        "Track health data like weight, sleep & mood",
        "Check off your daily habits here",
        "View past logs, set goals, or see analytics",
    ]

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(OnboardingAnchorKey.self) { value in
                anchors = value
            }
            .overlay {
                if isActive {
                    tooltipOverlay
                }
            }
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        if let rect = anchors[currentStep] {
            GeometryReader { geo in
                let screenHeight = geo.size.height
                let padding: CGFloat = 8
                let highlightRect = CGRect(
                    x: rect.minX - padding,
                    y: rect.minY - padding,
                    width: rect.width + padding * 2,
                    height: rect.height + padding * 2
                )
                let showAbove = rect.midY > screenHeight * 0.5

                ZStack {
                    // Dark overlay with cutout
                    Color.black.opacity(0.5)
                        .mask {
                            Rectangle()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(width: highlightRect.width, height: highlightRect.height)
                                        .position(x: highlightRect.midX, y: highlightRect.midY)
                                        .blendMode(.destinationOut)
                                }
                        }
                        .compositingGroup()

                    // Tooltip bubble
                    VStack(spacing: 12) {
                        Text(tooltips[currentStep])
                            .font(.body)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: advance) {
                            Text(currentStep < tooltips.count - 1 ? "Next" : "Done")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(Color.indigo.gradient)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    .frame(maxWidth: 300)
                    .position(
                        x: geo.size.width / 2,
                        y: showAbove
                            ? highlightRect.minY - 70
                            : highlightRect.maxY + 70
                    )
                }
            }
            .animation(.easeInOut(duration: 0.25), value: currentStep)
        }
    }

    private func advance() {
        if currentStep < tooltips.count - 1 {
            currentStep += 1
        } else {
            isActive = false
        }
    }
}

extension View {
    func onboardingTooltips(isActive: Binding<Bool>) -> some View {
        self.modifier(OnboardingTooltipModifier(isActive: isActive))
    }
}
