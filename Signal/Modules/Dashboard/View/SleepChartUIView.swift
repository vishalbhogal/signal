// SleepChartUIView.swift
// Signal
//
// 100% UIKit implementation of the sleep trend chart.
// Uses CAShapeLayer for the line, CAGradientLayer + clipping mask for the fill,
// and UILabel / UIImageView for all annotations.
// No SwiftUI, no Charts framework dependency here.

import UIKit

final class SleepChartUIView: UIView {

    // MARK: - Chart Geometry

    // Space reserved outside the chart plot area for labels.
    private let top:    CGFloat = 38   // title row
    private let left:   CGFloat = 26   // y-axis labels
    private let bottom: CGFloat = 22   // x-axis labels
    private let right:  CGFloat = 10

    // Y-axis domain
    private let yMin: Double = 0
    private let yMax: Double = 10

    // MARK: - CALayers (drawn in layoutSubviews)

    // The gradient fill under the curve — clipped to the area path shape.
    private let gradientFillLayer = CAGradientLayer()
    // Mask that clips the gradient to the shape of the area under the curve.
    private let fillMaskLayer     = CAShapeLayer()
    // The line stroke itself, drawn above the gradient.
    private let lineLayer         = CAShapeLayer()
    // Dashed horizontal reference line at 6h.
    private let refLineLayer      = CAShapeLayer()
    // Individual dot markers at each data point.
    private var dotLayers: [CAShapeLayer] = []

    // MARK: - Header Views

