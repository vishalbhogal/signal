//
//  InsightCell.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import UIKit

// MARK: - Insight Cell

final class InsightCell: UICollectionViewCell {
    static let reuseID = "InsightCell"

    // MARK: Callbacks — wired by the ViewController, not by the cell itself.
    // Keeping navigation concerns out of the cell preserves a clean boundary.
    var onDismiss:    (() -> Void)?
    var onTakeAction: (() -> Void)?

    // Full-card gradient keyed to the insight's priority accent color.
    private var cardGradientLayer: CAGradientLayer?
    private var currentAccent: UIColor = Signal.Colors.insightP4

    // MARK: Subviews

    private let accentBar: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconBubble: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = Signal.Colors.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.font          = .systemFont(ofSize: 12, weight: .light)
        l.textColor     = .black.withAlphaComponent(0.65)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Hairline divider between body text and the action buttons.
    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = Signal.Colors.background
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // "Dismiss" — subdued text button, or swipe left anywhere on the card.
    private let dismissButton: UIButton = {
        let btn = UIButton(type: .system)
        // 1. Define the styling attributes, including the underline
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black.withAlphaComponent(0.5),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        // 2. Create the attributed string
        let attributedTitle = NSAttributedString(string: "Dismiss", attributes: attributes)
        // 3. Apply it to the button
        btn.setAttributedTitle(attributedTitle, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // "Take Action" — filled brand-green pill.
    private let actionButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Take Action", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor     = .clear   // gradient replaces flat colour
        contentView.layer.cornerRadius  = 16
        contentView.layer.masksToBounds = true
        applyCardShadow()

        iconBubble.addSubview(iconView)
        contentView.addSubview(accentBar)
        contentView.addSubview(iconBubble)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyLabel)
        contentView.addSubview(divider)
        contentView.addSubview(dismissButton)
        contentView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            // Accent bar: spans full card height on the left edge
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            accentBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            // Icon bubble: top-aligned with the title row
            iconBubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconBubble.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            iconBubble.widthAnchor.constraint(equalToConstant: 36),
            iconBubble.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconBubble.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBubble.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            // Text column
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: iconBubble.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: iconBubble.trailingAnchor, constant: 10),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            bodyLabel.bottomAnchor.constraint(equalTo: divider.topAnchor, constant: -10),

            // Divider
            divider.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -10),

            // Action buttons row
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            actionButton.heightAnchor.constraint(equalToConstant: 28),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            dismissButton.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: divider.leadingAnchor),
            dismissButton.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            dismissButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        actionButton.addTarget(self,  action: #selector(actionTapped),  for: .touchUpInside)

        // Swipe left anywhere on the card also triggers dismiss.
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(dismissTapped))
        swipe.direction = .left
        contentView.addGestureRecognizer(swipe)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardGradient()
    }

    private func updateCardGradient() {
        cardGradientLayer = contentView.applyDiagonalGradient(
            replacing: cardGradientLayer,
            from: currentAccent.withAlphaComponent(0.10),
            to: .white,
            cornerRadius: 16
        )
    }

    // MARK: Configure

    func configure(with insight: HealthInsight) {
        titleLabel.text = insight.title
        bodyLabel.text  = insight.body
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        iconView.image  = UIImage(systemName: insight.iconName, withConfiguration: cfg)

        let (accent, bubble): (UIColor, UIColor) = {
            switch insight.priority {
            case 1:  return (Signal.Colors.insightP1, Signal.Colors.workBubble)
            case 2:  return (Signal.Colors.insightP2, Signal.Colors.hrvBubble)
            case 3:  return (Signal.Colors.insightP3, Signal.Colors.sleepBubble)
            default: return (Signal.Colors.insightP4, Signal.Colors.lightGreen)
            }
        }()
        accentBar.backgroundColor  = accent
        iconBubble.backgroundColor = bubble
        iconView.tintColor         = accent
        actionButton.backgroundColor = accent
        currentAccent              = accent  // drives the card gradient
        setNeedsLayout()                     // rebuild gradient with new accent

        // Clear stale callbacks from a reused cell before the VC re-assigns them.
        onDismiss    = nil
        onTakeAction = nil
    }

    // MARK: Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset any in-flight dismiss animation so the cell looks correct if reused.
        contentView.transform = .identity
        contentView.alpha     = 1
    }

    // MARK: Actions

    @objc private func dismissTapped() {
        // Slide the card out to the left, then let the data source remove it
        // (the VC's onDismiss handler calls dataSource.apply, which animates the gap).
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
            self.contentView.transform = CGAffineTransform(translationX: -self.bounds.width, y: 0)
            self.contentView.alpha = 0
        } completion: { _ in
            self.onDismiss?()
        }
    }

    @objc private func actionTapped() {
        onTakeAction?()
    }
}
