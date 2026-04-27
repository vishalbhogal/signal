//
//  GreetingHeaderView.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//


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