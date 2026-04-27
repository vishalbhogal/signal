// MetricDetailSheetViewController.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.

import UIKit

final class MetricDetailSheetViewController: UIViewController {

    // MARK: - Data
    private let stat: StatItem
    private let snapshots: [DailyHealthSnapshot]

    // MARK: - Init
    init(stat: StatItem, snapshots: [DailyHealthSnapshot]) {
        self.stat = stat
        self.snapshots = snapshots.sorted { $0.date < $1.date }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(stat:snapshots:)") }

    // MARK: - Views
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis    = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Signal.Colors.background
        layoutScrollView()
        buildContent()
    }

    // MARK: - Layout helpers

    private func layoutScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func buildContent() {
        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeTrendCard())
        contentStack.addArrangedSubview(makeBreakdownCard())
        contentStack.addArrangedSubview(makeInterpretationCard())
    }

    // MARK: - Section builders
    private func makeHeader() -> UIView {
        let container = UIView()

        let pill = UIView()
        pill.backgroundColor    = stat.iconColor.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 20
        pill.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.tintColor   = stat.iconColor
        let cfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        icon.image = UIImage(systemName: stat.iconName, withConfiguration: cfg)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text      = stat.title
        titleLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = Signal.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text      = "\(stat.value) \(stat.unit)"
        valueLabel.font      = .systemFont(ofSize: 38, weight: .thin)
        valueLabel.textColor = Signal.Colors.textPrimary
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labelStack.axis    = .vertical
        labelStack.spacing = 2
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        pill.addSubview(icon)
        container.addSubview(pill)
        container.addSubview(labelStack)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pill.topAnchor.constraint(equalTo: container.topAnchor),
            pill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pill.widthAnchor.constraint(equalToConstant: 68),
            pill.heightAnchor.constraint(equalToConstant: 68),

            icon.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),

            labelStack.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 16),
            labelStack.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            labelStack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }

    /// Full-width card holding an enlarged sparkline for the 7-day window.
    private func makeTrendCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = Signal.Colors.cardSurface
        card.layer.cornerRadius = Signal.Card.radius
        card.applyCardShadow()

        let header = UILabel()
        header.text      = "7-Day Trend"
        header.font      = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = Signal.Colors.textSecondary
        header.translatesAutoresizingMaskIntoConstraints = false
        let sparkline = SparklineView()
        sparkline.lineColor  = stat.iconColor
        sparkline.values     = stat.sparklineValues
        sparkline.backgroundColor = .clear
        sparkline.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(header)
        card.addSubview(sparkline)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            sparkline.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            sparkline.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            sparkline.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            sparkline.heightAnchor.constraint(equalToConstant: 80),
            sparkline.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    /// White card with one row per day showing the raw value + colour coding.
    private func makeBreakdownCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = Signal.Colors.cardSurface
        card.layer.cornerRadius = Signal.Card.radius
        card.applyCardShadow()

        let header = UILabel()
        header.text      = "Daily Breakdown"
        header.font      = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = Signal.Colors.textSecondary
        header.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = UIStackView()
        rowStack.axis    = .vertical
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"

        for (i, snapshot) in snapshots.enumerated() {
            let raw = rawValue(for: snapshot)
            let row = makeBreakdownRow(
                day: df.string(from: snapshot.date),
                value: formatValue(raw),
                color: rowColor(for: raw),
                showSeparator: i < snapshots.count - 1
            )
            rowStack.addArrangedSubview(row)
        }

        card.addSubview(header)
        card.addSubview(rowStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            rowStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeBreakdownRow(day: String, value: String,
                                  color: UIColor, showSeparator: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dayLabel = UILabel()
        dayLabel.text      = day
        dayLabel.font      = .systemFont(ofSize: 13, weight: .regular)
        dayLabel.textColor = Signal.Colors.textSecondary
        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text          = "\(value) \(stat.unit)"
        valueLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor     = color
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(dayLabel)
        container.addSubview(valueLabel)

        var constraints: [NSLayoutConstraint] = [
            dayLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            dayLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dayLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: showSeparator ? -9 : -9),

            valueLabel.centerYAnchor.constraint(equalTo: dayLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: dayLabel.trailingAnchor, constant: 8)
        ]

        if showSeparator {
            let sep = UIView()
            sep.backgroundColor = Signal.Colors.background
            sep.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(sep)
            constraints += [
                sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1)
            ]
        }

        NSLayoutConstraint.activate(constraints)
        return container
    }

    /// Tinted callout card with a one-line interpretation of the week's data.
    private func makeInterpretationCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = stat.iconColor.withAlphaComponent(0.07)
        card.layer.cornerRadius = Signal.Card.radius
        card.layer.borderColor  = stat.iconColor.withAlphaComponent(0.18).cgColor
        card.layer.borderWidth  = 1

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor   = stat.iconColor
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: "lightbulb.fill", withConfiguration: cfg)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let textLabel = UILabel()
        textLabel.text          = interpretationText()
        textLabel.font          = .systemFont(ofSize: 13, weight: .regular)
        textLabel.textColor     = Signal.Colors.textPrimary
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(textLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            textLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            textLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    // MARK: - Metric helpers

    /// Extracts the raw daily value relevant to this metric from a snapshot.
    private func rawValue(for snapshot: DailyHealthSnapshot) -> Double {
        switch stat.title {
        case "Sleep": return snapshot.sleepHours
        case "Steps": return Double(snapshot.stepCount)
        case "HRV":   return snapshot.heartRateVariability
        case "Shift": return snapshot.workHours
        default:      return 0
        }
    }

    /// Formats a raw value for display (Steps are integers, others are 1-dp floats).
    private func formatValue(_ val: Double) -> String {
        if stat.title == "Steps" { return "\(Int(val))" }
        return String(format: "%.1f", val)
    }

    /// Green / amber / red depending on how a day's value compares to its target.
    private func rowColor(for value: Double) -> UIColor {
        switch stat.title {
        case "Sleep":
            return value >= 7.0 ? Signal.Colors.brandGreen
                 : value >= 6.0 ? UIColor(hex: "F59E0B")
                 : UIColor(hex: "E76F51")
        case "Steps":
            return value >= 7500 ? Signal.Colors.brandGreen
                 : value >= 4000 ? UIColor(hex: "F59E0B")
                 : UIColor(hex: "E76F51")
        case "HRV":
            return value >= 35 ? Signal.Colors.brandGreen
                 : value >= 25 ? UIColor(hex: "F59E0B")
                 : UIColor(hex: "E76F51")
        case "Shift":
            return value <= 8.0  ? Signal.Colors.brandGreen
                 : value <= 10.0 ? UIColor(hex: "F59E0B")
                 : UIColor(hex: "E76F51")
        default: return Signal.Colors.textPrimary
        }
    }

    /// Recommended target value and its human label for each metric.
    private var baseline: (value: Double, label: String) {
        switch stat.title {
        case "Sleep": return (7.0,    "recommended")
        case "Steps": return (7500,   "daily target")
        case "HRV":   return (35.0,   "healthy floor")
        case "Shift": return (8.0,    "target shift length")
        default:      return (0,      "")
        }
    }

    /// Produces a single sentence comparing the 7-day average to the metric's baseline.
    private func interpretationText() -> String {
        let values = stat.sparklineValues
        guard !values.isEmpty else { return "" }
        let avg = values.reduce(0, +) / Double(values.count)
        let (base, label) = baseline
        let diff = avg - base

        switch stat.title {
        case "Sleep":
            let avgStr  = String(format: "%.1f", avg)
            let diffStr = String(format: "%.1f", abs(diff))
            if diff >= 0 {
                return "You averaged \(avgStr)h — \(diffStr)h above the \(label) of \(Int(base))h."
            } else {
                return "You averaged \(avgStr)h — \(diffStr)h below the \(label) of \(Int(base))h."
            }

        case "Steps":
            let avgInt  = Int(avg)
            let baseInt = Int(base)
            let diffInt = Int(abs(diff))
            if diff >= 0 {
                return "You averaged \(avgInt) steps — \(diffInt) above the \(label) of \(baseInt)."
            } else {
                return "You averaged \(avgInt) steps — \(diffInt) below the \(label) of \(baseInt)."
            }

        case "HRV":
            let avgStr  = String(format: "%.0f", avg)
            let diffStr = String(format: "%.0f", abs(diff))
            if diff >= 0 {
                return "Your HRV averaged \(avgStr)ms — \(diffStr)ms above the \(label) of \(Int(base))ms. Recovery looks good."
            } else {
                return "Your HRV averaged \(avgStr)ms — \(diffStr)ms below the \(label) of \(Int(base))ms. Elevated physiological stress likely."
            }

        case "Shift":
            let avgStr  = String(format: "%.1f", avg)
            let diffStr = String(format: "%.1f", abs(diff))
            if diff <= 0 {
                return "Your shifts averaged \(avgStr)h — within the \(label) of \(Int(base))h."
            } else {
                return "Your shifts averaged \(avgStr)h — \(diffStr)h over the \(label) of \(Int(base))h."
            }

        default:
            return "Weekly average: \(formatValue(avg)) \(stat.unit)."
        }
    }
}
