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
    @State private var selectedPieActivity: String?
    @State private var selectedPieAngle: Double?
    @State private var selectedSubstanceName: String?
    @State private var selectedMoodQuadrant: String?
    @State private var selectedMoodAngle: Double?
    @State private var trendFilterActivity: String = "All"
    @AppStorage("weightUnit") private var weightUnit = "lbs"
    
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
                } else if selectedCategory == .biometrics {
                    biometricAnalytics
                } else {
                    habitsAnalytics
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.loadData(for: selectedTimeRange, date: selectedDate)
        }
    }
    
    // MARK: - X-Axis Helpers

    /// Stride component for date-based chart x-axes, adapting to the selected time range.
    private var xAxisStride: Calendar.Component {
        switch selectedTimeRange {
        case .day:       return .hour
        case .week:      return .day
        case .month:     return .weekOfYear
        case .sixMonths: return .month
        case .year:      return .month
        case .all:       return .quarter
        }
    }

    /// Date format for x-axis labels, adapting to the selected time range.
    private var xAxisDateFormat: Date.FormatStyle {
        switch selectedTimeRange {
        case .day:       return .dateTime.hour()
        case .week:      return .dateTime.weekday(.abbreviated)
        case .month:     return .dateTime.month(.abbreviated).day()
        case .sixMonths: return .dateTime.month(.abbreviated)
        case .year:      return .dateTime.month(.abbreviated)
        case .all:       return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    // MARK: - Period Navigation Helpers

    /// The latest allowed anchor date for the current range (today for all ranges).
    private var latestAnchor: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Move selectedDate (the anchor / last day of the window) by one window-width.
    private func shiftPeriod(by direction: Int) {
        let cal = Calendar.current
        guard let days = selectedTimeRange.dayCount else { return }
        guard let newDate = cal.date(byAdding: .day, value: direction * days, to: selectedDate) else { return }
        if newDate <= latestAnchor {
            selectedDate = newDate
        }
    }

    /// True when the window is at the most recent allowed position.
    private var isPeriodAtPresent: Bool {
        if selectedTimeRange == .all { return true }
        return selectedDate >= latestAnchor
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f
    }()
    private static let rangeHeaderFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    /// Human-readable header for the current period.
    private var periodHeader: String {
        let cal = Calendar.current
        guard let days = selectedTimeRange.dayCount else { return "All Time" }

        if days == 1 {
            if cal.isDateInToday(selectedDate) { return "Today" }
            if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
            return Self.dayHeaderFormatter.string(from: selectedDate)
        }

        let f = Self.rangeHeaderFormatter
        if selectedDate >= latestAnchor {
            let rangeStart = cal.date(byAdding: .day, value: -(days - 1), to: latestAnchor) ?? latestAnchor
            return "\(f.string(from: rangeStart)) – \(f.string(from: latestAnchor))"
        }

        let rangeStart = cal.date(byAdding: .day, value: -(days - 1), to: selectedDate) ?? selectedDate
        return "\(f.string(from: rangeStart)) – \(f.string(from: selectedDate))"
    }

    /// Canonical anchor for a given range (today for all ranges).
    private func anchorDate(for range: TimeRange) -> Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func goalProgressSection(for type: GoalCategoryType) -> some View {
        let items = viewModel.goalProgressItems.filter { $0.goal.categoryType == type }
        let streaks = viewModel.goalStreakData.filter { $0.categoryType == type }
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(items) { item in
                        let matchedStreak = streaks.first(where: { $0.goalName == item.goal.categoryName && $0.isTarget == (item.goal.kind == .target) })
                        GoalProgressCard(progress: item, streak: matchedStreak)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var habitGoalsSection: some View {
        let habitStreaks = viewModel.habitStreakData
        return Group {
            if !habitStreaks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(habitStreaks) { streak in
                        HabitStreakCard(streak: streak)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var activityAnalytics: some View {
        VStack(spacing: 24) {
            // Goal Progress
            goalProgressSection(for: .activity)

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
                        .opacity(selectedActivityName == nil || selectedActivityName == item.name ? 1.0 : 0.4)
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
                    .chartXSelection(value: $selectedActivityName)
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
                                Text("\(item.count) session\(item.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                        .foregroundStyle(Color(hex: item.colorHex) ?? .blue)
                        .opacity(selectedPieActivity == nil || selectedPieActivity == item.name ? 1.0 : 0.4)
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    .chartAngleSelection(value: $selectedPieAngle)
                    .onChange(of: selectedPieAngle) { _, newValue in
                        if let angle = newValue {
                            selectedPieActivity = findActivityItem(at: angle)
                        } else {
                            selectedPieActivity = nil
                        }
                    }
                    .chartLegend(.hidden)
                    .overlay(alignment: .topTrailing) {
                        if let name = selectedPieActivity,
                           let item = viewModel.activityTimeData.first(where: { $0.name == name }) {
                            let total = viewModel.activityTimeData.reduce(0.0) { $0 + $1.hours }
                            let pct = total > 0 ? (item.hours / total) * 100 : 0
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1fh", item.hours))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("\(item.count) session\(item.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f%%", pct))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 3)
                            .padding(8)
                        }
                    }

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
                    .padding(.top, 4)
                }
            }

            // Time Trend (Line Chart)
            if !viewModel.activityTrendData.isEmpty {
                ChartCard(title: "Activity Trend") {
                    // Activity filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["All"] + viewModel.activityTimeData.map(\.name), id: \.self) { name in
                                Button(name) {
                                    trendFilterActivity = name
                                }
                                .font(.subheadline)
                                .fontWeight(trendFilterActivity == name ? .bold : .regular)
                                .foregroundColor(trendFilterActivity == name ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(trendFilterActivity == name ? Color.blue : Color(.systemGray5))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Chart {
                        ForEach(filteredTrendData) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(trendLineColor(for: item.categoryName))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", item.date),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [trendLineColor(for: item.categoryName).opacity(0.3), trendLineColor(for: item.categoryName).opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }

                        // Goal lines (convert hours → minutes to match y-axis)
                        ForEach(activityGoalsForTrend, id: \.id) { goal in
                            RuleMark(y: .value("Goal", goalValueInMinutes(goal)))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
                                .font(.caption2)
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
            // Goal Progress
            goalProgressSection(for: .substance)

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
                        .opacity(selectedSubstanceName == nil || selectedSubstanceName == item.name ? 1.0 : 0.4)
                        .cornerRadius(8)
                    }
                    .frame(height: 250)
                    .chartXSelection(value: $selectedSubstanceName)
                    .overlay(alignment: .topTrailing) {
                        if let name = selectedSubstanceName,
                           let item = viewModel.filteredSubstanceCountData.first(where: { $0.name == name }) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("\(item.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(item.count == 1 ? "log" : "logs")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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

            // Trend line (filtered)
            if !viewModel.filteredSubstanceTrendData.isEmpty {
                ChartCard(title: "Usage Trend") {
                    Chart {
                        ForEach(viewModel.filteredSubstanceTrendData) { item in
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

                        // Substance goal lines (frequency goals with unit "times")
                        ForEach(substanceFrequencyGoals, id: \.id) { goal in
                            RuleMark(y: .value("Goal", goal.value))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
                                .font(.caption2)
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
                title: "Time Change",
                value: viewModel.activityTimeChange,
                icon: viewModel.activityTimeChange.hasPrefix("+") ? "arrow.up.right" : viewModel.activityTimeChange.hasPrefix("-") ? "arrow.down.right" : "equal.circle",
                color: viewModel.activityTimeChange.hasPrefix("+") ? .green : viewModel.activityTimeChange.hasPrefix("-") ? .red : .secondary
            )

            StatCard(
                title: "Sessions",
                value: viewModel.activityCountChange,
                icon: "number",
                color: viewModel.activityCountChange.hasPrefix("+") ? .green : viewModel.activityCountChange.hasPrefix("-") ? .red : .secondary
            )

            StatCard(
                title: "Busiest Day",
                value: viewModel.busiestDay,
                icon: "calendar",
                color: .orange
            )

            StatCard(
                title: "Avg Duration",
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
                title: "Usage Change",
                value: viewModel.substanceCountChange,
                icon: viewModel.substanceCountChange.hasPrefix("+") ? "arrow.up.right" : viewModel.substanceCountChange.hasPrefix("-") ? "arrow.down.right" : "equal.circle",
                color: viewModel.substanceCountChange.hasPrefix("+") ? .green : viewModel.substanceCountChange.hasPrefix("-") ? .red : .secondary
            )

            StatCard(
                title: "Trend",
                value: viewModel.substanceTrend,
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            StatCard(
                title: "Daily Avg",
                value: viewModel.averageSubstancePerDay,
                icon: "calendar",
                color: .orange
            )

            StatCard(
                title: "Top Method",
                value: viewModel.topMethod,
                icon: "pill.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Biometric Analytics
    
    private var biometricAnalytics: some View {
        VStack(spacing: 24) {
            // Goal Progress
            goalProgressSection(for: .biometric)

            // Biometric Statistics
            biometricStatisticsCards
            
            // Weight Trend
            if !viewModel.weightTrendData.isEmpty {
                ChartCard(title: "Weight Trend") {
                    Chart {
                        ForEach(viewModel.weightTrendData) { item in
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

                        // Weight goal lines
                        ForEach(goalsFor(type: .biometric, name: BiometricType.weight.rawValue), id: \.id) { goal in
                            RuleMark(y: .value("Goal", weightGoalChartValue(goal)))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartYScale(domain: weightYDomain)
                    .chartYAxisLabel(weightUnit, position: .trailing)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
                                .font(.caption2)
                        }
                    }
                }
            }

            // Sleep Duration Trend
            if !viewModel.sleepTrendData.isEmpty {
                ChartCard(title: "Sleep Duration") {
                    Chart {
                        ForEach(viewModel.sleepTrendData) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Hours", item.value)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(4)
                        }

                        // Sleep duration goal lines
                        ForEach(goalsFor(type: .biometric, name: BiometricType.sleepDuration.rawValue), id: \.id) { goal in
                            RuleMark(y: .value("Goal", goal.value))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            // Bed & Wake Time chart
            if !viewModel.bedWakeTimeData.isEmpty {
                let hours = viewModel.bedWakeTimeData.map(\.hour)
                let domainMin = floor((hours.min() ?? 20) / 2.0) * 2.0 - 2.0
                let domainMax = ceil((hours.max() ?? 34) / 2.0) * 2.0 + 2.0
                let yAxisValues = Array(stride(from: Int(domainMin), through: Int(domainMax), by: 2))

                ChartCard(title: "Bed & Wake Times") {
                    Chart {
                        ForEach(viewModel.bedWakeTimeData) { item in
                            LineMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Hour", item.hour)
                            )
                            .foregroundStyle(by: .value("Type", item.type))
                            .symbol(Circle())
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }

                        // Bed time goal line
                        ForEach(goalsFor(type: .biometric, name: BiometricType.bedTime.rawValue), id: \.id) { goal in
                            RuleMark(y: .value("Goal", bedTimeGoalChartHour(goal)))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }

                        // Wake time goal line
                        ForEach(goalsFor(type: .biometric, name: BiometricType.wakeTime.rawValue), id: \.id) { goal in
                            RuleMark(y: .value("Goal", goal.value))
                                .foregroundStyle(goalLineColor(for: goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .annotation(position: .bottom, alignment: .trailing) {
                                    Text(goalAnnotation(for: goal))
                                        .font(.caption2)
                                        .foregroundColor(goalLineColor(for: goal))
                                }
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: domainMin...domainMax)
                    .chartYAxis {
                        AxisMarks(values: yAxisValues) { value in
                            AxisValueLabel {
                                let h = value.as(Int.self) ?? 0
                                let wrapped = h % 24
                                Text(wrapped == 0 ? "12 AM" : wrapped < 12 ? "\(wrapped) AM" : wrapped == 12 ? "12 PM" : "\(wrapped - 12) PM")
                                    .font(.caption2)
                            }
                            AxisGridLine()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
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

                        // Mood goal crosshairs — pleasantness (vertical)
                        ForEach(moodPleasantnessGoals, id: \.id) { goal in
                            RuleMark(x: .value("Goal", goal.value))
                                .foregroundStyle(Color.orange.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        }

                        // Mood goal crosshairs — energy (horizontal)
                        ForEach(moodEnergyGoals, id: \.id) { goal in
                            RuleMark(y: .value("Goal", goal.value))
                                .foregroundStyle(Color.blue.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        }

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

                            // Mood pleasantness goal lines
                            ForEach(moodPleasantnessGoals, id: \.id) { goal in
                                RuleMark(y: .value("Goal", goal.value))
                                    .foregroundStyle(Color.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text(goalAnnotation(for: goal))
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                            }

                            // Mood energy goal lines
                            ForEach(moodEnergyGoals, id: \.id) { goal in
                                RuleMark(y: .value("Goal", goal.value))
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text(goalAnnotation(for: goal))
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
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
                            AxisMarks(values: .stride(by: xAxisStride)) { _ in
                                AxisValueLabel(format: xAxisDateFormat)
                                    .font(.caption2)
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
                            .opacity(selectedMoodQuadrant == nil || selectedMoodQuadrant == item.quadrant ? 1.0 : 0.4)
                            .cornerRadius(4)
                        }
                        .frame(height: 250)
                        .chartAngleSelection(value: $selectedMoodAngle)
                        .onChange(of: selectedMoodAngle) { _, newValue in
                            if let angle = newValue {
                                selectedMoodQuadrant = findMoodQuadrant(at: angle)
                            } else {
                                selectedMoodQuadrant = nil
                            }
                        }
                        .chartLegend(.hidden)
                        .overlay {
                            if let quadrant = selectedMoodQuadrant,
                               let item = viewModel.moodQuadrantData.first(where: { $0.quadrant == quadrant }) {
                                let total = viewModel.moodQuadrantData.reduce(0) { $0 + $1.count }
                                let pct = total > 0 ? (Double(item.count) / Double(total)) * 100 : 0
                                VStack(spacing: 2) {
                                    Text(quadrant.replacingOccurrences(of: "\n", with: " "))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("\(item.count)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text(item.count == 1 ? "entry" : "entries")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f%%", pct))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

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
                        .padding(.top, 4)
                    }
                }
            }

            // Empty State
            if viewModel.weightTrendData.isEmpty && viewModel.sleepTrendData.isEmpty && viewModel.bedWakeTimeData.isEmpty && viewModel.moodScatterData.isEmpty {
                emptyStateView(icon: "heart.text.square", message: "No biometric data for this period")
            }
        }
    }
    
    // MARK: - Habits Analytics

    private var habitsAnalytics: some View {
        VStack(spacing: 24) {
            // Goals (includes habit streaks)
            habitGoalsSection

            // Stat Cards
            if viewModel.totalHabits > 0 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Completions",
                        value: "\(viewModel.periodCompletions)",
                        icon: "checkmark.circle.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Rate Change",
                        value: viewModel.completionRateChange,
                        icon: viewModel.completionRateChange.hasPrefix("+") ? "arrow.up.right" : viewModel.completionRateChange.hasPrefix("-") ? "arrow.down.right" : "equal.circle",
                        color: viewModel.completionRateChange.hasPrefix("+") ? .green : viewModel.completionRateChange.hasPrefix("-") ? .red : .secondary
                    )

                    StatCard(
                        title: "Completion Rate",
                        value: viewModel.completionRate,
                        icon: "percent",
                        color: .orange
                    )

                    StatCard(
                        title: "Best Streak",
                        value: viewModel.bestOverallStreak,
                        icon: "flame.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)
            }

            // Daily Completions Bar Chart
            if !viewModel.dailyHabitCompletionData.isEmpty {
                ChartCard(title: "Daily Completions") {
                    Chart(viewModel.dailyHabitCompletionData) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Completed", item.count)
                        )
                        .foregroundStyle(
                            item.total > 0 && item.count >= item.total
                                ? Color.green.gradient
                                : Color.blue.gradient
                        )
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: xAxisStride)) { _ in
                            AxisValueLabel(format: xAxisDateFormat)
                                .font(.caption2)
                        }
                    }
                }
            }

            // Empty State
            if viewModel.totalHabits == 0 {
                emptyStateView(icon: "checklist", message: "No habits configured yet")
            }
        }
    }

    private var biometricStatisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Latest Weight",
                value: viewModel.latestWeight,
                icon: "scalemass.fill",
                color: .green
            )

            StatCard(
                title: "Weight Change",
                value: viewModel.weightChange,
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )

            StatCard(
                title: "Avg Sleep",
                value: viewModel.averageSleep,
                icon: "moon.zzz.fill",
                color: .blue
            )

            StatCard(
                title: "Sleep Change",
                value: viewModel.sleepChange,
                icon: viewModel.sleepChange.hasPrefix("+") ? "arrow.up.right" : viewModel.sleepChange.hasPrefix("-") ? "arrow.down.right" : "equal.circle",
                color: viewModel.sleepChange.hasPrefix("+") ? .green : viewModel.sleepChange.hasPrefix("-") ? .red : .secondary
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

    // MARK: - Goal Line Helpers

    /// Returns active goals matching a category type and optionally a specific category name.
    private func goalsFor(type: GoalCategoryType, name: String? = nil) -> [Goal] {
        viewModel.goalProgressItems
            .map(\.goal)
            .filter { $0.categoryType == type && $0.isActive && (name == nil || $0.categoryName == name) }
    }

    /// Color for a goal line — green for targets, orange for limits.
    private func goalLineColor(for goal: Goal) -> Color {
        goal.kind == .target ? .green : .orange
    }

    /// Annotation label for a goal line, including the goal's category name.
    private func goalAnnotation(for goal: Goal) -> String {
        let comp: String
        switch goal.comparison {
        case .atLeast: comp = "\u{2265}"
        case .atMost: comp = "\u{2264}"
        case .exactly: comp = "="
        }
        let formatted = GoalFormatters.formatGoalValue(goal.value, goal: goal)
        let unitText = GoalFormatters.formatGoalUnit(goal)
        let valueStr = "\(comp) \(formatted)\(unitText.isEmpty ? "" : " \(unitText)")"
        return "\(goal.categoryName): \(valueStr)"
    }

    /// Substance goals filtered for the current category selection and unit type "times".
    /// Returns empty when "All" is selected — goal lines only show for a specific category.
    private var substanceFrequencyGoals: [Goal] {
        guard viewModel.selectedSubstanceCategory != "All" else { return [] }
        return goalsFor(type: .substance, name: viewModel.selectedSubstanceCategory)
            .filter { $0.unit == "times" }
    }

    /// Activity goals filtered for the current trend filter.
    /// Returns empty when "All" is selected — goal lines only show for a specific activity.
    private var activityGoalsForTrend: [Goal] {
        guard trendFilterActivity != "All" else { return [] }
        return goalsFor(type: .activity, name: trendFilterActivity)
    }

    /// Convert a goal's value to minutes for the activity trend chart y-axis.
    private func goalValueInMinutes(_ goal: Goal) -> Double {
        goal.unit == "hours" ? goal.value * 60 : goal.value
    }

    /// Y-axis domain for the weight trend chart, centered on the data with ~18 unit window.
    private var weightYDomain: ClosedRange<Double> {
        let values = viewModel.weightTrendData.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let dataRange = hi - lo
        let padding = max((20 - dataRange) / 2, 4)
        return (lo - padding)...(hi + padding)
    }

    /// Convert a weight goal value to match the chart's display unit.
    private func weightGoalChartValue(_ goal: Goal) -> Double {
        // Chart data is already converted to the display unit by the view model.
        // Convert the goal value to match.
        if weightUnit == "kg" {
            return goal.unit == "kg" ? goal.value : GoalFormatters.lbsToKg(goal.value)
        } else {
            return goal.unit == "kg" ? GoalFormatters.kgToLbs(goal.value) : goal.value
        }
    }

    /// For bed time goals, adjust to 24+ range if before noon (after-midnight bed times).
    private func bedTimeGoalChartHour(_ goal: Goal) -> Double {
        goal.value < 12 ? goal.value + 24 : goal.value
    }

    /// Mood goals filtered to pleasantness axis only.
    private var moodPleasantnessGoals: [Goal] {
        goalsFor(type: .biometric, name: BiometricType.mood.rawValue)
            .filter { $0.unit == "pleasantness" }
    }

    /// Mood goals filtered to energy axis only.
    private var moodEnergyGoals: [Goal] {
        goalsFor(type: .biometric, name: BiometricType.mood.rawValue)
            .filter { $0.unit == "energy" }
    }

    // MARK: - Activity Trend Helpers

    private var filteredTrendData: [TrendData] {
        let data = viewModel.activityTrendData
        if trendFilterActivity == "All" {
            // Aggregate all activities per day
            let byDate = Dictionary(grouping: data) { $0.date }
            return byDate.map { date, items in
                TrendData(date: date, minutes: items.reduce(0) { $0 + $1.minutes }, categoryName: "All")
            }.sorted { $0.date < $1.date }
        }
        return data.filter { $0.categoryName == trendFilterActivity }
    }

    private func trendLineColor(for categoryName: String) -> Color {
        if let item = viewModel.activityTimeData.first(where: { $0.name == categoryName }) {
            return Color(hex: item.colorHex) ?? .blue
        }
        return .blue
    }

    private func moodPointColor(p: Double, e: Double) -> Color {
        if p >= 0 && e >= 0 { return .yellow }   // High energy + Pleasant (Yale yellow)
        if p < 0 && e >= 0 { return .red }        // High energy + Unpleasant (Yale red)
        if p >= 0 && e < 0 { return .green }       // Low energy + Pleasant (Yale green)
        return .blue                                // Low energy + Unpleasant (Yale blue)
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

    private func findActivityItem(at angle: Double) -> String? {
        var cumulative = 0.0
        for item in viewModel.activityTimeData {
            cumulative += item.hours
            if angle <= cumulative {
                return item.name
            }
        }
        return viewModel.activityTimeData.last?.name
    }

    private func findMoodQuadrant(at angle: Double) -> String? {
        var cumulative = 0.0
        for item in viewModel.moodQuadrantData {
            cumulative += Double(item.count)
            if angle <= cumulative {
                return item.quadrant
            }
        }
        return viewModel.moodQuadrantData.last?.quadrant
    }
}

// MARK: - Enums

enum AnalyticsCategory: String, CaseIterable {
    case activities = "Activities"
    case substances = "Substances"
    case biometrics = "Biometrics"
    case habits = "Habits"
}

// MARK: - Habit Streak Card

struct HabitStreakCard: View {
    let streak: HabitStreakData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: streak.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color(hex: streak.colorHex) ?? .blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(streak.habitName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Best: \(streak.bestStreak) day\(streak.bestStreak == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(streak.currentStreak > 0 ? .orange : .secondary)
                Text("\(streak.currentStreak)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(streak.currentStreak > 0 ? .primary : .secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

// MARK: - Goal Streak Card

struct GoalStreakCard: View {
    let streak: GoalStreakData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: streak.isTarget ? "target" : "hand.raised.fill")
                .font(.title3)
                .foregroundColor(streak.isTarget ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(streak.goalName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(streak.isTarget ? "Target" : "Limit")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(streak.isTarget ? Color.green : Color.orange)
                        .clipShape(Capsule())
                }
                Text("Best: \(streak.bestStreak) \(streak.periodLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(streak.currentStreak)")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(streak.periodLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

#Preview {
    NavigationStack {
        DataDisplayView()
    }
}

