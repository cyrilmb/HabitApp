//
//  SubstanceHelpers.swift
//  HabitTracker
//
//  Shared icon and color helpers for substance categories
//

import SwiftUI

func iconForSubstanceCategory(_ name: String) -> String {
    let lowercased = name.lowercased()
    if lowercased.contains("alcohol") {
        return "wineglass"
    } else if lowercased.contains("cannabis") || lowercased.contains("marijuana") {
        return "leaf"
    } else if lowercased.contains("caffeine") || lowercased.contains("coffee") {
        return "cup.and.saucer"
    } else if lowercased.contains("tobacco") || lowercased.contains("nicotine") {
        return "smoke"
    } else {
        return "pill"
    }
}

func colorForSubstanceCategory(_ name: String) -> Color {
    let lowercased = name.lowercased()
    if lowercased.contains("alcohol") {
        return .red
    } else if lowercased.contains("cannabis") {
        return .green
    } else if lowercased.contains("caffeine") {
        return .brown
    } else if lowercased.contains("tobacco") {
        return .gray
    } else {
        return .purple
    }
}

func iconForSubstanceMethod(_ method: String) -> String {
    let lowercased = method.lowercased()
    if lowercased.contains("beer") { return "mug" }
    else if lowercased.contains("wine") { return "wineglass" }
    else if lowercased.contains("shot") { return "wineglass.fill" }
    else if lowercased.contains("cocktail") { return "cup.and.saucer.fill" }
    else if lowercased.contains("joint") { return "flame" }
    else if lowercased.contains("vape") { return "cloud" }
    else if lowercased.contains("edible") { return "fork.knife" }
    else if lowercased.contains("pipe") { return "circle.circle" }
    else if lowercased.contains("coffee") { return "cup.and.saucer" }
    else if lowercased.contains("tea") { return "cup.and.saucer" }
    else { return "circle.fill" }
}
