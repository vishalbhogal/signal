// ProfileViewController.swift
// Signal

import UIKit
import Combine

final class ProfileViewController: UIViewController {

    private let viewModel: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scroll container
    // A UIScrollView + content UIStackView lets both the profile header and the
    // badge grid scroll together as one continuous surface on small screens.

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Profile header views

    private let avatarView: UIView = {
        let v = UIView()
        v.backgroundColor = Signal.Colors.primaryGreen
        v.layer.cornerRadius = 50
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let initialsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let departmentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Badge section views

    private let badgeSectionHeader: UILabel = {
        let l = UILabel()
        l.text = "Explorer Badges"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Holds rows of badge tiles.  Rebuilt in `viewWillAppear` each time
    /// so it reflects the latest UserDefaults state without any caching.
    private let badgeGridStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Init

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Signal.Colors.background

        setupViews()
        bindViewModel()
        viewModel.loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh badge grid every time the tab is shown so it reflects
        // any new badges earned since the last visit.
        rebuildBadgeGrid()
    }

    // MARK: - Layout

    private func setupViews() {
        view.addSubview(scrollView)
        view.addSubview(activityIndicator)
        scrollView.addSubview(contentStack)

        // ── Profile header container ──────────────────────────────────────────
        let profileHeader = buildProfileHeader()
        contentStack.addArrangedSubview(profileHeader)

        // ── Divider ───────────────────────────────────────────────────────────
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let dividerWrapper = UIView()
        dividerWrapper.translatesAutoresizingMaskIntoConstraints = false
        dividerWrapper.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: dividerWrapper.topAnchor),
            divider.bottomAnchor.constraint(equalTo: dividerWrapper.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: dividerWrapper.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: dividerWrapper.trailingAnchor, constant: -20),
        ])
        contentStack.addArrangedSubview(dividerWrapper)
        contentStack.setCustomSpacing(24, after: profileHeader)
        contentStack.setCustomSpacing(24, after: dividerWrapper)

        // ── Badge section ─────────────────────────────────────────────────────
        let badgeContainer = UIView()
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeSectionHeader)
        badgeContainer.addSubview(badgeGridStack)
        NSLayoutConstraint.activate([
            badgeSectionHeader.topAnchor.constraint(equalTo: badgeContainer.topAnchor),
            badgeSectionHeader.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 20),
            badgeSectionHeader.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -20),

            badgeGridStack.topAnchor.constraint(equalTo: badgeSectionHeader.bottomAnchor, constant: 16),
            badgeGridStack.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 20),
            badgeGridStack.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -20),
            badgeGridStack.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -32),
        ])
        contentStack.addArrangedSubview(badgeContainer)

        // ── Constraints ───────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            // Width must match the scroll view so the stack doesn't scroll horizontally.
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func buildProfileHeader() -> UIView {
        avatarView.addSubview(initialsLabel)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(avatarView)
        container.addSubview(nameLabel)
        container.addSubview(roleLabel)
        container.addSubview(departmentLabel)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            avatarView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            avatarView.heightAnchor.constraint(equalToConstant: 100),

            initialsLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 20),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),

            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            roleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            departmentLabel.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 4),
            departmentLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            departmentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
        ])
        return container
    }

    // MARK: - Combine Binding

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle: break
                case .loading: self?.activityIndicator.startAnimating()
                case .loaded(let profile):
                    self?.activityIndicator.stopAnimating()
                    self?.configure(with: profile)
                case .error: self?.activityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }

    private func configure(with profile: ClinicianProfile) {
        initialsLabel.text = profile.avatarInitials
        nameLabel.text = profile.name
        roleLabel.text = profile.role
        departmentLabel.text = profile.interests
    }

    // MARK: - Badge Grid

    /// Rebuilds the badge grid from the current BadgeStore state.
    /// Arranges badges in rows of 3 tiles each.
    private func rebuildBadgeGrid() {
        // Remove previous rows before rebuilding.
        badgeGridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let all     = BadgeDefinition.all
        let earned  = BadgeStore.shared.earnedBadgeIDs
        let visited = BadgeStore.shared.parkVisitCount

        // Split into rows of 3.
        let columns = 3
        for rowStart in stride(from: 0, to: all.count, by: columns) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 12
            rowStack.distribution = .fillEqually

            let rowEnd = min(rowStart + columns, all.count)
            for badge in all[rowStart..<rowEnd] {
                let isEarned = earned.contains(badge.id)
                rowStack.addArrangedSubview(makeBadgeTile(badge: badge, isEarned: isEarned, visitCount: visited))
            }

            // Pad the last row with spacers if it has fewer than 3 badges.
            let remainder = (rowEnd - rowStart)
            if remainder < columns {
                for _ in remainder..<columns {
                    let spacer = UIView()
                    rowStack.addArrangedSubview(spacer)
                }
            }

            badgeGridStack.addArrangedSubview(rowStack)
        }
    }

    /// Builds one badge tile (icon circle + title label + progress hint).
    private func makeBadgeTile(badge: BadgeDefinition, isEarned: Bool, visitCount: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Background card
        container.backgroundColor = isEarned
            ? Signal.Colors.primaryGreen.withAlphaComponent(0.10)
            : UIColor.secondarySystemGroupedBackground
        container.layer.cornerRadius = 14

        // Icon circle
        let circleDiameter: CGFloat = 52
        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.layer.cornerRadius = circleDiameter / 2
        circle.backgroundColor = isEarned
            ? Signal.Colors.primaryGreen.withAlphaComponent(0.20)
            : UIColor.tertiarySystemFill

        let icon = UIImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = isEarned ? Signal.Colors.primaryGreen : .tertiaryLabel

        if isEarned {
            icon.image = UIImage(systemName: badge.symbolName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        } else {
            // Show a lock icon over the badge symbol.
            icon.image = UIImage(systemName: "lock.fill",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        }

        circle.addSubview(icon)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = isEarned ? badge.title : "Locked"
        titleLabel.font = .systemFont(ofSize: 12, weight: isEarned ? .semibold : .regular)
        titleLabel.textColor = isEarned ? .label : .tertiaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        // Progress hint for unearned badges (e.g. "3 / 5 visits")
        let progressLabel = UILabel()
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 10, weight: .regular)
        progressLabel.textColor = .quaternaryLabel
        progressLabel.textAlignment = .center
        if !isEarned {
            progressLabel.text = "\(min(visitCount, badge.threshold)) / \(badge.threshold) visits"
        }

        container.addSubview(circle)
        container.addSubview(titleLabel)
        container.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circle.widthAnchor.constraint(equalToConstant: circleDiameter),
            circle.heightAnchor.constraint(equalToConstant: circleDiameter),

            icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),

            progressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            progressLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            progressLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            progressLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        return container
    }
}
