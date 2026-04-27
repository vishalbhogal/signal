// DashboardViewController.swift
// Signal
//
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

// MARK: - Section / Item Identifiers

/// All dashboard sections, in display order.
/// These are the "section identifiers" for the diffable data source.
nonisolated enum DashboardSection: Int, CaseIterable, Sendable {
    case riskCard       // Big risk score card at the top
    case stats          // Horizontal scroll of stat chips
   // case trendChart     // Inline mini chart
    case explore        // Nearby parks / landmarks (Explorer feature)
    case insights       // List of insight cards
    
}

/// Every cell's data is represented as one of these cases.
/// Associated values carry the actual model — the cell uses them to configure itself.
/// `Sendable` is required by UICollectionViewDiffableDataSource's generic constraint
/// so the snapshot can be safely passed across concurrency boundaries.
nonisolated enum DashboardItem: Hashable, Sendable {
    case riskScore(BurnoutRiskScore)
    case stat(StatItem)
    case insight(HealthInsight)
    case exploreSpot(ExploreSpot)
}

/// A single stat chip displayed in the horizontal stats section.
/// UIColor isn't Hashable natively — we hash on title+value+unit instead,
/// which uniquely identifies each stat within a snapshot anyway.
struct StatItem: Sendable {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let bubbleColor: UIColor        // Pastel bubble behind the icon
    let iconColor: UIColor          // Darker tint for the icon itself
    let sparklineValues: [Double]   // 7 daily values for the mini sparkline
}

extension StatItem: Hashable {
    static func == (lhs: StatItem, rhs: StatItem) -> Bool {
        lhs.title == rhs.title && lhs.value == rhs.value && lhs.unit == rhs.unit
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(value)
        hasher.combine(unit)
    }
}

// MARK: - View Controller

final class DashboardViewController: UIViewController {

    // MARK: Properties

    private let viewModel: DashboardViewModel

    /// Manages CoreLocation + MapKit for the Explore Nearby section.
    /// Injected by AppCoordinator so it can be shared / tested independently.
    private let exploreManager: ExploreManager

    // `Set<AnyCancellable>` stores all active Combine subscriptions.
    // When this VC is deallocated, the set is deallocated too,
    // which cancels all subscriptions automatically — no memory leaks.
    private var cancellables = Set<AnyCancellable>()

    // MARK: Collection View

    /// The main scroll view that renders all dashboard sections.
    private lazy var collectionView: UICollectionView = {
        // Pass our compositional layout into the CollectionView at init time.
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = Signal.Colors.background

        // Register each cell class so the data source can dequeue them.
        // Registering with a type (not a nib) means no separate .xib files needed.
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

    /// Diffable data source — generic over our Section and Item enums.
    /// It holds a reference to the collection view and provides cells on demand.
    private var dataSource: UICollectionViewDiffableDataSource<DashboardSection, DashboardItem>!

    /// The most-recently loaded dashboard payload.  Retained so that tapping a
    /// stat chip or the risk card can pass the full data to the detail sheets.
    private var currentData: DashboardData?

    /// Current explore spots — kept separately so updates from ExploreManager
    /// can refresh only the explore section without rebuilding the entire snapshot.
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
        // Must call super.init before touching self in a designated init.
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(viewModel:exploreManager:)") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide the navigation bar entirely — the greeting header inside the
        // collection view replaces it with a more intentional design.
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupViews()
        configureDataSource()
        bindViewModel()

        // Trigger the first data load.
        viewModel.loadData()
        bindExploreManager()
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // If you don't do this, the gradient remains 0x0 pixels wide!
        backgroundGradientLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ask for location each time the tab is visible so proximity states
        // stay fresh when the user moves around between app sessions.
        exploreManager.requestLocationIfNeeded()
    }

