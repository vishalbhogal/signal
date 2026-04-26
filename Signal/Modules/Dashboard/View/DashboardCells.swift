// DashboardCells.swift
// Signal — v3 (pure UIKit, SF Symbols 6)
//
// Zero SwiftUI in this file. All layout via Auto Layout + CALayer.
// SF Symbols 6 symbol effects require iOS 17+ (guarded with #available).

import UIKit

// MARK: - Greeting Header

final class GreetingHeaderView: UICollectionReusableView {
    static let reuseID = "GreetingHeaderView"

    // Callback wired up by the ViewController so the cell doesn't know about navigation.
    var onProfileTap: (() -> Void)?
    var onBellTap:    (() -> Void)?

    // ── Logo stack: [waveform icon] [signal. label] ───────────────────────
    private let logoStack: UIStackView = {
        let sv = UIStackView()
        sv.axis      = .horizontal
        sv.spacing   = 6
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let waveformIcon: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let iv  = UIImageView(image: UIImage(systemName: "waveform", withConfiguration: cfg))
        iv.tintColor    = Signal.Colors.brandGreen
        iv.contentMode  = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()

    private let signalLabel: UILabel = {
        let l = UILabel()
        l.text      = "signal."
        l.font      = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = Signal.Colors.textPrimary
        return l
    }()

    // ── Profile button ────────────────────────────────────────────────────
    private let profileButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let img = UIImage(systemName: "person.crop.circle.fill", withConfiguration: cfg)
        btn.setImage(img, for: .normal)
        btn.tintColor = Signal.Colors.brandGreen.withAlphaComponent(0.7)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // ── Greeting + date ───────────────────────────────────────────────────
    private let greetingLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 26, weight: .light)
        l.textColor = Signal.Colors.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 13, weight: .thin)
        l.textColor = Signal.Colors.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Init
    

    override init(frame: CGRect) {
        super.init(frame: frame)

        //logoStack.addArrangedSubview(waveformIcon)
        //logoStack.addArrangedSubview(signalLabel)

        //addSubview(logoStack)
        addSubview(profileButton)
        addSubview(greetingLabel)
        addSubview(dateLabel)

        NSLayoutConstraint.activate([
//            logoStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
//            logoStack.leadingAnchor.constraint(equalTo: leadingAnchor),

            profileButton.centerYAnchor.constraint(equalTo: greetingLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            profileButton.widthAnchor.constraint(equalToConstant: 30),
            profileButton.heightAnchor.constraint(equalToConstant: 30),

//            greetingLabel.topAnchor.constraint(equalTo: logoStack.bottomAnchor, constant: 6),
//            greetingLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
//            greetingLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            greetingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            greetingLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            greetingLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            dateLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Configure

    func configure() {
        let hour = Calendar.current.component(.hour, from: Date())
        greetingLabel.text = hour < 12 ? "Good morning," : hour < 17 ? "Good afternoon," : "Good evening,"

        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        dateLabel.text = df.string(from: Date())

        // Pulse the waveform icon continuously — SF Symbols 6 symbol effect.
        // .pulse makes the icon opacity breathe, reinforcing the "live monitoring" feeling.
        if #available(iOS 17.0, *) {
            waveformIcon.addSymbolEffect(.variableColor.cumulative.nonReversing, options: .repeating)
        }
    }
    
    func triggerAnimation() {
        if #available(iOS 17.0, *) {
            waveformIcon.addSymbolEffect(.variableColor.cumulative, options: .repeating)
        }
    }

    // MARK: Actions

    @objc private func bellTapped()    { onBellTap?() }
    @objc private func profileTapped() { onProfileTap?() }
}

// MARK: - Section Header (with brand underline)

final class SectionHeaderView: UICollectionReusableView {
    static let reuseID = "SectionHeaderView"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 16, weight: .regular)   // per spec
        l.textColor = Signal.Colors.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // 3×20pt brand-green underline accent below the title.
    private let underline: UIView = {
        let v = UIView()
        v.backgroundColor    = Signal.Colors.brandGreen
        v.layer.cornerRadius = 1.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        addSubview(underline)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            underline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            underline.leadingAnchor.constraint(equalTo: leadingAnchor),
            underline.widthAnchor.constraint(equalToConstant: 20),
            underline.heightAnchor.constraint(equalToConstant: 3),
            underline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
        isHidden = title.isEmpty
    }
}

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

