// SleepChartView.swift
// Signal
//
// A visually rich SwiftUI sleep area chart with:
//   • Smooth catmullRom curve (no jagged angles)
//   • Multi-stop gradient fill from ocean blue → transparent
//   • Bold line stroke on top of the gradient
//   • Dot annotation at each data point
//   • Dashed red reference line at 6h (clinical minimum)
//   • Point callout bubble on the highest value

import SwiftUI
import Charts

struct SleepChartView: View {

    let snapshots: [DailyHealthSnapshot]

    private var sorted: [DailyHealthSnapshot] {
        snapshots.sorted { $0.date < $1.date }
    }

    private var maxSnapshot: DailyHealthSnapshot? {
        sorted.max(by: { $0.sleepHours < $1.sleepHours })
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Chart title row
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "moon.fill")
                    .foregroundColor(Color(hex: "0369A1"))
                    .font(.system(size: 13, weight: .semibold))
                Text("Sleep")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "1A2E1A"))
                Spacer()
                if let max = maxSnapshot {
                    Text("Peak \(String(format: "%.1f", max.sleepHours))h")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "0369A1"))
                }
            }
            .padding(.horizontal, 4)

            // The Chart itself
            Chart(sorted) { snap in

                // ── Area fill: gradient from blue → transparent ──────────────
                // AreaMark creates the shaded region beneath the curve.
                AreaMark(
                    x: .value("Day",   snap.date, unit: .day),
                    y: .value("Sleep", snap.sleepHours)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "0369A1").opacity(0.55), location: 0.0),
                            .init(color: Color(hex: "ADE8F4").opacity(0.20), location: 0.55),
                            .init(color: Color.clear,                        location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                // catmullRom: passes through every data point with smooth tangents.
                // It avoids the "pointy" look of .linear and the overshoot of .cardinal.

                // ── Line stroke on top of the area ───────────────────────────
                LineMark(
                    x: .value("Day",   snap.date, unit: .day),
                    y: .value("Sleep", snap.sleepHours)
                )
                .foregroundStyle(Color(hex: "0369A1"))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                // ── Data point dots ──────────────────────────────────────────
                PointMark(
                    x: .value("Day",   snap.date, unit: .day),
                    y: .value("Sleep", snap.sleepHours)
                )
                .foregroundStyle(Color(hex: "0369A1"))
                .symbolSize(28)
                // symbolSize: the area in points² of the dot (not the radius).

                // ── Annotation bubble on the peak value ──────────────────────
                // Only shown on the snapshot with the highest sleep hours.
                if let max = maxSnapshot, snap.id == max.id {
                    PointMark(
                        x: .value("Day",   snap.date, unit: .day),
                        y: .value("Sleep", snap.sleepHours)
                    )
                    .annotation(position: .top, spacing: 4) {
                        // This view appears above the peak dot.
                        Text("\(String(format: "%.1f", snap.sleepHours))h")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(hex: "0369A1"))
                            )
                    }
                    .foregroundStyle(Color.clear)
                    .symbolSize(0)
                }
            }
            // ── Y axis: 0–10h range, gridlines at 4, 6, 8 ─────────────────
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(values: [0, 4, 6, 8, 10]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.15))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)h")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            // ── X axis: abbreviated weekday ──────────────────────────────
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 9))
                }
            }
            // ── Dashed reference line at 6h (clinical minimum sleep) ─────
            // chartOverlay gives us raw geometry coordinates to draw into.
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let yPos = proxy.position(forY: 6.0) {
                        // Dashed red line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPos))
                            path.addLine(to: CGPoint(x: geo.size.width, y: yPos))
                        }
                        .stroke(
                            Color(hex: "E76F51").opacity(0.7),
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )

                        // "6h min" label at the right end of the reference line
                        Text("6h min")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "E76F51"))
                            .position(x: geo.size.width - 22, y: yPos - 9)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}
