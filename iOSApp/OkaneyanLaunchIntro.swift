import SwiftUI

/// Presents the Orbit O launch animation until the host app is ready.
///
/// The opening choreography plays once. If the host is still loading when it ends,
/// the satellite continues around the orbit. Setting `isAppReady` to `true` calls
/// `onComplete` immediately; the component never adds a loading delay.
@MainActor
public struct OkaneyanLaunchIntro: View {
    private let isAppReady: Bool
    private let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var startedAt = Date()
    @State private var skipAnimation = false
    @State private var didComplete = false

    private let introDuration = 3.25
    private let orbitLoopDuration = 5.0

    /// Creates the launch animation.
    /// - Parameters:
    ///   - isAppReady: Set to `true` when the host has a usable first screen.
    ///   - onComplete: Called once, immediately when the host reports readiness.
    public init(isAppReady: Bool, onComplete: @escaping () -> Void) {
        self.isAppReady = isAppReady
        self.onComplete = onComplete
    }

    public var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 60.0,
            paused: isAppReady || reduceMotion || skipAnimation || didComplete
        )) { timeline in
            let isSettled = isAppReady || reduceMotion || skipAnimation
            let rawElapsed = isSettled
                ? introDuration
                : max(0, timeline.date.timeIntervalSince(startedAt))
            let elapsed = min(introDuration, rawElapsed)

            GeometryReader { proxy in
                let markSize = min(proxy.size.width * 0.66, 288)

                VStack(spacing: 15) {
                    OkaneyanOrbitMark(
                        elapsed: elapsed,
                        waitingElapsed: max(0, rawElapsed - introDuration),
                        isLoading: !isSettled && rawElapsed >= introDuration,
                        size: markSize
                    )
                    .frame(width: markSize, height: markSize)

                    wordmark(elapsed: elapsed, isSettled: isSettled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(pageColor.ignoresSafeArea())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("okaneyan. запускается")
                .accessibilityAction(named: Text("Завершить анимацию")) {
                    skipAnimation = true
                }
                .onAppear {
                    startedAt = timeline.date
                }
                .task(id: isAppReady) {
                    guard isAppReady, !didComplete else { return }
                    didComplete = true
                    onComplete()
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func wordmark(elapsed: Double, isSettled: Bool) -> some View {
        let reveal = isSettled ? 1 : smooth((elapsed - 0.82) / 0.46)

        VStack(spacing: 5) {
            (Text("okaneyan") + Text(".").foregroundColor(rose))
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(primaryInk)

            Text("PERSONAL FINANCE")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(secondaryInk)
        }
        .opacity(reveal)
        .accessibilityHidden(true)
    }

    private var pageColor: Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.052, blue: 0.066)
            : Color(red: 0.965, green: 0.946, blue: 0.954)
    }

    private var primaryInk: Color {
        colorScheme == .dark
            ? Color(red: 0.94, green: 0.92, blue: 0.94)
            : Color(red: 0.16, green: 0.13, blue: 0.16)
    }

    private var secondaryInk: Color {
        colorScheme == .dark
            ? Color(red: 0.68, green: 0.64, blue: 0.68)
            : Color(red: 0.42, green: 0.36, blue: 0.42)
    }

    private var rose: Color { Color(red: 0.85, green: 0.64, blue: 0.71) }
}

private struct OkaneyanOrbitMark: View {
    let elapsed: Double
    let waitingElapsed: Double
    let isLoading: Bool
    let size: CGFloat

    private let orbitStart = 0.24
    private let orbitEnd = 2.60
    private let satelliteStart = 0.70
    private let dockAt = 2.90
    private let orbitLoopDuration = 5.0

    private var orbitProgress: Double {
        smooth((elapsed - orbitStart) / (orbitEnd - orbitStart))
    }

    private var satelliteProgress: Double {
        smooth((elapsed - satelliteStart) / (dockAt - satelliteStart))
    }

    private var satelliteAngle: Double {
        if isLoading {
            let phase = (waitingElapsed / orbitLoopDuration).truncatingRemainder(dividingBy: 1)
            return (-45 - 360 * phase) * .pi / 180
        }
        return (-45 + 300 * (0.94 * (1 - satelliteProgress))) * .pi / 180
    }

    var body: some View {
        let center = size / 2
        let radius = size * (176.0 / 512.0)

        let satelliteX = center + radius * CGFloat(cos(satelliteAngle))
        let satelliteY = center + radius * CGFloat(sin(satelliteAngle))

        ZStack {
            if isLoading {
                OkaneyanOrbitGap()
                    .stroke(orbitColor.opacity(0.24), style: orbitStyle)
            }

            OkaneyanOrbitArc(progress: CGFloat(orbitProgress))
                .stroke(orbitColor, style: orbitStyle)

            Circle()
                .stroke(letterMetal, lineWidth: size * (35.0 / 512.0))
                .frame(width: size * (130.0 / 512.0), height: size * (130.0 / 512.0))
                .rotation3DEffect(
                    .degrees(360 * smooth(elapsed / dockAt)),
                    axis: (x: 0.18, y: 1, z: 0.035),
                    perspective: 0.55
                )
                .opacity(smooth(elapsed / 0.26))

            satellite
                .position(x: satelliteX, y: satelliteY)
                .opacity(smooth((elapsed - satelliteStart) / 0.22))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var satellite: some View {
        let diameter = size * (34.0 / 512.0)

        return ZStack(alignment: .topLeading) {
            Circle().fill(rose)
            Circle()
                .fill(.white.opacity(0.58))
                .frame(width: size * (5.6 / 512.0), height: size * (5.6 / 512.0))
                .offset(x: size * (7.0 / 512.0), y: size * (7.0 / 512.0))
        }
        .frame(width: diameter, height: diameter)
    }

    private var orbitStyle: StrokeStyle {
        StrokeStyle(lineWidth: size * (5.0 / 512.0), lineCap: .round, lineJoin: .round)
    }

    private var orbitColor: Color { Color(red: 0.47, green: 0.46, blue: 0.49) }
    private var rose: Color { Color(red: 0.85, green: 0.64, blue: 0.71) }

    private var letterMetal: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.82, green: 0.81, blue: 0.83),
                Color(red: 0.47, green: 0.46, blue: 0.49),
                Color(red: 0.67, green: 0.66, blue: 0.69),
                Color(red: 0.82, green: 0.81, blue: 0.83)
            ],
            center: .center,
            startAngle: .degrees(-100),
            endAngle: .degrees(260)
        )
    }
}

private struct OkaneyanOrbitArc: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0 else { return path }

        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) * (176.0 / 512.0),
            startAngle: .degrees(-45),
            endAngle: .degrees(-45 + 300 * Double(min(1, max(0, progress)))),
            clockwise: false
        )
        return path
    }
}

private struct OkaneyanOrbitGap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) * (176.0 / 512.0),
            startAngle: .degrees(-105),
            endAngle: .degrees(-45),
            clockwise: false
        )
        return path
    }
}

private func smooth(_ value: Double) -> Double {
    let t = min(1, max(0, value))
    return t * t * t * (t * (t * 6 - 15) + 10)
}
