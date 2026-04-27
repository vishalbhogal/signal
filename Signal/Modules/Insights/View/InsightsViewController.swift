// InsightsViewController.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// Full-screen insights list using UICollectionView with a simple vertical layout.

import UIKit
import Combine


final class InsightsViewController: UIViewController {

    private let viewModel: InsightsViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: Collection View Setup

    private lazy var collectionView: UICollectionView = {
        // Simple vertical list layout — one full-width card per insight.
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.showsSeparators = false
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(InsightCell.self, forCellWithReuseIdentifier: InsightCell.reuseID)
        return cv
    }()

    // Diffable data source — reuses our existing InsightCell.
    private var dataSource: UICollectionViewDiffableDataSource<InsightsSection, HealthInsight>!

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    init(viewModel: InsightsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Insights"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(collectionView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        configureDataSource()
        bindViewModel()
        viewModel.loadData()
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<InsightsSection, HealthInsight>(
            collectionView: collectionView
        ) { (cv: UICollectionView, indexPath: IndexPath, insight: HealthInsight) in
            let cell = cv.dequeueReusableCell(
                withReuseIdentifier: InsightCell.reuseID,
                for: indexPath
            ) as! InsightCell
            cell.configure(with: insight)
            return cell
        }
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle: break
                case .loading: self?.activityIndicator.startAnimating()
                case .loaded(let insights):
                    self?.activityIndicator.stopAnimating()
                    var snapshot = NSDiffableDataSourceSnapshot<InsightsSection, HealthInsight>()
                    snapshot.appendSections([.main])
                    snapshot.appendItems(insights)
                    self?.dataSource.apply(snapshot, animatingDifferences: true)
                case .error: self?.activityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }
}
