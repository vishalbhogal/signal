// BurnoutRiskEngine.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// ─────────────────────────────────────────────────────────────────────────────
// HOW CORE ML WORKS (read this first)
// ─────────────────────────────────────────────────────────────────────────────
//
// Core ML is Apple's framework for running trained machine learning models
// entirely on-device — no server, no network call, no data leaves the phone.
//
// A Core ML model (.mlmodel file) is a binary that encodes:
//   1. The model architecture (e.g. decision tree, neural network)
//   2. The trained weights (numbers learned from training data)
//   3. The input/output schema (what types go in, what types come out)
//
// For a model named "BurnoutRiskModel.mlmodel" Xcode generates:
//   - BurnoutRiskModel          (the model class)
//   - BurnoutRiskModelInput     (struct with your feature properties)
//   - BurnoutRiskModelOutput    (struct with prediction result properties)
//
// Inference flow:
//   1. Create a BurnoutRiskModelInput with your numeric features
//   2. Call model.prediction(input:) — this runs the math on-device
//   3. Read the output's burnoutRisk probability (0.0–1.0)
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY WE'RE MOCKING IT HERE
// ─────────────────────────────────────────────────────────────────────────────
//
// Training a real model requires labeled historical data
// which we don't have yet. So BurnoutRiskEngine uses a hand-tuned scoring
// formula that mimics what a trained model would output.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
// MARK: - Protocol

/// `async throws` real model load from disk could fail or take time with CoreML.
protocol BurnoutRiskEngineProtocol {
    func predict(features: WeeklyBehavioralFeatures) async throws -> BurnoutRiskScore
}

// MARK: - Mock Engine (Formula-Based)

/// Scores burnout risk using a weighted formula across 5 behavioral signals.
final class MockBurnoutRiskEngine: BurnoutRiskEngineProtocol {

