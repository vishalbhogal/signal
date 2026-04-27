// DashboardViewController.swift
// Signal
//
// Created by Vishal Bhogal on 27/04/26.
// ─────────────────────────────────────────────────────────────────────────────
// UICOLLECTIONVIEW + COMPOSITIONAL LAYOUT — HOW IT ALL WORKS
// ─────────────────────────────────────────────────────────────────────────────
//
// UICollectionView is Apple's most powerful list/grid view.
// Unlike UITableView (only vertical rows), CollectionView supports any layout.
//
// COMPOSITIONAL LAYOUT (iOS 13+) lets you describe layouts as nested boxes:
//
//   Section  ← one "page" of content (e.g. the risk card section)
//     └── Group  ← a row or column of items
//           └── Item  ← a single cell
//
// Each level is sized independently using NSCollectionLayoutDimension:
//   .fractionalWidth(0.5)  → 50% of the parent's width
//   .absolute(200)         → exactly 200 points
//   .estimated(100)        → starts at 100pts, expands to fit content
//
// DIFFABLE DATA SOURCE (iOS 13+):
//   Instead of reloadData() which blurs everything, DiffableDataSource
//   calculates exactly which cells changed and animates only those.
//   It needs two enum types: SectionIdentifier and ItemIdentifier,
//   both Hashable so it can compare old and new snapshots.
//
// ─────────────────────────────────────────────────────────────────────────────

import UIKit
import Combine
import CoreLocation
import MapKit
import UserNotifications


// MARK: - Section / Item Identifiers
 
enum DashboardSection: Int, CaseIterable, Sendable {
    case riskCard       // Big risk score card at the top
    case stats          // Horizontal scroll of stat chips
    case explore        // Nearby parks / landmarks (Explorer feature)
    case insights       // List of insight cards
}

nonisolated enum DashboardItem: Hashable, Sendable {
    case riskScore(BurnoutRiskScore)
    case stat(StatItem)
    case insight(HealthInsight)
    case exploreSpot(ExploreSpot)
}

// MARK: - View Controller

final class DashboardViewController: UIViewController {
    // MARK: Properties
    private let viewModel: DashboardViewModel
    private let exploreManager: ExploreManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Collection View
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = Signal.Colors.background
        cv.register(RiskScoreCell.self, forCellWithReuseIdentifier: RiskScoreCell.reuseID)
        cv.register(StatCell.self, forCellWithReuseIdentifier: StatCell.reuseID)
        cv.register(InsightCell.self, forCellWithReuseIdentifier: InsightCell.reuseID)
        cv.register(ExploreSpotCell.self, forCellWithReuseIdentifier: ExploreSpotCell.reuseID)
        
