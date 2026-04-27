//
//  SparklineView.swift
//  Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//

import UIKit
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
