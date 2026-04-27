// RiskBreakdownSheetViewController.swift
// Signal
//
// Sheet that appears when the user taps the burnout risk card.
// Shows the four weighted signals (Sleep 30%, HRV 30%, Work 20%, Activity 10%)
// as colour-coded progress bars so the clinician can see exactly *why*
// their score is what it is — building trust in the number.

import UIKit

final class RiskBreakdownSheetViewController: UIViewController {

    // MARK: - Data

    private let score: BurnoutRiskScore
    private let features: WeeklyBehavioralFeatures

    // MARK: - Init

    init(score: BurnoutRiskScore, features: WeeklyBehavioralFeatures) {
        self.score    = score
        self.features = features
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(score:features:)") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Signal.Colors.background
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.axis    = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

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

        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeContributorsCard())
        contentStack.addArrangedSubview(makeFootnote())
    }

    // MARK: - Section builders

    /// Score badge + title + subtitle.
    private func makeHeader() -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text      = "Score Breakdown"
        titleLabel.font      = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = Signal.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text          = "How your \(score.percentageString) burnout risk index is calculated across four signals"
        subtitleLabel.font          = .systemFont(ofSize: 14, weight: .light)
        subtitleLabel.textColor     = Signal.Colors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    /// White card with one contributor row per signal, including a bar showing
    /// how much risk that signal contributed on a 0–100% scale.
    private func makeContributorsCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = Signal.Colors.cardSurface
        card.layer.cornerRadius = Signal.Card.radius
        card.applyCardShadow()

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let items = contributors()
        for (i, c) in items.enumerated() {
            stack.addArrangedSubview(makeContributorRow(c, showSeparator: i < items.count - 1))
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])

        return card
    }

    /// One row: icon pill + name + description | weight % | coloured bar
    private func makeContributorRow(_ c: Contributor, showSeparator: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon pill
        let pill = UIView()
        pill.backgroundColor    = c.color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 10
        pill.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.tintColor   = c.color
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        icon.image = UIImage(systemName: c.icon, withConfiguration: cfg)
        icon.translatesAutoresizingMaskIntoConstraints = false

        // Name + description labels
        let nameLabel = UILabel()
        nameLabel.text      = c.name
        nameLabel.font      = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = Signal.Colors.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text      = c.description
        descLabel.font      = .systemFont(ofSize: 11, weight: .light)
        descLabel.textColor = Signal.Colors.textSecondary
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // Weight badge — e.g. "30 %"
        let weightLabel = UILabel()
        weightLabel.text          = "\(Int(c.weight * 100))%"
        weightLabel.font          = .systemFont(ofSize: 13, weight: .medium)
        weightLabel.textColor     = Signal.Colors.textSecondary
        weightLabel.textAlignment = .right
        weightLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress bar track
        let barTrack = UIView()
        barTrack.backgroundColor    = Signal.Colors.background
        barTrack.layer.cornerRadius = 3
        barTrack.translatesAutoresizingMaskIntoConstraints = false

        // Coloured fill — width is a fraction of the track via multiplier
        let barFill = UIView()
        barFill.backgroundColor    = c.color
        barFill.layer.cornerRadius = 3
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(barFill)

        // Separator between rows
        let sep = UIView()
        sep.backgroundColor = Signal.Colors.background
        sep.translatesAutoresizingMaskIntoConstraints = false

        pill.addSubview(icon)
        container.addSubview(pill)
        container.addSubview(nameLabel)
        container.addSubview(descLabel)
        container.addSubview(weightLabel)
        container.addSubview(barTrack)
        if showSeparator { container.addSubview(sep) }

        // Bar fill fraction: clamp away from 0 so the constraint multiplier is valid,
        // and use a filled tint at low opacity when contribution is negligible.
        let fraction = CGFloat(max(0.01, min(1.0, c.subScore)))

        var constraints: [NSLayoutConstraint] = [
            pill.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pill.topAnchor.constraint(equalTo: container.topAnchor),
            pill.widthAnchor.constraint(equalToConstant: 36),
            pill.heightAnchor.constraint(equalToConstant: 36),

            icon.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 17),
            icon.heightAnchor.constraint(equalToConstant: 17),

            nameLabel.topAnchor.constraint(equalTo: container.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 12),

            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            descLabel.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 12),

            weightLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            weightLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            weightLabel.widthAnchor.constraint(equalToConstant: 38),
            // Keep name/desc labels from running into the weight badge
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: weightLabel.leadingAnchor, constant: -4),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: weightLabel.leadingAnchor, constant: -4),

            barTrack.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 10),
            barTrack.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 12),
            barTrack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            barTrack.heightAnchor.constraint(equalToConstant: 6),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            barFill.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: fraction)
        ]

        if showSeparator {
            constraints += [
                barTrack.bottomAnchor.constraint(equalTo: sep.topAnchor, constant: -22),
                sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1),
                sep.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ]
        } else {
            constraints.append(barTrack.bottomAnchor.constraint(equalTo: container.bottomAnchor))
        }

        NSLayoutConstraint.activate(constraints)
        return container
    }

    private func makeFootnote() -> UIView {
        let label = UILabel()
        label.text          = "Weights are informed by published burnout research. Sleep and HRV are the strongest physiological predictors; work load captures environmental pressure; activity reflects recovery behaviour."
        label.font          = .systemFont(ofSize: 11, weight: .light)
        label.textColor     = Signal.Colors.textSecondary
        label.numberOfLines = 0
        return label
    }

    // MARK: - Contributor model

    private struct Contributor {
        let name: String
        let icon: String
        let weight: Double    // Fractional weight (0–1), e.g. 0.30
        let subScore: Double  // This signal's 0–1 risk contribution
        let color: UIColor
        let description: String
    }

    /// Computes sub-scores using the same formula as MockBurnoutRiskEngine.
    private func contributors() -> [Contributor] {
        // Mirror the formulas from BurnoutRiskEngine.swift exactly.
        let sleepScore = max(0, (8.0 - features.avgSleepHours) / 8.0)
        let hrvScore   = max(0, (70.0 - features.avgHRV) / 70.0)
        let workScore  = min(1.0, max(0, (features.avgWorkHours - 8.0) / 6.0))
        let stepScore  = max(0, 1.0 - (features.avgStepCount / 10_000.0))
        let activeScore = max(0, 1.0 - (features.avgActiveMinutes / 30.0))

        // Activity weight is the sum of steps (10%) + active minutes (10%) shown as one row.
        let combinedActivity      = (stepScore * 0.10 + activeScore * 0.10) / 0.20

        return [
            Contributor(
                name: "Sleep",
                icon: "moon.fill",
                weight: 0.30,
                subScore: sleepScore,
                color: Signal.Colors.sleepIcon,
                description: String(format: "Avg %.1fh / night · target 8h", features.avgSleepHours)
            ),
            Contributor(
                name: "HRV",
                icon: "waveform.path.ecg",
                weight: 0.30,
                subScore: hrvScore,
                color: Signal.Colors.hrvIcon,
                description: String(format: "Avg %dms · healthy floor 35ms", Int(features.avgHRV))
            ),
            Contributor(
                name: "Work Load",
                icon: "briefcase.fill",
                weight: 0.20,
                subScore: workScore,
                color: Signal.Colors.workIcon,
                description: String(format: "Avg %.1fh / shift · target 8h", features.avgWorkHours)
            ),
            Contributor(
                name: "Activity",
                icon: "figure.walk",
                weight: 0.20,
                subScore: combinedActivity,
                color: Signal.Colors.stepsIcon,
                description: String(format: "Avg %d steps · target 10 000", Int(features.avgStepCount))
            )
        ]
    }
}