    // Fixed background gradient — sits behind the scrolling collection view.
    // Using a dedicated layer (not the collectionView background) means the
    // gradient stays anchored to the screen while content scrolls over it.
    private let backgroundGradientLayer: CAGradientLayer = {
        let gl = CAGradientLayer()
        
        // 1. Top: Base background (clean for the header/dark card)
        // 2. Bottom: Very pale, premium sage (grounds the colorful chips)
        gl.colors = [
            Signal.Colors.background.cgColor,
            UIColor(red: 0.94, green: 0.97, blue: 0.95, alpha: 1.0).cgColor
        ]
        
        // Start the fade about 40% down the screen, right below the main card
        gl.locations = [0.4, 1.0]
        
        // True vertical fade (looks much cleaner behind scrollable lists than diagonal)
        gl.startPoint = CGPoint(x: 0.5, y: 0.0)
        gl.endPoint   = CGPoint(x: 0.5, y: 1.0)
        
        return gl
    }()

    // MARK: - Setup

    private func setupViews() {
        // Insert gradient behind everything; collectionView is transparent so it shows through.
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
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

    // MARK: - Combine Binding

    private func bindViewModel() {
        // Subscribe to $state — this closure runs every time state changes.
        // `receive(on:)` ensures the closure runs on the main thread (required for UIKit).
        // `sink` is the "subscribe and receive values" operator.
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                // `[weak self]` prevents the closure from retaining the VC strongly.
                self?.render(state: state)
            }
            .store(in: &cancellables)
        // `.store(in:)` saves the AnyCancellable into our set.
        // Without this, the subscription would be cancelled immediately (no one holds it).
    }

