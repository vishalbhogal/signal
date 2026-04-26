// ExploreSpotCell.swift
// Signal
//
// A large card cell matching the Daily Adventure card style:
//
//   [icon]  Nearby [Category]           ← header row
//
//   Walk to [Place], about [dist] away. ← description
//
//   ⊕  [prompt text]                   ← mindful nudge (gray)
//
//   [Place Name]  [🚶 dist]  [⚡ 15 XP] ← info chips
//
//   [ Show on Map ]  [ Check In / Get Closer ]  ← action buttons

import MapKit
import UIKit

final class ExploreSpotCell: UICollectionViewCell {

    static let reuseID = "ExploreSpotCell"

    // MARK: - Closures

    var onShowMap: (() -> Void)?
    var onCheckIn: (() -> Void)?

    // MARK: - Subviews

    // Header row ─────────────────────────────────────────────────────────────

    private let headerIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Description ─────────────────────────────────────────────────────────────

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = .label
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Prompt row ──────────────────────────────────────────────────────────────

    private let promptIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "sparkles",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .secondaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let promptLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .thin)
        l.textColor = .black
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Info chips row ──────────────────────────────────────────────────────────

    //private let placeChip   = ExploreSpotCell.makeChip(icon: "mappin", tint: .black)
    private let distChip    = ExploreSpotCell.makeChip(icon: "figure.walk", tint: .black)
    private let xpChip      = ExploreSpotCell.makeChip(icon: "bolt.fill", tint: .black)

    private let chipsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // Action buttons ──────────────────────────────────────────────────────────

    private let mapButton: UIButton = {
        // 1. Change from .filled() to .tinted() to create that soft, secondary visual weight
        var cfg = UIButton.Configuration.tinted()
        
        // 2. Apply your deep green theme color.
        // (If you have this saved in your `Signal.Colors` struct, use that instead!)
        let themeColor = UIColor(red: 30/255, green: 63/255, blue: 47/255, alpha: 1.0)
        
        cfg.baseBackgroundColor = themeColor
        cfg.baseForegroundColor = themeColor
        
        cfg.cornerStyle = .capsule
        cfg.image = UIImage(systemName: "map.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        cfg.title = "Show on Map"
        cfg.imagePadding = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return outgoing
        }
        
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let proximityButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var b = a; b.font = UIFont.systemFont(ofSize: 14, weight: .semibold); return b
        }
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let buttonsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 10
        sv.distribution = .fillEqually
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppearance()
        setupLayout()
        mapButton.addTarget(self, action: #selector(mapTapped), for: .touchUpInside)
        proximityButton.addTarget(self, action: #selector(proximityTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    // Gradient is rebuilt in layoutSubviews once the frame is known.
    private var cardGradientLayer: CAGradientLayer?

    // MARK: - Card appearance

    private func setupAppearance() {
        contentView.backgroundColor     = .clear   // gradient provides the bg
        contentView.layer.cornerRadius  = Signal.Card.radius
        contentView.layer.masksToBounds = true
        layer.masksToBounds             = false    // shadow renders outside clip
        layer.shadowColor               = UIColor.black.cgColor
        layer.shadowOpacity             = Float(Signal.Card.shadowOpacity)
        layer.shadowOffset              = CGSize(width: 0, height: 3)
        layer.shadowRadius              = 8
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardGradient()
        // Keep shadow path in sync with the cell frame for performance.
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: Signal.Card.radius
        ).cgPath
    }

    /// Nature-inspired gradient: very light sage-green at the top fading to
    /// pure white — echoes the green wellness brand without shouting.
    private func updateCardGradient() {
        cardGradientLayer?.removeFromSuperlayer()
        let gl = CAGradientLayer()
        gl.frame        = contentView.bounds
        gl.cornerRadius = Signal.Card.radius
        gl.colors = [
            UIColor(red: 0.86, green: 0.96, blue: 0.90, alpha: 1.0).cgColor, // light sage
            UIColor.white.cgColor,
        ]
        gl.startPoint = CGPoint(x: 0.0, y: 0.0)
        gl.endPoint   = CGPoint(x: 1.0, y: 1.0)
        contentView.layer.insertSublayer(gl, at: 0)
        cardGradientLayer = gl
    }

    // MARK: - Layout

    private func setupLayout() {
        // Header stack
        let headerStack = UIStackView(arrangedSubviews: [headerIcon, titleLabel])
        headerStack.axis = .horizontal
        headerStack.spacing = 10
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Prompt stack
        let promptStack = UIStackView(arrangedSubviews: [promptIcon, promptLabel])
        promptStack.axis = .horizontal
        promptStack.spacing = 8
        promptStack.alignment = .top
        promptStack.translatesAutoresizingMaskIntoConstraints = false

        // Chips stack
        //chipsStack.addArrangedSubview(placeChip)
        chipsStack.addArrangedSubview(distChip)
        chipsStack.addArrangedSubview(xpChip)
        chipsStack.addArrangedSubview(UIView())   // trailing spacer

        // Buttons stack
        buttonsStack.addArrangedSubview(mapButton)
        buttonsStack.addArrangedSubview(proximityButton)

        // Main vertical stack
        let mainStack = UIStackView(arrangedSubviews: [
            headerStack,
            descriptionLabel,
            promptStack,
            chipsStack,
            buttonsStack,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 14
        mainStack.setCustomSpacing(16, after: headerStack)
        mainStack.setCustomSpacing(16, after: descriptionLabel)
        mainStack.setCustomSpacing(16, after: promptStack)
        mainStack.setCustomSpacing(18, after: chipsStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            headerIcon.widthAnchor.constraint(equalToConstant: 18),
            headerIcon.heightAnchor.constraint(equalToConstant: 18),

            promptIcon.widthAnchor.constraint(equalToConstant: 14),
            promptIcon.heightAnchor.constraint(equalToConstant: 14),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    // MARK: - Configure

    func configure(with spot: ExploreSpot) {
        // Header
        headerIcon.image = UIImage(systemName: spot.symbolName,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        titleLabel.text = "Nearby \(spot.categoryName)"

        // Description — mirrors Daily Adventure style
        let verbs: [String]
        switch spot.categoryName {
        case "Park":        verbs = ["Take a breather", "Reset your brain", "Step outside"]
        case "Green Space": verbs = ["Get some fresh air", "Break the indoor loop", "Step away from the desk"]
        default:            verbs = ["Take the scenic option", "Do a small urban quest", "Go explore"]
        }
        let verb = verbs.randomElement() ?? "Visit"
        descriptionLabel.text = "\(verb) at \(spot.name), about \(spot.distanceString) away."

        // Prompt
        promptLabel.text = spot.prompt

        // Info chips
        //configureChip(placeChip, text: spot.name)
        configureChip(distChip,  text: spot.distanceString)
        configureChip(xpChip,    text: "15 XP")

        // Proximity button state
        if spot.isVisited {
            configureProximityButton(title: "Visited ✓",
                                     icon: "checkmark.circle.fill",
                                     background: Signal.Colors.primaryGreen.withAlphaComponent(0.15),
                                     foreground: Signal.Colors.primaryGreen,
                                     enabled: false)
        } else {
            switch spot.proximityState {
            case .exact, .nearby:
                configureProximityButton(title: "Check In",
                                         icon: "location.fill",
                                         background: Signal.Colors.primaryGreen,
                                         foreground: .white,
                                         enabled: true)
            case .far:
                configureProximityButton(title: "Get Closer",
                                         icon: "location",
                                         background: UIColor.secondarySystemFill,
                                         foreground: .secondaryLabel,
                                         enabled: false)
            }
        }
    }

    private func configureProximityButton(title: String,
                                          icon: String,
                                          background: UIColor,
                                          foreground: UIColor,
                                          enabled: Bool) {
        var cfg = UIButton.Configuration.filled()
        cfg.cornerStyle = .capsule
        cfg.title = title
        cfg.image = UIImage(systemName: icon,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        cfg.imagePadding = 6
        cfg.baseBackgroundColor = background
        cfg.baseForegroundColor = foreground
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var b = a; b.font = UIFont.systemFont(ofSize: 14, weight: .semibold); return b
        }
        proximityButton.configuration = cfg
        proximityButton.isEnabled = enabled
        proximityButton.alpha = enabled ? 1.0 : 0.6
    }

    // MARK: - Chip helper

    private static func makeChip(icon: String, tint: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemFill
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let iv = UIImageView()
        iv.image = UIImage(systemName: icon,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        iv.tintColor = tint
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .light)
        label.textColor = tint
        label.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [iv, label])
        row.axis = .horizontal
        row.spacing = 4
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 13),
            iv.heightAnchor.constraint(equalToConstant: 13),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        // Tag: 1 = icon view, 2 = label (used in configureChip)
        iv.tag = 1
        label.tag = 2
        return container
    }

    private func configureChip(_ chip: UIView, text: String) {
        (chip.subviews.first(where: { $0 is UIStackView }) as? UIStackView)?
            .arrangedSubviews
            .compactMap { $0 as? UILabel }
            .first?.text = text
    }

    // MARK: - Actions

    @objc private func mapTapped()       { onShowMap?() }
    @objc private func proximityTapped() { onCheckIn?() }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        onShowMap = nil
        onCheckIn = nil
        descriptionLabel.text = nil
        promptLabel.text = nil
    }
}