        cv.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.reuseID
        )
        cv.register(
            GreetingHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: GreetingHeaderView.reuseID
        )
        return cv
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<DashboardSection, DashboardItem>!
    private var currentData: DashboardData?
    private var exploreSpots: [ExploreSpot] = []
    
    // MARK: Other Views
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: Init
    init(viewModel: DashboardViewModel, exploreManager: ExploreManager = ExploreManager()) {
        self.viewModel = viewModel
        self.exploreManager = exploreManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("Use init(viewModel:exploreManager:)") }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        requestNotificationPermission()
        setupViews()
        configureDataSource()
        bindViewModel()
        viewModel.loadData()
        bindExploreManager()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        UIView.backgroundGradientLayer.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        exploreManager.requestLocationIfNeeded()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.layer.insertSublayer(UIView.backgroundGradientLayer, at: 0)
        view.backgroundColor = .clear
        collectionView.backgroundColor = .clear
        
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        view.addSubview(errorLabel)
        collectionView.delegate = self
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
        
        // Pull-to-refresh
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refresh
    }
    
    @objc private func handleRefresh() {
        viewModel.loadData()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notifications allowed")
            }
        }
    }
    
    // MARK: - Combine Binding
    
    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else {
                    print("self = nil")
                    return
                }
                self.render(state: state)
            }
            .store(in: &cancellables)
    }
    
    /// Subscribes to ExploreManager.$spots and refreshes only the explore
    /// section of the snapshot whenever nearby spots change.
    private func bindExploreManager() {
        exploreManager.$spots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] spots in
                guard let self else {
                    print("self = nil")
                    return
                }
                self.applyExploreSnapshot(spots: spots)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Rendering
    
    private func render(state: DashboardState) {
        collectionView.refreshControl?.endRefreshing()
        
        switch state {
        case .idle:
            break
            
        case .loading:
            activityIndicator.startAnimating()
            errorLabel.isHidden = true
            
        case .loaded(let data):
            activityIndicator.stopAnimating()
            errorLabel.isHidden = true
            applySnapshot(data: data)
            
        case .error(let message):
            activityIndicator.stopAnimating()
            errorLabel.isHidden = false
            errorLabel.text = "Unable to load data.\n\(message)"
        }
    }
    
    // MARK: - Diffable Data Source
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<DashboardSection, DashboardItem>(
            collectionView: collectionView
        ) { (collectionView: UICollectionView, indexPath: IndexPath, item: DashboardItem) in
            
            // Switch on the item type to dequeue the correct cell.
            switch item {
                
            case .riskScore(let score):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: RiskScoreCell.reuseID,
                    for: indexPath
                ) as! RiskScoreCell
                cell.configure(with: score)
                return cell
                
            case .stat(let stat):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: StatCell.reuseID,
                    for: indexPath
                ) as! StatCell
                cell.configure(with: stat)
                return cell
                
            case .insight(let insight):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: InsightCell.reuseID,
                    for: indexPath
                ) as! InsightCell
                cell.configure(with: insight)
                cell.onDismiss = { [weak self] in
                    self?.dismissInsight(insight)
                }
                cell.onTakeAction = { [weak self] in
                    self?.handleTakeAction(for: insight)
                }
                return cell
                
            case .exploreSpot(let spot):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ExploreSpotCell.reuseID,
                    for: indexPath
                ) as! ExploreSpotCell
                cell.configure(with: spot)
                cell.onCheckIn = { [weak self] in
                    self?.handleCheckIn(spot: spot)
                }
                cell.onShowMap = { [weak self] in
                    self?.handleShowMap(for: spot)
                }
                return cell
            }
        }
        
        // Supplementary view provider — called for section headers.
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            guard let self = self, let dataSource = self.dataSource else { return nil }
            
            // ‼️ THE FIX: Ask the snapshot exactly which section is currently at this index
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            
            if section == .riskCard {
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: GreetingHeaderView.reuseID,
                    for: indexPath
                ) as! GreetingHeaderView
                header.configure()
                
                header.onProfileTap = { [weak self] in
                    self?.tabBarController?.selectedIndex = 3
                }
                header.onBellTap = { [weak self] in
                    // Placeholder: shake the bell or show a notifications sheet.
                    _ = self
                }
                return header
            }
            
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseID,
                for: indexPath
            ) as! SectionHeaderView
            
            switch section {
            case .stats:      header.configure(title: "This Week")
            case .insights:   header.configure(title: "Insights")
            case .explore:    header.configure(title: "Explore Nearby")
            default:          break
            }
            return header
        }
    }

    private func applySnapshot(data: DashboardData) {
        currentData = data
        var snapshot = NSDiffableDataSourceSnapshot<DashboardSection, DashboardItem>()
        var activeSections: [DashboardSection] = [.riskCard, .stats]
        if !data.insights.isEmpty {
            activeSections.append(.insights)
        }
        activeSections.append(.explore)
        
        snapshot.appendSections(activeSections)
        snapshot.appendItems([DashboardItem.riskScore(data.riskScore)], toSection: .riskCard)
        snapshot.appendItems(data.statItems.map { DashboardItem.stat($0) }, toSection: .stats)
        if !data.insights.isEmpty {
            snapshot.appendItems(data.insights.map { DashboardItem.insight($0) }, toSection: .insights)
        }
        snapshot.appendItems(exploreSpots.map { DashboardItem.exploreSpot($0) }, toSection: .explore)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    
    private func applyExploreSnapshot(spots: [ExploreSpot]) {
        var seen = Set<String>()
        let unique = spots.filter { seen.insert($0.id).inserted }
        exploreSpots = unique
        var snapshot = dataSource.snapshot()
        guard snapshot.sectionIdentifiers.contains(.explore) else { return }
        let current = snapshot.itemIdentifiers(inSection: .explore)
        snapshot.deleteItems(current)
        snapshot.appendItems(unique.map { .exploreSpot($0) }, toSection: .explore)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
}

// MARK: - Sheet helpers

extension DashboardViewController {

    /// Presents a view controller as a resizable bottom sheet with a grabber.
    private func presentAsSheet(_ vc: UIViewController) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            // Medium shows enough content without covering the whole screen;
            // the user can drag up to large for the full breakdown / table.
            sheet.detents               = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = Signal.Card.radius
        }
        present(vc, animated: true)
    }

    private func dismissInsight(_ insight: HealthInsight) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([.insight(insight)])
        // 2. If that was the last item in the section, delete the section (and its header)
        if snapshot.numberOfItems(inSection: .insights) == 0 {
            snapshot.deleteSections([.insights])
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    /// Opens Apple Maps centred on the explore spot.
    private func handleShowMap(for spot: ExploreSpot) {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark  = MKPlacemark(coordinate: coordinate)
        let mapItem    = MKMapItem(placemark: placemark)
        mapItem.name   = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue,
        ])
    }

    private func handleCheckIn(spot: ExploreSpot) {
        let newBadges = exploreManager.markVisited(spot)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard !newBadges.isEmpty else { return }
        let badge = newBadges.last!
        let alert = UIAlertController(
            title: "Badge Unlocked! 🏅",
            message: "\"\(badge.title)\"\n\(badge.description)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        present(alert, animated: true)
    }

    private func handleTakeAction(for insight: HealthInsight) {
        let alert = UIAlertController(
            title: insight.title,
            message: "Choose a next step to address this signal.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Schedule a break", style: .default) { [weak self] _ in
            self?.scheduleBreakReminder()
        })
        alert.addAction(UIAlertAction(title: "Talk to a colleague", style: .default) { [weak self] _ in
            self?.openColleagueMessageSheet()
        })
        alert.addAction(UIAlertAction(title: "Mark as done & dismiss", style: .default) { [weak self] _ in
            self?.dismissInsight(insight)
        })
        let presenter = self.tabBarController ?? self
        presenter.present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension DashboardViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        if let riskCell = cell as? RiskScoreCell {
            riskCell.triggerSymbolAnimations()
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let data = currentData else { return }

        switch item {
        case .riskScore(let score):
            let vc = RiskBreakdownSheetViewController(score: score, features: data.features)
            presentAsSheet(vc)

        case .stat(let stat):
            let sorted = data.snapshots.sorted { $0.date < $1.date }
            let vc = MetricDetailSheetViewController(stat: stat, snapshots: sorted)
            presentAsSheet(vc)

        default:
            break
        }
    }
}