// MARK: - Sparkline View

/// Lightweight UIView that draws a smooth mini line chart using UIBezierPath + CGGradient.
final class SparklineView: UIView {
    var values: [Double] = [] { didSet { setNeedsDisplay() } }
    var lineColor: UIColor = Signal.Colors.brandGreen

    override func draw(_ rect: CGRect) {
        guard values.count > 1 else { return }
        let minV = values.min()!, maxV = values.max()!
        let range = maxV - minV

        func pt(_ i: Int) -> CGPoint {
            let x = rect.width * CGFloat(i) / CGFloat(values.count - 1)
            let n: CGFloat = range > 0 ? CGFloat((values[i] - minV) / range) : 0.5
            return CGPoint(x: x, y: rect.height - n * rect.height * 0.85 - rect.height * 0.075)
        }

        let pts  = (0..<values.count).map { pt($0) }
        let line = UIBezierPath()
        let fill = UIBezierPath()
        line.move(to: pts[0])
        fill.move(to: CGPoint(x: pts[0].x, y: rect.height))
        fill.addLine(to: pts[0])

        for i in 1..<pts.count {
            let c1 = CGPoint(x: pts[i-1].x + (pts[i].x - pts[i-1].x) * 0.5, y: pts[i-1].y)
            let c2 = CGPoint(x: pts[i-1].x + (pts[i].x - pts[i-1].x) * 0.5, y: pts[i].y)
            line.addCurve(to: pts[i], controlPoint1: c1, controlPoint2: c2)
            fill.addCurve(to: pts[i], controlPoint1: c1, controlPoint2: c2)
        }
        fill.addLine(to: CGPoint(x: pts.last!.x, y: rect.height))
        fill.close()

        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        fill.addClip()
        let colors = [lineColor.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad,
                                   start: CGPoint(x: rect.midX, y: 0),
                                   end:   CGPoint(x: rect.midX, y: rect.height),
                                   options: [])
        }
        ctx.restoreGState()
        lineColor.setStroke()
        line.lineWidth = 1.5
        line.stroke()
    }
}

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

    /// Full-card diagonal gradient: accent color (light) → white.
    /// Each metric chip gets its own tint so the row reads as a colour-coded set.
    private func updateCardGradient() {
        cardGradientLayer?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.frame        = contentView.bounds
        gl.cornerRadius = 16
        gl.colors = [
            accentColor.withAlphaComponent(0.18).cgColor,   // top-left: metric tint
            UIColor.white.withAlphaComponent(0.95).cgColor, // bottom-right: clean white
        ]
        gl.startPoint = CGPoint(x: 0.0, y: 0.0)
        gl.endPoint   = CGPoint(x: 1.0, y: 1.0)   // diagonal for a bit of depth
        contentView.layer.insertSublayer(gl, at: 0)
        cardGradientLayer = gl
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

// MARK: - Chart Cell (pure UIKit — uses SleepChartUIView directly)

final class ChartCell: UICollectionViewCell {
    static let reuseID = "ChartCell"

    private let containerView: UIView = {
        let v = UIView()
        // Sleep card background per spec
        v.backgroundColor    = Signal.Colors.sleepCard
        v.layer.cornerRadius = Signal.Card.radius
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Pure UIKit chart — no UIHostingController, no SwiftUI
    private let sleepChart = SleepChartUIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardShadow()

        sleepChart.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        containerView.addSubview(sleepChart)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            sleepChart.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            sleepChart.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            sleepChart.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            sleepChart.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with snapshots: [DailyHealthSnapshot]) {
        sleepChart.configure(with: snapshots)
    }
}

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

    /// Gentle diagonal gradient from the priority accent (very low opacity)
    /// across to clean white — gives each card a warm, distinct feel without
    /// competing with the accent bar on the left edge.
    private func updateCardGradient() {
        cardGradientLayer?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.frame        = contentView.bounds
        gl.cornerRadius = 16
        gl.colors = [
            currentAccent.withAlphaComponent(0.10).cgColor,
            UIColor.white.cgColor,
        ]
        gl.startPoint = CGPoint(x: 0.0, y: 0.0)
        gl.endPoint   = CGPoint(x: 1.0, y: 1.0)
        contentView.layer.insertSublayer(gl, at: 0)
        cardGradientLayer = gl
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
