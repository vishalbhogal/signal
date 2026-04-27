// SplashViewController.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//
// Displays a Lottie animation on launch, then fires a callback
// so the AppCoordinator can transition to the main tab bar.

import UIKit
import Lottie  // Imported from the SPM package you installed

final class SplashViewController: UIViewController {

    // MARK: - Callback

    /// Set by AppCoordinator. Called when the animation finishes.
    /// Using a closure here avoids a formal delegate protocol for a one-time event.
    var onAnimationComplete: (() -> Void)?

    // MARK: - Views

    /// LottieAnimationView renders a JSON-based vector animation.
    /// It's a UIView subclass — you position it like any other view.
    private let animationView: LottieAnimationView = {
        // "splash_animation" is the name of the .json Lottie file in your bundle.
        // Add a Lottie JSON file to the project and rename it to "splash_animation".
        // You can find free animations at lottiefiles.com.
        let view = LottieAnimationView(name: "splash_animation")
        view.contentMode = .scaleAspectFit

        // loopMode: .playOnce means the animation runs once, then stops.
        // Other options: .loop (repeats forever), .autoReverse (ping-pong).
        view.loopMode = .playOnce

        // Prevents the animation from being interactive (no accidental taps).
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let taglineLabel: UILabel = {
        let label = UILabel()
        label.text = "Burnout. Detected early."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.alpha = 0  // Start invisible — we fade it in with animation
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start after the view is on screen so the animation is visible immediately.
        startAnimation()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(animationView)
        view.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            // Center the animation in the screen, 60% of screen width.
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            animationView.widthAnchor.constraint(equalToConstant: 400),
            animationView.heightAnchor.constraint(equalToConstant: 400),

            taglineLabel.topAnchor.constraint(equalTo: animationView.bottomAnchor, constant: 16),
            taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Animation

    private func startAnimation() {
        // Fade in the tagline regardless of whether Lottie loads.
        UIView.animate(withDuration: 0.6, delay: 0.3, options: .curveEaseIn) {
            self.taglineLabel.alpha = 1
        }

        // `animationView.animation` is nil when the JSON file isn't in the bundle.
        // Guard against this so the app never gets stuck on the splash screen.
        guard animationView.animation != nil else {
            // No JSON file yet — wait 1.5s then proceed to the main app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.onAnimationComplete?()
            }
            return
        }

        // play(completion:) runs the animation once and calls the closure when done.
        // `completed` is true if the animation finished naturally, false if interrupted.
        animationView.play { [weak self] completed in
            guard completed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.onAnimationComplete?()
            }
        }
    }
}