    func predict(features: WeeklyBehavioralFeatures) async throws -> BurnoutRiskScore {

        // ─── SCORING LOGIC ───────────────────────────────────────────────────
        // Weights are chosen based on published burnout research:
        //   Sleep and HRV -> strongest physiological predictors.
        //   Work hours -> captures the environmental load.
        //   Steps and active minutes -> reflect recovery behavior.
        
//        The formula, broken down:
//
//        ┌────────┬────────────────────┬────────┬────────────────────────────┐
//        │ Signal │      Formula       │ Weight │ Example (avg values above) │
//        ├────────┼────────────────────┼────────┼────────────────────────────┤
//        │ Sleep  │ (8 - avgSleep) / 8 │ 30%    │ (8 - 6.8) / 8 = 0.15       │
//        ├────────┼────────────────────┼────────┼────────────────────────────┤
//        │ HRV    │ (70 - avgHRV) / 70 │ 30%    │ (70 - 41) / 70 = 0.41      │
//        ├────────┼────────────────────┼────────┼────────────────────────────┤
//        │ Work   │ (avgWork - 8) / 6  │ 20%    │ (10.2 - 8) / 6 = 0.37      │
//        ├────────┼────────────────────┼────────┼────────────────────────────┤
//        │ Steps  │ 1 - steps / 10000  │ 10%    │ 1 - 5200/10000 = 0.48      │
//        ├────────┼────────────────────┼────────┼────────────────────────────┤
//        │ Active │ 1 - active / 30    │ 10%    │ 1 - 28/30 = 0.07           │
//        └────────┴────────────────────┴────────┴────────────────────────────┘
//
//        Raw score = (0.15 × 0.30) + (0.41 × 0.30) + (0.37 × 0.20) + (0.48 × 0.10) + (0.07 × 0.10)
//        = 0.045 + 0.123 + 0.074 + 0.048 + 0.007 = 0.297
//
//        Bucketing: < 0.35 → .low, 0.35–0.65 → .moderate, > 0.65 → .high

        // Sleep score: fewer hours → higher risk.
        let sleepScore = max(0, (8.0 - features.avgSleepHours) / 8.0)
        // e.g. 6 hrs sleep → (8-6)/8 = 0.25 risk contribution

        // HRV score: lower HRV → higher stress → higher risk.
        let hrvScore = max(0, (70.0 - features.avgHRV) / 70.0)
        // e.g. 35ms HRV → (70-35)/70 = 0.50 risk contribution

        // Work hours score: more hours → higher risk.
        // Anything above 8h contributes; we cap the penalty at 14h.
        let workScore = min(1.0, max(0, (features.avgWorkHours - 8.0) / 6.0))
        // e.g. 11h work → (11-8)/6 = 0.50 risk contribution

        // Activity score: fewer steps → higher risk.
        // 10,000 steps is used as the "fully active" reference.
        let stepScore = max(0, 1.0 - (features.avgStepCount / 10_000.0))
        // e.g. 4,000 steps → 1 - 0.4 = 0.60 risk contribution

        // Active minutes score: under 30 min/day → elevated risk.
        let activeScore = max(0, 1.0 - (features.avgActiveMinutes / 30.0))

        // ─── WEIGHTED SUM ────────────────────────────────────────────────────
        // Weights: sleep 30%, hrv 30%, work 20%, steps 10%, active 10%
        let rawScore = (sleepScore  * 0.30)
                     + (hrvScore    * 0.30)
                     + (workScore   * 0.20)
                     + (stepScore   * 0.10)
                     + (activeScore * 0.10)

        let finalScore = min(1.0, max(0.0, rawScore))

        // ─── BUCKET INTO RISK LEVEL ──────────────────────────────────────────
        // Thresholds chosen to match clinical burnout literature:
        //   < 0.35 → Low risk
        //   0.35–0.65 → Moderate (watch and act)
        //   > 0.65 → High (intervention recommended)
        let level: RiskLevel
        switch finalScore {
        case 0..<0.35:  level = .low
        case 0.35..<0.65: level = .moderate
        default:        level = .high
        }

        return BurnoutRiskScore(score: finalScore, level: level, date: Date())
    }
}

// MARK: - Real Core ML Engine (Reference — not yet active)

//
// final class CoreMLBurnoutRiskEngine: BurnoutRiskEngineProtocol {

//     private let model: BurnoutRiskModel
//
//     init() throws {
//         // `BurnoutRiskModel()` loads the compiled .mlmodelc from the app bundle.
//         // This can throw if the model file is missing or corrupted.
//         self.model = try BurnoutRiskModel()
//     }
//
//     func predict(features: WeeklyBehavioralFeatures) async throws -> BurnoutRiskScore {
//
//         // Build the auto-generated input struct with your feature values.
//         let input = BurnoutRiskModelInput(
//             avgSleepHours: features.avgSleepHours,
//             avgStepCount: features.avgStepCount,
//             avgActiveMinutes: Double(features.avgActiveMinutes),
//             avgHRV: features.avgHRV,
//             avgWorkHours: features.avgWorkHours,
//             sleepDeficitDays: Double(features.sleepDeficitDays),
//             highWorkloadDays: Double(features.highWorkloadDays)
//         )
//
//         // model.prediction(input:) runs the neural network / decision tree on-device.
//         let output = try model.prediction(input: input)
//
//         // `burnoutRiskProbability` is the output feature defined in the .mlmodel.
//         // It's a dictionary: ["low": 0.2, "moderate": 0.3, "high": 0.5]
//         let highProb = output.burnoutRiskProbability["high"] ?? 0
//         let modProb  = output.burnoutRiskProbability["moderate"] ?? 0
//
//         let score = highProb + (modProb * 0.5) // blend into a single 0–1 score
//         let level: RiskLevel = highProb > 0.5 ? .high : modProb > 0.5 ? .moderate : .low
//
//         return BurnoutRiskScore(score: score, level: level, date: Date())
//     }
// }
