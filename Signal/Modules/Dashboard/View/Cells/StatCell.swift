//
//  StatCell.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import UIKit
// MARK: - Stat Cell

/// White-ish card: coloured icon pill (36×36, cornerRadius 10) + value + metric name
/// + sparkline at the bottom with a CAGradientLayer tint behind it.
final class StatCell: UICollectionViewCell {
    static let reuseID = "StatCell"

    private let iconPill: UIView = {
        let v = UIView()
        // Size and cornerRadius set here; bg = brandGreen @ 0.15 alpha set in configure().
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .regular)
        l.textColor = Signal.Colors.textPrimary
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let unitLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 10, weight: .thin)
        l.textColor = Signal.Colors.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 11, weight: .thin)
        l.textColor = .black.withAlphaComponent(0.8)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let sparkline = SparklineView()

    // Full-card gradient in the accent color — inserted at index 0 so it sits
    // below all subviews. Resized in layoutSubviews once the frame is known.
    private var cardGradientLayer: CAGradientLayer?

    // Sparkline ambient tint — separate gradient that sits just behind the sparkline.
    private var sparklineBgLayer: CAGradientLayer?
    private var accentColor: UIColor = Signal.Colors.brandGreen

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Background is driven by cardGradientLayer — keep the raw bg clear.
        contentView.backgroundColor     = .clear
        contentView.layer.cornerRadius  = 16
        contentView.layer.masksToBounds = true
        // Subtle white border — adds definition against the similarly-toned background
        contentView.layer.borderColor   = UIColor.white.withAlphaComponent(0.6).cgColor
        contentView.layer.borderWidth   = 1
        applyCardShadow()

        sparkline.backgroundColor = .clear
        sparkline.translatesAutoresizingMaskIntoConstraints = false

        iconPill.addSubview(iconView)
        contentView.addSubview(iconPill)
        contentView.addSubview(valueLabel)
        contentView.addSubview(unitLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(sparkline)

        NSLayoutConstraint.activate([
            // Icon pill: 36×36 per spec
            iconPill.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconPill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            iconPill.widthAnchor.constraint(equalToConstant: 36),
            iconPill.heightAnchor.constraint(equalToConstant: 36),

            // Icon image centered in pill
            iconView.centerXAnchor.constraint(equalTo: iconPill.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconPill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            // Value + unit on same row below the pill
            valueLabel.topAnchor.constraint(equalTo: iconPill.bottomAnchor, constant: 6),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            unitLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            unitLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            // Metric name below value
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),

            // Sparkline: 36pt at the bottom per spec (>= 36pt requirement)
            sparkline.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sparkline.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sparkline.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sparkline.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: layoutSubviews — place gradient layers once frames are known

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardGradient()
        updateSparklineBg()
    }

    private func updateCardGradient() {
        cardGradientLayer = contentView.applyDiagonalGradient(
            replacing: cardGradientLayer,
            from: accentColor.withAlphaComponent(0.18),
            to: UIColor.white.withAlphaComponent(0.95),
            cornerRadius: 16
        )
    }

    private func updateSparklineBg() {
        sparklineBgLayer?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.frame = sparkline.frame
        // Accent color at 0.15 alpha as per spec — subtle tint, not distracting.
        gl.colors = [
            accentColor.withAlphaComponent(0.15).cgColor,
            UIColor.clear.cgColor
        ]
        gl.startPoint = CGPoint(x: 0.5, y: 0)
        gl.endPoint   = CGPoint(x: 0.5, y: 1)
        // Insert below the sparkline view so the drawn line stays on top.
        contentView.layer.insertSublayer(gl, below: sparkline.layer)
        sparklineBgLayer = gl
    }

    // MARK: Configure

    func configure(with stat: StatItem) {
        accentColor = stat.iconColor

        // SF Symbols 6 icons per spec
        let cfg  = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image   = UIImage(systemName: stat.iconName, withConfiguration: cfg)
        // All icons tinted brand green per spec
        iconView.tintColor = .black.withAlphaComponent(0.65)
        // Pill bg = brandGreen @ 0.15 alpha (icon pill matching spec)
        iconPill.backgroundColor = Signal.Colors.brandGreen.withAlphaComponent(0.15)

        valueLabel.text = stat.value
        unitLabel.text  = stat.unit
        titleLabel.text = stat.title
        sparkline.lineColor  = stat.iconColor
        sparkline.values     = stat.sparklineValues
    }
}