extension DashboardViewController {
    // MARK: - Compositional Layout
    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self, let dataSource = self.dataSource else {
                let size = NSCollectionLayoutSize(widthDimension: .absolute(0), heightDimension: .absolute(0))
                return NSCollectionLayoutSection(group: NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: []))
            }
            
            //  snapshot for the exact section at this index
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            
            switch section {
            case .riskCard:   return Self.makeRiskCardSection()
            case .stats:      return Self.makeStatsSection()
            case .insights:   return Self.makeInsightsSection()
            case .explore:    return Self.makeExploreSection()
            }
        }
        return layout
    }

    // MARK: Section Layout Builders
    private static func makeRiskCardSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),   // 100% of group width
            heightDimension: .fractionalHeight(1.0)  // 100% of group height
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(240)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16)

        let greetingHeaderSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(80)
        )
        let greetingHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: greetingHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [greetingHeader]
        return section
    }

    /// Horizontally scrolling row of stat chips.
    private static func makeStatsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(140),
            heightDimension: .absolute(130)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(580),
            heightDimension: .absolute(120)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: Signal.Space.lg, trailing: 16)

        // .continuous for section to scrolls horizontally, independently of the main scroll.
        section.orthogonalScrollingBehavior = .continuous

        let header = makeHeader()
        header.contentInsets = NSDirectionalEdgeInsets(top: Signal.Space.md, leading: 0, bottom: 0, trailing: 0)
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Vertical list of insight cards, each sized to fit its content.
    private static func makeInsightsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(90)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(90)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10  // Gap between insight cards
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        
        let header = makeHeader()
        header.contentInsets = NSDirectionalEdgeInsets(top: Signal.Space.md, leading: 0, bottom: 0, trailing: 0)
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Single large card for the explore spot — estimated tall enough for the full card.
    private static func makeExploreSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(280)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(280)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16)
        
        let header = makeHeader()
        header.contentInsets = NSDirectionalEdgeInsets(top: Signal.Space.md, leading: 0, bottom: 0, trailing: 0)
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Creates a standard section header supplementary item.
    private static func makeHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top  // Header sits above the section's content
        )
    }
}

// MARK: Insight+Actions
extension DashboardViewController {
    private func openColleagueMessageSheet() {
        let message = "Hey, do you have 5 minutes to chat today? Need to bounce something off you."
        // The share sheet can share text, URLs, or images
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = self.collectionView
        }
        let presenter = self.tabBarController ?? self
        presenter.present(activityVC, animated: true)
    }
    
    private func scheduleBreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for your break 🧘"
        content.body = "You scheduled a quick mental buffer. Step away for 15 mins, and come back refreshed."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.showSuccessToast(message: "Break scheduled for 15 mins")
                }
            }
        }
    }

    // Optional: A quick visual feedback helper
    private func showSuccessToast(message: String) {
        let alert = UIAlertController(title: "Confirmed", message: message, preferredStyle: .alert)
        let presenter = self.tabBarController ?? self
        presenter.present(alert, animated: true)
        
        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}