    private let headerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 5
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let moonIcon: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let iv  = UIImageView(image: UIImage(systemName: "moon.zzz.fill", withConfiguration: cfg))
        iv.tintColor = UIColor(hex: "0369A1")
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let sleepTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Sleep"
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = Signal.Colors.textPrimary
        return l
    }()

    private let peakLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = UIColor(hex: "0369A1")
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Recycled Axis Labels

    private var yAxisLabels: [UILabel] = []
    private var xAxisLabels: [UILabel] = []
    private var refMinLabel: UILabel?

    // MARK: - Data

    private var snapshots: [DailyHealthSnapshot] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayers()
        setupHeader()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        setupLayers()
        setupHeader()
    }

    // MARK: - Setup

    private func setupLayers() {
        // ── Gradient fill ────────────────────────────────────────────────
        // Three-stop gradient: rich blue at top → light cyan mid → clear bottom.
        gradientFillLayer.colors = [
            UIColor(red: 0.02, green: 0.38, blue: 0.63, alpha: 0.50).cgColor,
            UIColor(red: 0.67, green: 0.91, blue: 0.96, alpha: 0.18).cgColor,
            UIColor.clear.cgColor
        ]
        gradientFillLayer.locations = [0, 0.55, 1.0]
        gradientFillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientFillLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        // The fillMaskLayer acts as a cookie-cutter: only pixels inside the
        // closed area path are visible through the gradient.
        gradientFillLayer.mask = fillMaskLayer
        layer.addSublayer(gradientFillLayer)

        // ── Line stroke ──────────────────────────────────────────────────
        lineLayer.fillColor   = UIColor.clear.cgColor
        lineLayer.strokeColor = UIColor(red: 0.02, green: 0.38, blue: 0.63, alpha: 1.0).cgColor
        lineLayer.lineWidth   = 2.5
        lineLayer.lineCap     = .round
        lineLayer.lineJoin    = .round
        layer.addSublayer(lineLayer)

        // ── Reference line at 6h ─────────────────────────────────────────
        refLineLayer.fillColor        = UIColor.clear.cgColor
        refLineLayer.strokeColor      = UIColor(red: 0.91, green: 0.44, blue: 0.32, alpha: 0.65).cgColor
        refLineLayer.lineWidth        = 1.2
        refLineLayer.lineDashPattern  = [5, 4]
        layer.addSublayer(refLineLayer)
    }

    private func setupHeader() {
        // Left side: moon icon + "Sleep" label
        headerStack.addArrangedSubview(moonIcon)
        headerStack.addArrangedSubview(sleepTitleLabel)
        addSubview(headerStack)
        addSubview(peakLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),

            peakLabel.centerYAnchor.constraint(equalTo: headerStack.centerYAnchor),
            peakLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
    }

    // MARK: - Configure

    func configure(with snapshots: [DailyHealthSnapshot]) {
        self.snapshots = snapshots.sorted { $0.date < $1.date }
        if let peak = self.snapshots.max(by: { $0.sleepHours < $1.sleepHours }) {
            peakLabel.text = "Peak \(String(format: "%.1f", peak.sleepHours))h"
        }
        // Clear and redraw when data changes.
        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers = []
        setNeedsLayout()
    }

    // MARK: - Layout / Drawing

    override func layoutSubviews() {
        super.layoutSubviews()
        guard snapshots.count > 1, bounds.width > 0, bounds.height > 0 else { return }
        redrawChart()
    }

    private var plotRect: CGRect {
        CGRect(
            x: left,
            y: top,
            width:  bounds.width  - left - right,
            height: bounds.height - top  - bottom
        )
    }

    private func xPos(_ index: Int) -> CGFloat {
        plotRect.minX + CGFloat(index) / CGFloat(snapshots.count - 1) * plotRect.width
    }

    private func yPos(_ value: Double) -> CGFloat {
        let normalised = (value - yMin) / (yMax - yMin)
        return plotRect.maxY - CGFloat(normalised) * plotRect.height
    }

    private func redrawChart() {
        let rect = plotRect

        // ── Point coordinates ────────────────────────────────────────────
        let pts: [CGPoint] = snapshots.enumerated().map { i, snap in
            CGPoint(x: xPos(i), y: yPos(snap.sleepHours))
        }

        // ── Smooth curve using cubic bezier cardinal spline ──────────────
        // Each control point is at the midpoint x of adjacent segments,
        // preserving the y of each side — this produces a smooth S-curve
        // through all data points without overshoot.
        let linePath = cardinalSpline(through: pts)
        lineLayer.path = linePath.cgPath

        // ── Fill path: close below the curve to form the area shape ──────
        let fillPath = cardinalSpline(through: pts)
        fillPath.addLine(to: CGPoint(x: pts.last!.x,  y: rect.maxY))
        fillPath.addLine(to: CGPoint(x: pts.first!.x, y: rect.maxY))
        fillPath.close()

        // The mask layer clips the gradient to the fill shape.
        // Its frame must match the gradient layer's frame (= bounds).
        fillMaskLayer.path      = fillPath.cgPath
        fillMaskLayer.fillColor = UIColor.black.cgColor   // opaque = visible
        fillMaskLayer.frame     = bounds
        gradientFillLayer.frame = bounds

        // ── Reference line at y = 6h ──────────────────────────────────────
        let refY = yPos(6.0)
        let refPath = UIBezierPath()
        refPath.move(to:    CGPoint(x: rect.minX, y: refY))
        refPath.addLine(to: CGPoint(x: rect.maxX, y: refY))
        refLineLayer.path = refPath.cgPath

        // ── Dot markers at each data point ───────────────────────────────
        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers = pts.map { pt in
            let dot = CAShapeLayer()
            // Outer white ring: fill white, strokeColor blue, draws as circle with border.
            let circle = UIBezierPath(arcCenter: pt, radius: 3.5,
                                      startAngle: 0, endAngle: .pi * 2, clockwise: true)
            dot.path        = circle.cgPath
            dot.fillColor   = UIColor(red: 0.02, green: 0.38, blue: 0.63, alpha: 1.0).cgColor
            dot.strokeColor = UIColor.white.cgColor
            dot.lineWidth   = 1.5
            layer.addSublayer(dot)
            return dot
        }

        // ── Axis labels ───────────────────────────────────────────────────
        redrawYLabels(rect: rect)
        redrawXLabels(rect: rect)
        redrawRefLabel(at: refY)
    }

    // MARK: - Axis Label Rendering

    private func redrawYLabels(rect: CGRect) {
        yAxisLabels.forEach { $0.removeFromSuperview() }
        yAxisLabels = []
        for value in [4.0, 6.0, 8.0] {
            let l = UILabel()
            l.text      = "\(Int(value))h"
            l.font      = .systemFont(ofSize: 9, weight: .regular)
            l.textColor = .systemGray2
            l.textAlignment = .right
            l.sizeToFit()
            let y = yPos(value)
            l.frame = CGRect(x: 0, y: y - l.frame.height / 2,
                             width: left - 4, height: l.frame.height)
            addSubview(l)
            yAxisLabels.append(l)
        }
    }

    private func redrawXLabels(rect: CGRect) {
        xAxisLabels.forEach { $0.removeFromSuperview() }
        xAxisLabels = []
        let df = DateFormatter()
        df.dateFormat = "E"     // "Mon", "Tue"…

        for (i, snap) in snapshots.enumerated() {
            let l = UILabel()
            // Take only first 2 characters: "Mo", "Tu" — less cluttered than "Mon"
            l.text      = String(df.string(from: snap.date).prefix(2))
            l.font      = .systemFont(ofSize: 9, weight: .regular)
            l.textColor = .systemGray2
            l.textAlignment = .center
            l.frame     = CGRect(x: xPos(i) - 12, y: rect.maxY + 4, width: 24, height: 14)
            addSubview(l)
            xAxisLabels.append(l)
        }
    }

    private func redrawRefLabel(at y: CGFloat) {
        refMinLabel?.removeFromSuperview()
        let l = UILabel()
        l.text      = "6h min"
        l.font      = .systemFont(ofSize: 9, weight: .semibold)
        l.textColor = UIColor(red: 0.91, green: 0.44, blue: 0.32, alpha: 0.85)
        l.sizeToFit()
        l.frame = CGRect(
            x: bounds.width - l.frame.width - right - 2,
            y: y - l.frame.height - 2,
            width: l.frame.width,
            height: l.frame.height
        )
        addSubview(l)
        refMinLabel = l
    }

    // MARK: - Smooth Curve Path

    /// Builds a UIBezierPath through all points using cubic bezier segments.
    /// Control points are derived from adjacent segment midpoints (cardinal spline),
    /// producing smooth curves that pass exactly through every data point.
    private func cardinalSpline(through points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            // Midpoint x gives a smooth horizontal-to-vertical transition
            let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) * 0.5, y: p0.y)
            let cp2 = CGPoint(x: p0.x + (p1.x - p0.x) * 0.5, y: p1.y)
            path.addCurve(to: p1, controlPoint1: cp1, controlPoint2: cp2)
        }
        return path
    }
}
