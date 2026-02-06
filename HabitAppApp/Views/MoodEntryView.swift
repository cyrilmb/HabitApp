//
//  MoodEntryView.swift
//  HabitTracker
//
//  2D Russell Circumplex grid for mood entry
//

import SwiftUI

// MARK: - Emotion Label Model

struct EmotionLabel {
    let name: String
    let x: Double  // pleasantness: -1 (unpleasant) to +1 (pleasant)
    let y: Double  // energy:       -1 (low) to +1 (high)
}

let emotionLabels: [EmotionLabel] = [
    // Top-Right (High Energy + Pleasant)
    EmotionLabel(name: "Excited",  x:  0.7,  y:  0.7),
    EmotionLabel(name: "Happy",    x:  0.85, y:  0.4),
    EmotionLabel(name: "Alert",    x:  0.4,  y:  0.85),
    // Bottom-Right (Low Energy + Pleasant)
    EmotionLabel(name: "Content",  x:  0.7,  y: -0.4),
    EmotionLabel(name: "Serene",   x:  0.85, y: -0.7),
    EmotionLabel(name: "Relaxed",  x:  0.4,  y: -0.7),
    EmotionLabel(name: "Calm",     x:  0.6,  y: -0.85),
    // Top-Left (High Energy + Unpleasant)
    EmotionLabel(name: "Tense",    x: -0.4,  y:  0.85),
    EmotionLabel(name: "Nervous",  x: -0.7,  y:  0.7),
    EmotionLabel(name: "Stressed", x: -0.85, y:  0.5),
    EmotionLabel(name: "Angry",    x: -0.7,  y:  0.4),
    // Bottom-Left (Low Energy + Unpleasant)
    EmotionLabel(name: "Sad",       x: -0.7,  y: -0.4),
    EmotionLabel(name: "Depressed", x: -0.85, y: -0.7),
    EmotionLabel(name: "Bored",     x: -0.4,  y: -0.7),
    EmotionLabel(name: "Fatigued",  x: -0.6,  y: -0.85),
]

/// Returns the nearest emotion label for a given (pleasantness, energy) position.
func nearestEmotionLabel(pleasantness: Double, energy: Double) -> String {
    var closest = emotionLabels[0]
    var minDist = Double.greatestFiniteMagnitude
    for label in emotionLabels {
        let dx = label.x - pleasantness
        let dy = label.y - energy
        let dist = dx * dx + dy * dy
        if dist < minDist {
            minDist = dist
            closest = label
        }
    }
    return closest.name
}

// MARK: - Mood Entry View

