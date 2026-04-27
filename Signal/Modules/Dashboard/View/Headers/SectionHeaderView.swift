//
//  SectionHeaderView.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import UIKit
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
