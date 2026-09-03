import SwiftUI

struct SparklineView: View {
    let dataPoints: [CGFloat]
    let lineWidth: CGFloat
    let lineColor: Color
    let fillColor: Color

    init(
        dataPoints: [CGFloat],
        lineWidth: CGFloat = 1.5,
        lineColor: Color = .barTabPrimary,
        fillColor: Color = .barTabPrimary.opacity(0.1)
    ) {
        self.dataPoints = dataPoints
        self.lineWidth = lineWidth
        self.lineColor = lineColor
        self.fillColor = fillColor
    }

    var body: some View {
        GeometryReader { geometry in
            if dataPoints.count >= 2 {
                let minVal = dataPoints.min() ?? 0
                let maxVal = dataPoints.max() ?? 1
                let range = maxVal - minVal
                let normalized = dataPoints.map { point in
                    range > 0 ? (point - minVal) / range : 0.5
                }

                let stepX = geometry.size.width / CGFloat(normalized.count - 1)
                let height = geometry.size.height

                Path { path in
                    for (index, point) in normalized.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (point * height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, lineWidth: lineWidth)

                Path { path in
                    let stepX = geometry.size.width / CGFloat(normalized.count - 1)
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: 0, y: height))
                    for (index, point) in normalized.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (point * height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: CGFloat(normalized.count - 1) * stepX, y: height))
                    path.closeSubpath()
                }
                .fill(fillColor)
            }
        }
    }
}
