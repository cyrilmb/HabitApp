//
//  OnboardingView.swift
//  HabitTracker
//
//  Swipeable intro pages for new users
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [(title: String, subtitle: String, icon: String, color: Color)] = [
        ("Welcome to Habit Tracker", "Your personal tracking companion", "chart.line.uptrend.xyaxis.circle.fill", .indigo),
        ("Track Activities", "Time your activities with a built-in timer", "timer", .blue),
        ("Log Substances", "Record consumption with categories and methods", "pill", .purple),
        ("Monitor Biometrics", "Track weight, sleep, mood, and more", "heart.text.square", .red),
        ("Build Daily Habits", "Create a daily checklist and build streaks", "checklist", .green),
        ("Set Goals & View Analytics", "Set targets or limits, and see your progress over time", "target", .orange),
    ]

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            hasSeenOnboarding = true
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Spacer()

                            Image(systemName: page.icon)
                                .font(.system(size: 80))
                                .foregroundStyle(page.color)
                                .frame(width: 120, height: 120)

                            Text(page.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Text(page.subtitle)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Spacer()
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)

                if currentPage == pages.count - 1 {
                    Button(action: {
                        hasSeenOnboarding = true
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigo.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
