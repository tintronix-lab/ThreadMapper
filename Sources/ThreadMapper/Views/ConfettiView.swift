import SwiftUI

struct ConfettiView: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var particles: [ConfettiParticle] = []
    @State private var startDate = Date.distantPast

    private static let duration: Double = 2.5

    var body: some View {
        if !reduceMotion && isShowing {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                Canvas { gc, size in
                    let t = ctx.date.timeIntervalSince(startDate)
                    guard t < Self.duration else { return }
                    for p in particles {
                        let pt = max(0.0, t - p.delay)
                        let x = p.x * size.width + p.vx * pt
                        let y = p.y0 + p.vy * pt + 120.0 * pt * pt
                        guard y < size.height + 20 else { continue }
                        let fade = t > Self.duration - 0.7
                            ? max(0.0, (Self.duration - t) / 0.7)
                            : 1.0
                        gc.drawLayer { inner in
                            inner.translateBy(x: x, y: y)
                            inner.rotate(by: .radians(p.rotation + p.spin * pt))
                            inner.fill(
                                Path(CGRect(x: -p.width / 2, y: -p.height / 2,
                                           width: p.width, height: p.height)),
                                with: .color(p.color.opacity(fade))
                            )
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                startDate = Date()
                particles = ConfettiParticle.burst(count: 60)
                Task {
                    try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                    isShowing = false
                }
            }
        }
    }
}

struct ConfettiParticle {
    let x: Double        // normalized 0…1 horizontal start
    let y0: Double       // vertical start in pts (negative = above visible edge)
    let vx: Double       // horizontal drift pts/second
    let vy: Double       // initial downward speed pts/second
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let rotation: Double // initial angle in radians
    let spin: Double     // radians per second
    let delay: Double    // stagger in seconds

    static func burst(count: Int) -> [ConfettiParticle] {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue,
                               .purple, .mint, .pink, .cyan, .teal]
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in
            ConfettiParticle(
                x: Double.random(in: -0.05...1.05, using: &rng),
                y0: Double.random(in: -30...10, using: &rng),
                vx: Double.random(in: -25...25, using: &rng),
                vy: Double.random(in: 50...160, using: &rng),
                width: CGFloat.random(in: 6...10, using: &rng),
                height: CGFloat.random(in: 3...6, using: &rng),
                color: colors.randomElement(using: &rng)!,
                rotation: Double.random(in: 0...(.pi * 2), using: &rng),
                spin: Double.random(in: -6...6, using: &rng),
                delay: Double.random(in: 0...0.4, using: &rng)
            )
        }
    }
}
