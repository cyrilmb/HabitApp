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
    @State private var selectedSubstanceName: String?
    @State private var selectedMoodQuadrant: String?
    @State private var trendFilterActivity: String = "All"
    
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
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(items) { item in
                        GoalProgressCard(progress: item)
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
                    .chartAngleSelection(value: $selectedPieActivity)
                    .chartLegend(.hidden)
                    .overlay {
                        if let name = selectedPieActivity,
                           let item = viewModel.activityTimeData.first(where: { $0.name == name }) {
                            let total = viewModel.activityTimeData.reduce(0.0) { $0 + $1.hours }
                            let pct = total > 0 ? (item.hours / total) * 100 : 0
                            VStack(spacing: 2) {
                                Text(name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1fh", item.hours))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("\(item.count) sessions")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f%%", pct))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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

                    Chart(filteredTrendData) { item in
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
            // Goal Progress
            goalProgressSection(for: .biometric)

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
                        .chartAngleSelection(value: $selectedMoodQuadrant)
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