struct MoodEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pleasantness: Double = 0.0
    @State private var energy: Double = 0.0
    @State private var notes: String = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.yellow)
                    Text("Mood")
                        .font(.headline)
                }
            }

            Section {
                circumplexGrid
                    .padding(.vertical, 8)
            } header: {
                Text("Tap or drag to select your mood")
            } footer: {
                Text("Nearest: \(nearestEmotionLabel(pleasantness: pleasantness, energy: energy))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Section {
                TextEditor(text: $notes)
                    .frame(height: 80)
            } header: {
                Text("Notes (Optional)")
            }
        }
        .navigationTitle("Log Mood")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: saveMood) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.yellow.gradient)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Circumplex Grid

    private var circumplexGrid: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.width)
            let half = size / 2

            ZStack {
                // Quadrant backgrounds
                quadrantBackgrounds(size: size)

                // Crosshair lines
                Path { path in
                    path.move(to: CGPoint(x: half, y: 0))
                    path.addLine(to: CGPoint(x: half, y: size))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: half))
                    path.addLine(to: CGPoint(x: size, y: half))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                // Axis labels
                Text("Pleasant")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: size - 30, y: half - 10)
                Text("Unpleasant")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: 38, y: half - 10)
                Text("High Energy")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: half, y: 10)
                Text("Low Energy")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: half, y: size - 10)

                // Emotion word labels
                ForEach(emotionLabels, id: \.name) { label in
                    Text(label.name)
                        .font(.system(size: 10))
                        .foregroundColor(.primary.opacity(0.7))
                        .position(
                            x: half + CGFloat(label.x) * half * 0.9,
                            y: half - CGFloat(label.y) * half * 0.9
                        )
                }

                // Selected position dot
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(
                        x: half + CGFloat(pleasantness) * half,
                        y: half - CGFloat(energy) * half
                    )
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(-1, min(1, Double((value.location.x - half) / half)))
                        let y = max(-1, min(1, Double((half - value.location.y) / half)))
                        pleasantness = x
                        energy = y
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func quadrantBackgrounds(size: CGFloat) -> some View {
        let half = size / 2
        return ZStack {
            // Top-right: High Energy + Pleasant (green-ish)
            Rectangle()
                .fill(Color.green.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half / 2)
            // Top-left: High Energy + Unpleasant (red-ish)
            Rectangle()
                .fill(Color.red.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half / 2)
            // Bottom-right: Low Energy + Pleasant (blue-ish)
            Rectangle()
                .fill(Color.blue.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half + half / 2)
            // Bottom-left: Low Energy + Unpleasant (gray-ish)
            Rectangle()
                .fill(Color.gray.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half + half / 2)
        }
    }

    // MARK: - Save

    private func saveMood() {
        isSaving = true
        let userId = FirebaseService.shared.userId

        Task {
            do {
                var biometric = Biometric(
                    userId: userId,
                    type: .mood,
                    value: pleasantness,
                    unit: "mood",
                    secondaryValue: energy
                )
                biometric.notes = notes.isEmpty ? nil : notes

                try await FirebaseService.shared.saveBiometric(biometric)

                await MainActor.run {
                    isSaving = false
                    SheetManager.shared.dismissAndToast(.biometric)
                }
            } catch {
                print("Error saving mood: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Compact Circumplex Grid (for EditBiometricView)

struct CompactCircumplexGrid: View {
    @Binding var pleasantness: Double
    @Binding var energy: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.width)
            let half = size / 2

            ZStack {
                // Quadrant backgrounds
                quadrantBackgrounds(size: size)

                // Crosshair
                Path { path in
                    path.move(to: CGPoint(x: half, y: 0))
                    path.addLine(to: CGPoint(x: half, y: size))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: half))
                    path.addLine(to: CGPoint(x: size, y: half))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                // Axis labels
                Text("Pleasant")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: size - 30, y: half - 10)
                Text("Unpleasant")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: 38, y: half - 10)
                Text("High Energy")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: half, y: 10)
                Text("Low Energy")
                    .font(.caption2).foregroundColor(.secondary)
                    .position(x: half, y: size - 10)

                // Emotion word labels
                ForEach(emotionLabels, id: \.name) { label in
                    Text(label.name)
                        .font(.system(size: 9))
                        .foregroundColor(.primary.opacity(0.6))
                        .position(
                            x: half + CGFloat(label.x) * half * 0.9,
                            y: half - CGFloat(label.y) * half * 0.9
                        )
                }

                // Dot
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(
                        x: half + CGFloat(pleasantness) * half,
                        y: half - CGFloat(energy) * half
                    )
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(-1, min(1, Double((value.location.x - half) / half)))
                        let y = max(-1, min(1, Double((half - value.location.y) / half)))
                        pleasantness = x
                        energy = y
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func quadrantBackgrounds(size: CGFloat) -> some View {
        let half = size / 2
        return ZStack {
            Rectangle()
                .fill(Color.green.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half / 2)
            Rectangle()
                .fill(Color.red.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half / 2)
            Rectangle()
                .fill(Color.blue.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half + half / 2)
            Rectangle()
                .fill(Color.gray.opacity(0.07))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half + half / 2)
        }
    }
}

#Preview {
    NavigationStack {
        MoodEntryView()
    }
}
