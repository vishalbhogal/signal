// TrendsViewController.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//
// Shows full-screen trend charts for each behavioral metric.
// Uses the same UIHostingController + Apple Charts approach as ChartCell,
// but with dedicated charts per metric on a scrollable page.

import UIKit
import SwiftUI
import Combine

final class TrendsViewController: UIViewController {

    private let viewModel: TrendsViewModel
    private var cancellables = Set<AnyCancellable>()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 24
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    init(viewModel: TrendsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trends"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = Signal.Colors.background

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // StackView width = scrollView width so it scrolls vertically only.
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        bindViewModel()
        viewModel.loadData()
    }

    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle: break
                case .loading:
                    self?.activityIndicator.startAnimating()
                    
                case .loaded(let snapshots):
                    self?.activityIndicator.stopAnimating()
                    self?.buildCharts(from: snapshots)
                    
                case .error(let msg):
                    self?.activityIndicator.stopAnimating()
                    print("Trends error: \(msg)")
                }
            }
            .store(in: &cancellables)
    }

    /// Creates one chart card per metric and adds them to the vertical stack.
    private func buildCharts(from snapshots: [DailyHealthSnapshot]) {
        // Remove any previously added chart cards (e.g. on refresh).
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let charts: [(title: String, view: AnyView)] = [
            ("Sleep Hours",      AnyView(MetricChartView(snapshots: snapshots, metric: .sleep))),
            ("Step Count",       AnyView(MetricChartView(snapshots: snapshots, metric: .steps))),
            ("HRV (ms)",         AnyView(MetricChartView(snapshots: snapshots, metric: .hrv))),
            ("Work Hours",       AnyView(MetricChartView(snapshots: snapshots, metric: .workHours)))
        ]

        for chart in charts {
            let card = makeChartCard(title: chart.title, chartView: chart.view)
            stackView.addArrangedSubview(card)
        }
    }

    /// Wraps a SwiftUI chart in a UIKit card view using UIHostingController.
    private func makeChartCard(title: String, chartView: AnyView) -> UIView {
        let card = UIView()
        card.backgroundColor = Signal.Colors.cardSurface
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // UIHostingController bridges the SwiftUI chart into UIKit.
        let hosting = UIHostingController(rootView: chartView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        // IMPORTANT: Must add the hosting controller as a child of self,
        // otherwise SwiftUI lifecycle events won't reach it correctly.
        addChild(hosting)
        card.addSubview(titleLabel)
        card.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),

            hosting.view.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            hosting.view.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            hosting.view.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            hosting.view.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            hosting.view.heightAnchor.constraint(equalToConstant: 180)
        ])

        return card
    }
}
