//
//  RiskScoreCell.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import UIKit
// MARK: - Risk Score Cell

final class RiskScoreCell: UICollectionViewCell {
    static let reuseID = "RiskScoreCell"

    private var gradientLayer: CAGradientLayer?
    private let trackLayer    = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    // ── Risk pill (top-left) ──────────────────────────────────────────────
    private let pillView: UIView = {
        let v = UIView()
        v.backgroundColor    = UIColor.white.withAlphaComponent(0.22)
        v.layer.cornerRadius = 11
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Dynamic icon inside the pill — gets .bounce on appear.
    private let riskIcon: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let iv  = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg))
        iv.tintColor   = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let pillLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // ── Ring container ────────────────────────────────────────────────────
    private let ringContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // ── Labels inside ring ────────────────────────────────────────────────

    // .black weight — heavier than bold, premium feel
    private let percentLabel: UILabel = {
        let l = UILabel()
        l.font          = .systemFont(ofSize: 52, weight: .thin)   // per spec
        l.textColor     = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let indexCaptionLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let footerLabel: UILabel = {
        let l = UILabel()
        l.text          = "7 — day behavioural index"
        l.font          = .systemFont(ofSize: 10, weight: .thin)
        l.textColor     = UIColor.white.withAlphaComponent(0.6)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius  = Signal.Card.radius
        contentView.layer.masksToBounds = true
        applyCardShadow()

        // Arc layers are added to the layer directly; they draw via layoutSubviews.
        contentView.layer.addSublayer(trackLayer)
        contentView.layer.addSublayer(progressLayer)

        // Pill
        pillView.addSubview(riskIcon)
        pillView.addSubview(pillLabel)
        contentView.addSubview(pillView)

        // Ring container and its child labels
        contentView.addSubview(ringContainer)
        ringContainer.addSubview(percentLabel)
        ringContainer.addSubview(indexCaptionLabel)
        contentView.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            // Pill: top-left
            pillView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            pillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            pillView.heightAnchor.constraint(equalToConstant: 24),

            riskIcon.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
            riskIcon.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 8),
            riskIcon.widthAnchor.constraint(equalToConstant: 14),
            riskIcon.heightAnchor.constraint(equalToConstant: 14),

            pillLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),
            pillLabel.leadingAnchor.constraint(equalTo: riskIcon.trailingAnchor, constant: 4),
            pillLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -10),

            // Ring container: centered, square
            ringContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ringContainer.topAnchor.constraint(equalTo: pillView.bottomAnchor, constant: 8),
            ringContainer.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),
            ringContainer.widthAnchor.constraint(equalTo: ringContainer.heightAnchor),

            percentLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            percentLabel.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor, constant: -8),

            indexCaptionLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 2),
            indexCaptionLabel.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),

            footerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            footerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    private var storedScore: BurnoutRiskScore?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let score = storedScore else { return }
        updateGradient(for: score.level)
        drawRing(progress: score.score)
    }

    // MARK: Configure

    func configure(with score: BurnoutRiskScore) {
        storedScore = score
        percentLabel.text = score.percentageString
        pillLabel.text    = score.level.rawValue + " Risk"

        // kern: 2.5 — per spec. NSAttributedString is the only way to set letter spacing.
        let attrs: [NSAttributedString.Key: Any] = [
            .kern:            2.5,
            .font:            UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.70)
        ]
        indexCaptionLabel.attributedText = NSAttributedString(
            string: "BURNOUT RISK INDEX", attributes: attrs
        )

        // Set the appropriate risk icon dynamically
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        riskIcon.image = UIImage(systemName: score.level.iconName, withConfiguration: cfg)

        setNeedsLayout()
    }

    // Called from the VC's collectionView(_:willDisplay:forItemAt:) so the
    // animation fires when the cell is actually on-screen.
    func triggerSymbolAnimations() {
        if #available(iOS 17.0, *) {
            riskIcon.addSymbolEffect(.bounce, options: .nonRepeating)
        }
    }

    // MARK: - Gradient

    private func updateGradient(for level: RiskLevel) {
        let (top, bottom): (UIColor, UIColor) = {
            switch level {
            case .low:      return (Signal.Colors.riskLowTop,      Signal.Colors.riskLowBottom)
            case .moderate: return (Signal.Colors.riskModerateTop, Signal.Colors.riskModerateBottom)
            case .high:     return (Signal.Colors.riskHighTop,     Signal.Colors.riskHighBottom)
            }
        }()
        
        if let gl = gradientLayer {
            gl.colors = [top.cgColor, bottom.cgColor]
            gl.frame = contentView.bounds
        } else {
            let gl = CAGradientLayer.vertical(top: top, bottom: bottom, frame: contentView.bounds)
            gl.cornerRadius = Signal.Card.radius
            contentView.layer.insertSublayer(gl, at: 0)
            gradientLayer = gl
        }
    }

    // MARK: - Ring

    private func drawRing(progress: Double) {
        // To retain the "Initial View" (corner arc) even after layout updates,
        // we anchor the center to (0,0) with a stylized decorative radius.
        let radius: CGFloat = 140
        let center  = CGPoint(x: 0, y: 0)
        let start:  CGFloat = -.pi / 2           // 12 o'clock
        let fullEnd:CGFloat =  .pi * 3 / 2       // full circle

        let trackPath = UIBezierPath(arcCenter: center, radius: radius,
                                     startAngle: start, endAngle: fullEnd, clockwise: true)
        trackLayer.path        = trackPath.cgPath
        trackLayer.fillColor   = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.20).cgColor
        trackLayer.lineWidth   = 10
        trackLayer.lineCap     = .round

        let progressEnd = start + CGFloat(progress) * 2 * .pi
        let progPath    = UIBezierPath(arcCenter: center, radius: radius,
                                       startAngle: start, endAngle: progressEnd, clockwise: true)
        progressLayer.path        = progPath.cgPath
        progressLayer.fillColor   = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineWidth   = 10
        progressLayer.lineCap     = .round

        let anim            = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue      = 0
        anim.toValue        = 1
        anim.duration       = 1.1
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode       = .forwards
        anim.isRemovedOnCompletion = false
        progressLayer.add(anim, forKey: "ring")
    }
}
