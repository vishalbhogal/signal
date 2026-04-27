// MetricChartView.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//
// Smooth area + line chart for each behavioral metric.
// Each metric gets its own accent color from the Signal design system.
// No bar charts — smooth catmullRom curves with gradient fills.

import SwiftUI
import Charts

enum HealthMetric {
    case sleep, steps, hrv, workHours

    func value(from s: DailyHealthSnapshot) -> Double {
        switch self {
        case .sleep:     return s.sleepHours
        case .steps:     return Double(s.stepCount) / 1000   // Show in thousands
        case .hrv:       return s.heartRateVariability
        case .workHours: return s.workHours
        }
    }

    var yLabel: String {
        switch self {
        case .sleep:     return "Hours"
        case .steps:     return "k Steps"
        case .hrv:       return "ms"
        case .workHours: return "Hours"
        }
    }

    // Each metric has a distinct accent color — avoids monotone charts.
    var lineColor: Color {
        switch self {
        case .sleep:     return Signal.SUI.sleepLine
        case .steps:     return Signal.SUI.stepsLine
        case .hrv:       return Signal.SUI.hrvLine
        case .workHours: return Signal.SUI.workLine
        }
    }

    var areaColor: Color {
        switch self {
        case .sleep:     return Signal.SUI.sleepArea
        case .steps:     return Signal.SUI.stepsArea
        case .hrv:       return Signal.SUI.hrvArea
        case .workHours: return Signal.SUI.workArea
        }
    }

    /// Dashed reference line value — nil if no clinically meaningful threshold.
    var referenceValue: Double? {
        switch self {
        case .sleep:     return 7.0          // Recommended hours
        case .steps:     return 7.5          // WHO: 7,500 steps (in thousands)
        case .hrv:       return 35.0         // Healthy HRV floor
        case .workHours: return 8.0          // Standard shift
        }
    }

    var referenceLabel: String {
        switch self {
        case .sleep:     return "7h target"
        case .steps:     return "7.5k target"
        case .hrv:       return "35ms floor"
        case .workHours: return "8h shift"
        }
    }
}

struct MetricChartView: View {
    let snapshots: [DailyHealthSnapshot]
    let metric: HealthMetric

    private var sorted: [DailyHealthSnapshot] {
        snapshots.sorted { $0.date < $1.date }
    }

    var body: some View {
        Chart(sorted) { snap in

            // ── Gradient area fill ────────────────────────────────────────
            AreaMark(
                x: .value("Day",   snap.date, unit: .day),
                y: .value("Value", metric.value(from: snap))
            )
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: metric.lineColor.opacity(0.5), location: 0.0),
                        .init(color: metric.areaColor.opacity(0.2), location: 0.5),
                        .init(color: Color.clear,                   location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint:   .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // ── Smooth line ───────────────────────────────────────────────
            LineMark(
                x: .value("Day",   snap.date, unit: .day),
                y: .value("Value", metric.value(from: snap))
            )
            .foregroundStyle(metric.lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            // ── Data point dots ───────────────────────────────────────────
            PointMark(
                x: .value("Day",   snap.date, unit: .day),
                y: .value("Value", metric.value(from: snap))
            )
            .foregroundStyle(metric.lineColor)
            .symbolSize(24)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 10))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.12))
                AxisValueLabel().font(.system(size: 10))
            }
        }
        // ── Dashed reference line ─────────────────────────────────────────
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let ref = metric.referenceValue,
                   let yPos = proxy.position(forY: ref) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yPos))
                        path.addLine(to: CGPoint(x: geo.size.width, y: yPos))
                    }
                    .stroke(
                        Color(hex: "E76F51").opacity(0.65),
                        style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                    )

                    Text(metric.referenceLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "E76F51"))
                        .position(x: geo.size.width - 32, y: yPos - 9)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
