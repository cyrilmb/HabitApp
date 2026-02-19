//
//  CompactCircumplexGrid.swift
//  HabitTracker
//
//  Compact version of the circumplex mood grid (used in EditBiometricView)
//

import SwiftUI

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
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.primary.opacity(0.6))
                        .position(
                            x: half + CGFloat(label.x) * half * 0.95,
                            y: half - CGFloat(label.y) * half * 0.95
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
            // Top-right: High Energy + Pleasant (yellow)
            Rectangle()
                .fill(Color.yellow.opacity(0.10))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half / 2)
            // Top-left: High Energy + Unpleasant (red)
            Rectangle()
                .fill(Color.red.opacity(0.10))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half / 2)
            // Bottom-right: Low Energy + Pleasant (green)
            Rectangle()
                .fill(Color.green.opacity(0.10))
                .frame(width: half, height: half)
                .position(x: half + half / 2, y: half + half / 2)
            // Bottom-left: Low Energy + Unpleasant (blue)
            Rectangle()
                .fill(Color.blue.opacity(0.10))
                .frame(width: half, height: half)
                .position(x: half / 2, y: half + half / 2)
        }
    }
}