    /// Subscribes to ExploreManager.$spots and refreshes only the explore
    /// section of the snapshot whenever nearby spots change.
    private func bindExploreManager() {
        exploreManager.$spots
            .receive(on: DispatchQueue.main)
            .sink { [weak self] spots in
                self?.applyExploreSnapshot(spots: spots)
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
        // The data source is initialized with the collection view and a cell provider closure.
        // This closure is called every time a cell needs to be displayed.
        // Think of it as cellForItemAt, but type-safe.
        dataSource = UICollectionViewDiffableDataSource<DashboardSection, DashboardItem>(
            collectionView: collectionView
        ) { (collectionView: UICollectionView, indexPath: IndexPath, item: DashboardItem) in
            
            // Switch on the item type to dequeue the correct cell.
            switch item {
                
            case .riskScore(let score):
                // dequeueReusableCell reuses a cell that scrolled off-screen
                // instead of allocating a new one — critical for performance.
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
                // Dismiss: remove the item from the current snapshot (animated).
                cell.onDismiss = { [weak self] in
                    self?.dismissInsight(insight)
                }
                // Take Action: present a contextual alert with next-step options.
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
        // Supplementary view provider — called for section headers.
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            guard let self = self, let dataSource = self.dataSource else { return nil }
            
            // ‼️ THE FIX: Ask the snapshot exactly which section is currently at this index
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            
            // The riskCard section gets the full greeting header instead of a plain title.
            if section == .riskCard {
                let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: GreetingHeaderView.reuseID,
                    for: indexPath
                ) as! GreetingHeaderView
                header.configure()
                
                // Wire tab-switch closures — weak capture avoids retain cycle.
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
            
            // Now this switch statement is perfectly synchronized with your data!
            switch section {
            case .stats:      header.configure(title: "This Week")
                //case .trendChart: header.configure(title: "Sleep")
            case .insights:   header.configure(title: "Insights")
            case .explore:    header.configure(title: "Explore Nearby")
            default:          break
            }
            return header
        }
    }

    /// Builds a new NSDiffableDataSourceSnapshot and applies it.
    /// The diff engine figures out what changed and animates only those cells.
    private func applySnapshot(data: DashboardData) {
        currentData = data
        var snapshot = NSDiffableDataSourceSnapshot<DashboardSection, DashboardItem>()
        
        // 1. Dynamically build the active sections
        var activeSections: [DashboardSection] = [.riskCard, .stats]
        
        // Only add the insights section if there are actually insights to show
        if !data.insights.isEmpty {
            activeSections.append(.insights)
        }
        activeSections.append(.explore)
        
        snapshot.appendSections(activeSections)
        
        // 2. Section: Risk Card
        snapshot.appendItems([DashboardItem.riskScore(data.riskScore)], toSection: .riskCard)
        
        // 3. Section: Stats
        let stats = buildStatItems(from: data.features, snapshots: data.snapshots)
        snapshot.appendItems(stats.map { DashboardItem.stat($0) }, toSection: .stats)
        
        // 4. Section: Insights (Conditional)
        if !data.insights.isEmpty {
            snapshot.appendItems(data.insights.map { DashboardItem.insight($0) }, toSection: .insights)
        }
        
        // 5. Section: Explore Nearby
        snapshot.appendItems(exploreSpots.map { DashboardItem.exploreSpot($0) }, toSection: .explore)
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    /// Refreshes only the explore section without rebuilding the full snapshot.
    /// Called whenever ExploreManager publishes new spots.
    private func applyExploreSnapshot(spots: [ExploreSpot]) {
        // Safety-deduplicate by id — DiffableDataSource crashes on duplicate identifiers.
        var seen = Set<String>()
        let unique = spots.filter { seen.insert($0.id).inserted }

        exploreSpots = unique
        var snapshot = dataSource.snapshot()
        // Guard: explore section may not yet exist if initial data hasn't loaded.
        guard snapshot.sectionIdentifiers.contains(.explore) else { return }
        let current = snapshot.itemIdentifiers(inSection: .explore)
        snapshot.deleteItems(current)
        snapshot.appendItems(unique.map { .exploreSpot($0) }, toSection: .explore)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func buildStatItems(from features: WeeklyBehavioralFeatures,
                                snapshots: [DailyHealthSnapshot]) -> [StatItem] {
        // Sort oldest → newest so the sparkline reads left-to-right in time.
        let sorted = snapshots.sorted { $0.date < $1.date }
        return [
            StatItem(
                title: "Sleep",
                value: String(format: "%.1f", features.avgSleepHours),
                unit: "hrs",
                iconName: "moon.fill",
                bubbleColor: Signal.Colors.sleepBubble,
                iconColor:   Signal.Colors.sleepIcon,
                sparklineValues: sorted.map { $0.sleepHours }
            ),
            StatItem(
                title: "Steps",
                value: "\(Int(features.avgStepCount))",
                unit: "avg",
                iconName: "figure.walk",
                bubbleColor: Signal.Colors.stepsBubble,
                iconColor:   Signal.Colors.stepsIcon,
                sparklineValues: sorted.map { Double($0.stepCount) / 1000 }
            ),
            StatItem(
                title: "HRV",
                value: "\(Int(features.avgHRV))",
                unit: "ms",
                iconName: "waveform.path.ecg",
                bubbleColor: Signal.Colors.hrvBubble,
                iconColor:   Signal.Colors.hrvIcon,
                sparklineValues: sorted.map { $0.heartRateVariability }
            ),
            StatItem(
                title: "Shift",
                value: String(format: "%.1f", features.avgWorkHours),
                unit: "hrs",
                iconName: "briefcase.fill",
                bubbleColor: Signal.Colors.workBubble,
                iconColor:   Signal.Colors.workIcon,
                sparklineValues: sorted.map { $0.workHours }
            )
        ]
    }

    // MARK: - Compositional Layout

    /// Builds the entire dashboard layout.
    /// Each section has its own layout configuration defined in a helper below.
    private func makeLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            
            // 1. Safely unwrap the data source. (It may be nil during the very first initialization)
            guard let self = self, let dataSource = self.dataSource else {
                // Fallback empty layout before data source is hooked up
                let size = NSCollectionLayoutSize(widthDimension: .absolute(0), heightDimension: .absolute(0))
                return NSCollectionLayoutSection(group: NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: []))
            }
            
            // 2. Ask the snapshot for the exact section at this index
            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            
            // 3. Switch directly on the strongly-typed enum
            switch section {
            case .riskCard:   return Self.makeRiskCardSection()
            case .stats:      return Self.makeStatsSection()
                // case .trendChart: return Self.makeChartSection()
            case .insights:   return Self.makeInsightsSection()
            case .explore:    return Self.makeExploreSection()
            }
        }
        return layout
    }

    // MARK: Section Layout Builders

    /// Full-width card at the top showing the overall risk score.
    private static func makeRiskCardSection() -> NSCollectionLayoutSection {
        // Item: fills the full width and height of its group.
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),   // 100% of group width
            heightDimension: .fractionalHeight(1.0)  // 100% of group height
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // Risk card is taller now to comfortably fit the ring gauge + text without overlap.
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(240)
        )
        // .horizontal means items are laid out side by side.
        // count: 1 means there's only one item per group (one card).
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16)
        // The greeting header for this section is taller than a normal title header.
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
        // Stat chips: 130pt wide, 120pt tall — enough room for icon + value + sparkline.
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

        // .continuous means the section scrolls horizontally, independently of the main scroll.
        // This is what creates the "horizontal carousel" effect for stats.
        section.orthogonalScrollingBehavior = .continuous

        let header = makeHeader()
        header.contentInsets = NSDirectionalEdgeInsets(top: Signal.Space.md, leading: 0, bottom: 0, trailing: 0)
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Full-width chart cell.
    private static func makeChartSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(220)  // Fixed height for the chart
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    /// Vertical list of insight cards, each sized to fit its content.
    private static func makeInsightsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(90)  // .estimated lets cells self-size
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

    /// Removes a dismissed insight from the current snapshot without reloading
    /// all data.  The diffable data source animates the deletion automatically.
    private func dismissInsight(_ insight: HealthInsight) {
        var snapshot = dataSource.snapshot()
        // 1. Delete the specific item
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

    /// Called when the user taps "Check In" on an explore spot card.
    /// Marks the spot as visited via ExploreManager and shows a badge alert
    /// if a new explorer badge was unlocked.
    private func handleCheckIn(spot: ExploreSpot) {
        let newBadges = exploreManager.markVisited(spot)

        // Haptic feedback — signals a successful check-in.
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        guard !newBadges.isEmpty else { return }

        // Show the first newly earned badge.  If multiple unlock at once
        // (unlikely in practice) we just show the most prestigious one.
        let badge = newBadges.last!
        let alert = UIAlertController(
            title: "Badge Unlocked! 🏅",
            message: "\"\(badge.title)\"\n\(badge.description)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        present(alert, animated: true)
    }

    /// Shows a contextual action sheet so the clinician can choose a concrete
    /// next step rather than just reading a text card.
    private func handleTakeAction(for insight: HealthInsight) {
        let alert = UIAlertController(
            title: insight.title,
            message: "Choose a next step to address this signal.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Schedule a break", style: .default))
        alert.addAction(UIAlertAction(title: "Talk to a colleague", style: .default))
        alert.addAction(UIAlertAction(title: "Mark as done & dismiss", style: .default) { [weak self] _ in
            self?.dismissInsight(insight)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // On iPad the action sheet needs an anchor; pointing at the collection view
        // is safe because it always exists.
        alert.popoverPresentationController?.sourceView = collectionView
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension DashboardViewController: UICollectionViewDelegate {
    /// Called just before a cell appears on screen — perfect timing to trigger
    /// one-shot symbol animations (they run once then stop automatically).
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        if let riskCell = cell as? RiskScoreCell {
            riskCell.triggerSymbolAnimations()
        }
    }

    /// Handles taps on the risk card (opens score breakdown) and stat chips
    /// (opens metric detail).  Insight-cell taps are handled by the buttons
    /// inside the cell, so they fall through to the default no-op.
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let data = currentData else { return }

        switch item {
        case .riskScore(let score):
            let vc = RiskBreakdownSheetViewController(score: score, features: data.features)
            presentAsSheet(vc)

        case .stat(let stat):
            // Pass snapshots sorted oldest → newest so the breakdown table
            // reads chronologically from top to bottom.
            let sorted = data.snapshots.sorted { $0.date < $1.date }
            let vc = MetricDetailSheetViewController(stat: stat, snapshots: sorted)
            presentAsSheet(vc)

        default:
            break
        }
    }
}
