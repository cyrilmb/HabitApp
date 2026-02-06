//
//  DataDisplayView.swift
//  HabitTracker
//
//  Analytics and data visualization view
//

import SwiftUI
import Charts
import Combine

struct DataDisplayView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedCategory: AnalyticsCategory = .activities
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedActivityName: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedTimeRange) { _, newRange in
                    selectedDate = anchorDate(for: newRange)
                    viewModel.loadData(for: newRange, date: selectedDate)
                }
                
                // Period navigator — visible for every range except All Time
                if selectedTimeRange != .all {
                    HStack {
                        Button(action: { shiftPeriod(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }

                        Spacer()

                        Text(periodHeader)
                            .font(.headline)

                        Spacer()

                        Button(action: { shiftPeriod(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(isPeriodAtPresent ? .secondary : .blue)
                        }
                        .disabled(isPeriodAtPresent)
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedDate) { _, _ in
                        viewModel.loadData(for: selectedTimeRange, date: selectedDate)
                    }
                }
                
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(AnalyticsCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView("Loading analytics...")
                        .padding()
                } else if selectedCategory == .activities {
                    activityAnalytics
                } else if selectedCategory == .substances {
                    substanceAnalytics
                } else {
                    biometricAnalytics
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadData(for: selectedTimeRange, date: selectedDate)
        }
    }
    
    // MARK: - Period Navigation Helpers

    /// Move selectedDate forward or backward by one unit of the current range.
    private func shiftPeriod(by direction: Int) {
        let cal = Calendar.current
        let component: Calendar.Component
        switch selectedTimeRange {
        case .day:   component = .day
        case .week:  component = .weekOfYear
        case .month: component = .month
        case .year:  component = .year
        case .all:   return   // navigator is hidden for All Time
        }
        guard let newDate = cal.date(byAdding: component, value: direction, to: selectedDate) else { return }
        // Never allow stepping into a period that starts in the future
        if newDate <= cal.startOfDay(for: Date()) {
            selectedDate = newDate
        }
    }

    /// True when the current period already includes today — right chevron should be disabled.
    private var isPeriodAtPresent: Bool {
        let cal  = Calendar.current
        let now  = Date()
        switch selectedTimeRange {
        case .day:
            return cal.isDateInToday(selectedDate)
        case .week:
            // "this week" = the week that contains today
            return cal.component(.weekOfYear, from: selectedDate) == cal.component(.weekOfYear, from: now)
                && cal.component(.yearForWeekOfYear, from: selectedDate) == cal.component(.yearForWeekOfYear, from: now)
        case .month:
            return cal.component(.month, from: selectedDate) == cal.component(.month, from: now)
                && cal.component(.year,  from: selectedDate) == cal.component(.year,  from: now)
        case .year:
            return cal.component(.year, from: selectedDate) == cal.component(.year, from: now)
        case .all:
            return true
        }
    }

    /// Human-readable header for the current period.
    private var periodHeader: String {
        let cal = Calendar.current
        let now = Date()
        switch selectedTimeRange {
        case .day:
            if cal.isDateInToday(selectedDate)     { return "Today" }
            if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
            let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
            return f.string(from: selectedDate)

        case .week:
            // Show the Monday (or Sunday, respecting locale) of the week
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            let weekEnd   = cal.date(byAdding: .day, value: 6, to: weekStart)!
            if cal.component(.weekOfYear, from: weekStart) == cal.component(.weekOfYear, from: now)
                && cal.component(.yearForWeekOfYear, from: weekStart) == cal.component(.yearForWeekOfYear, from: now) {
                return "This Week"
            }
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "Week of \(f.string(from: weekStart)) – \(f.string(from: weekEnd))"

        case .month:
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            if cal.component(.month, from: selectedDate) == cal.component(.month, from: now)
                && cal.component(.year,  from: selectedDate) == cal.component(.year,  from: now) {
                return "This Month"
            }
            return f.string(from: selectedDate)

        case .year:
            let y = cal.component(.year, from: selectedDate)
            return y == cal.component(.year, from: now) ? "This Year" : "\(y)"

        case .all:
            return "All Time"
        }
    }
    
    /// Canonical anchor for a given range — used when the user switches segments
    /// so that stepping always works from a clean boundary.
    private func anchorDate(for range: TimeRange) -> Date {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .day:
            return cal.startOfDay(for: now)
        case .week:
            // Start of the current week (locale-aware)
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return cal.date(from: comps) ?? cal.startOfDay(for: now)
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            return cal.date(from: comps) ?? cal.startOfDay(for: now)
        case .year:
            let comps = cal.dateComponents([.year], from: now)
            return cal.date(from: comps) ?? cal.startOfDay(for: now)
        case .all:
            return now
        }
    }
    
    private var activityAnalytics: some View {
        VStack(spacing: 24) {
            // Statistics Cards
            statisticsCards
            
            // Total Time by Activity (Bar Chart)
            if !viewModel.activityTimeData.isEmpty {
                ChartCard(title: "Time by Activity") {
                    Chart(viewModel.activityTimeData) { item in
                        BarMark(
                            x: .value("Activity", item.name),
                            y: .value("Hours", item.hours)
                        )
                        .foregroundStyle(Color(hex: item.colorHex) ?? .blue)
                        .cornerRadius(8)
                    }
                    .frame(height: 250)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)  // Hide overlapping labels
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8) {
                        // Custom legend with colors
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.activityTimeData) { item in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: item.colorHex) ?? .blue)
                                        .frame(width: 10, height: 10)
                                    Text(item.name)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .chartAngleSelection(value: $selectedActivityName)
                    .overlay(alignment: .topTrailing) {
                        if let name = selectedActivityName,
                           let item = viewModel.activityTimeData.first(where: { $0.name == name }) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1fh", item.hours))
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 3)
                            .padding(8)
                        }
                    }
                }
            }
            
            // Activity Distribution (Pie Chart)
            if !viewModel.activityTimeData.isEmpty {
                ChartCard(title: "Activity Distribution") {
                    Chart(viewModel.activityTimeData) { item in
                        SectorMark(
                            angle: .value("Hours", item.hours),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Activity", item.name))
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                }
            }
            
            // Time Trend (Line Chart)
            if !viewModel.activityTrendData.isEmpty {
                ChartCard(title: "Activity Trend") {
                    Chart(viewModel.activityTrendData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Minutes", item.minutes)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Minutes", item.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
            
            // Empty State
            if viewModel.activityTimeData.isEmpty {
                emptyStateView(icon: "timer", message: "No activity data for this period")
            }
        }
    }
    
    // MARK: - Substance Analytics
    
    private var substanceAnalytics: some View {
        VStack(spacing: 24) {
            // Substance Statistics
            substanceStatisticsCards
            
            // Category selector pills
            if !viewModel.substanceCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All"] + viewModel.substanceCategories, id: \.self) { cat in
                            Button(cat) {
                                viewModel.selectedSubstanceCategory = cat
                            }
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedSubstanceCategory == cat ? .bold : .regular)
                            .foregroundColor(viewModel.selectedSubstanceCategory == cat ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedSubstanceCategory == cat ? Color.purple : Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Stats for selected category
            if viewModel.selectedSubstanceCategory != "All" {
                substanceCategoryStats
            }
            
            // Usage by type bar chart (filtered)
            if !viewModel.filteredSubstanceCountData.isEmpty {
                ChartCard(title: viewModel.selectedSubstanceCategory == "All" ? "Usage by Type" : "\(viewModel.selectedSubstanceCategory) — Methods") {
                    Chart(viewModel.filteredSubstanceCountData) { item in
                        BarMark(
                            x: .value("Type", item.name),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(Color.purple.gradient)
                        .cornerRadius(8)
                    }
                    .frame(height: 250)
                }
            }
            
            // Trend line (filtered)
            if !viewModel.filteredSubstanceTrendData.isEmpty && selectedTimeRange != .day {
                ChartCard(title: "Usage Trend") {
                    Chart(viewModel.filteredSubstanceTrendData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(Color.purple.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
            
            // Empty State
            if viewModel.filteredSubstanceCountData.isEmpty {
                emptyStateView(icon: "pill", message: "No substance data for this period")
            }
        }
    }
    
    private var substanceCategoryStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Logs",
                value: "\(viewModel.filteredTotalCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Daily Avg",
                value: viewModel.filteredDailyAvg,
                icon: "calendar",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Statistics Cards
    
    private var statisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Activities",
                value: "\(viewModel.totalActivities)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Total Time",
                value: viewModel.totalActivityTime,
                icon: "clock.fill",
                color: .blue
            )
            
            StatCard(
                title: "Most Tracked",
                value: viewModel.mostTrackedActivity,
                icon: "star.fill",
                color: .orange
            )
            
            StatCard(
                title: "Avg. Duration",
                value: viewModel.averageDuration,
                icon: "timer",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private var substanceStatisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Logs",
                value: "\(viewModel.totalSubstances)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Most Used",
                value: viewModel.mostUsedSubstance,
                icon: "star.fill",
                color: .purple
            )
            
            StatCard(
                title: "Daily Average",
                value: viewModel.averageSubstancePerDay,
                icon: "calendar",
                color: .orange
            )
            
            StatCard(
                title: "Top Method",
                value: viewModel.topMethod,
                icon: "pill.fill",
                color: .blue
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Biometric Analytics
    
    private var biometricAnalytics: some View {
        VStack(spacing: 24) {
            // Biometric Statistics
            biometricStatisticsCards
            
            // Weight Trend
            if !viewModel.weightTrendData.isEmpty {
                ChartCard(title: "Weight Trend") {
                    Chart(viewModel.weightTrendData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", item.value)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Weight", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 200)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
            
            // Sleep Duration Trend
            if !viewModel.sleepTrendData.isEmpty {
                ChartCard(title: "Sleep Duration") {
                    Chart(viewModel.sleepTrendData) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Hours", item.value)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
            }
            
            // Bed & Wake Time chart
            if !viewModel.bedWakeTimeData.isEmpty {
                ChartCard(title: "Bed & Wake Times") {
                    Chart(viewModel.bedWakeTimeData) { item in
                        LineMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Hour", item.hour)
                        )
                        .foregroundStyle(by: .value("Type", item.type))
                        .symbol(Circle())
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .frame(height: 250)
                    .chartYScale(domain: 18...32)
                    .chartYAxis {
                        AxisMarks(values: [18, 20, 22, 24, 26, 28, 30, 32]) { value in
                            AxisValueLabel {
                                let h = value.as(Int.self) ?? 0
                                let wrapped = h % 24
                                Text(wrapped == 0 ? "12 AM" : wrapped < 12 ? "\(wrapped) AM" : wrapped == 12 ? "12 PM" : "\(wrapped - 12) PM")
                                    .font(.caption2)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                                .font(.caption2)
                        }
                    }
                    .chartLegend(position: .bottom)
                }
            }

            // Mood Analytics
            if !viewModel.moodScatterData.isEmpty {
                moodStatisticsCards

                // Mood Heat Map
                ChartCard(title: "Mood Map") {
                    Chart {
                        // Quadrant reference lines
                        RuleMark(x: .value("Zero", 0))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                        ForEach(viewModel.moodScatterData) { point in
                            PointMark(
                                x: .value("Pleasantness", point.pleasantness),
                                y: .value("Energy", point.energy)
                            )
                            .foregroundStyle(moodPointColor(p: point.pleasantness, e: point.energy))
                            .symbolSize(60)
                            .opacity(0.7)
                        }
                    }
                    .frame(height: 280)
                    .chartXScale(domain: -1.1...1.1)
                    .chartYScale(domain: -1.1...1.1)
                    .chartXAxisLabel(position: .bottom) { Text("Pleasant →").font(.caption) }
                    .chartYAxisLabel(position: .leading) { Text("↑ Energy").font(.caption) }
                    .chartXAxis {
                        AxisMarks(values: [-1, -0.5, 0, 0.5, 1])
                    }
                    .chartYAxis {
                        AxisMarks(values: [-1, -0.5, 0, 0.5, 1])
                    }
                }

                // Mood Trend Lines
                if viewModel.moodTrendData.count > 1 {
                    ChartCard(title: "Mood Trend") {
                        Chart {
                            ForEach(viewModel.moodTrendData) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.pleasantness),
                                    series: .value("Series", "Pleasantness")
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle())
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                            ForEach(viewModel.moodTrendData) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.energy),
                                    series: .value("Series", "Energy")
                                )
                                .foregroundStyle(Color.blue)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle())
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                        }
                        .frame(height: 200)
                        .chartYScale(domain: -1...1)
                        .chartForegroundStyleScale([
                            "Pleasantness": Color.orange,
                            "Energy": Color.blue
                        ])
                        .chartLegend(position: .bottom)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.month().day())
                            }
                        }
                    }
                }

                // Quadrant Distribution (Donut)
                if viewModel.moodQuadrantData.contains(where: { $0.count > 0 }) {
                    ChartCard(title: "Quadrant Distribution") {
                        Chart(viewModel.moodQuadrantData) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(Color(hex: item.color) ?? .gray)
                            .cornerRadius(4)
                        }
                        .frame(height: 250)
                        .chartLegend(position: .bottom) {
                            FlowLayout(spacing: 8) {
                                ForEach(viewModel.moodQuadrantData) { item in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: item.color) ?? .gray)
                                            .frame(width: 10, height: 10)
                                        Text(item.quadrant.replacingOccurrences(of: "\n", with: " "))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty State
            if viewModel.weightTrendData.isEmpty && viewModel.sleepTrendData.isEmpty && viewModel.bedWakeTimeData.isEmpty && viewModel.moodScatterData.isEmpty {
                emptyStateView(icon: "heart.text.square", message: "No biometric data for this period")
            }
        }
    }
    
    private var biometricStatisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Total Entries",
                value: "\(viewModel.totalBiometrics)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Latest Weight",
                value: viewModel.latestWeight,
                icon: "scalemass.fill",
                color: .green
            )
            
            StatCard(
                title: "Avg Sleep",
                value: viewModel.averageSleep,
                icon: "moon.zzz.fill",
                color: .blue
            )
            
            StatCard(
                title: "Weight Change",
                value: viewModel.weightChange,
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var moodStatisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Mood Entries",
                value: "\(viewModel.totalMoodEntries)",
                icon: "face.smiling",
                color: .yellow
            )

            StatCard(
                title: "Avg Pleasantness",
                value: viewModel.averagePleasantness,
                icon: "arrow.left.and.right",
                color: .orange
            )

            StatCard(
                title: "Avg Energy",
                value: viewModel.averageEnergy,
                icon: "bolt.fill",
                color: .blue
            )

            StatCard(
                title: "Top Quadrant",
                value: viewModel.mostCommonQuadrant,
                icon: "square.grid.2x2",
                color: .green
            )
        }
        .padding(.horizontal)
    }

    private func moodPointColor(p: Double, e: Double) -> Color {
        if p >= 0 && e >= 0 { return .green }
        if p < 0 && e >= 0 { return .red }
        if p >= 0 && e < 0 { return .blue }
        return .gray
    }

    // MARK: - Empty State
    
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Start tracking to see analytics")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Supporting Views

struct ChartCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            content
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - Enums

enum AnalyticsCategory: String, CaseIterable {
    case activities = "Activities"
    case substances = "Substances"
    case biometrics = "Biometrics"
}

#Preview {
    NavigationStack {
        DataDisplayView()
    }
}

// MARK: - Flow Layout for Legend

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
