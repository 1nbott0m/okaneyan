import SwiftUI

/// Brand intro and readiness-driven orbit loop shown over the mounted finance root.
/// App entry waits for the root and a smooth satellite dock.
struct OkaneyanCinematicIntro: View {
    let isContentReady: Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var startedAt = Date()
    @State private var isLeaving = false
    @State private var didRequestFinish = false
    @State private var skipRequested = false
    @State private var contentReadyAt: Date?
    @State private var loadingPhaseAtReady = 0.0

    private let motionDuration = 2.90
    private let loadingOrbitDuration = 5.0
    private let transitionDuration: UInt64 = 380_000_000

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion || (skipRequested && !isContentReady) || isLeaving)) { timeline in
            let rawElapsed = (reduceMotion || skipRequested) ? motionDuration : max(0, timeline.date.timeIntervalSince(startedAt))
            let elapsed = min(motionDuration, rawElapsed)
            let settleStart = max(startedAt.addingTimeInterval(motionDuration), contentReadyAt ?? .distantFuture)
            let settleDuration = dockSettleDuration(phase: loadingPhaseAtReady, loopDuration: loadingOrbitDuration)
            let waitedForReadiness = (contentReadyAt ?? .distantFuture) >= startedAt.addingTimeInterval(motionDuration)
            let dockProgress = isContentReady && rawElapsed >= motionDuration
                ? (waitedForReadiness ? smooth(timeline.date.timeIntervalSince(settleStart) / settleDuration) : 1) : 0
            let entryReady = isContentReady && (reduceMotion || skipRequested || (rawElapsed >= motionDuration && dockProgress >= 1))
            GeometryReader { proxy in
                let markSize = min(proxy.size.width * 0.66, 288)
                ZStack {
                    backdrop
                    VStack(spacing: 15) {
                        OkaneyanCinematicMark(
                            elapsed: elapsed,
                            waitingElapsed: max(0, rawElapsed - motionDuration),
                            isContentReady: isContentReady,
                            phaseAtReady: loadingPhaseAtReady,
                            dockProgress: dockProgress,
                            reduced: reduceMotion,
                            loadingOrbitDuration: loadingOrbitDuration,
                            size: markSize
                        )
                            .frame(width: markSize, height: markSize)
                        brandLockup(elapsed: elapsed)
                    }
                    .scaleEffect(cameraScale(elapsed))
                    .offset(y: 2 * (1 - smooth(elapsed / motionDuration)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("okaneyan. запускается")
                    .accessibilityAction(named: Text("Пропустить анимацию")) { skipRequested = true }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(backgroundColor.ignoresSafeArea())
                .opacity(isLeaving ? 0 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.38), value: isLeaving)
                .onAppear {
                    startedAt = timeline.date
                    if isContentReady { contentReadyAt = timeline.date }
                }
                .onChange(of: isContentReady) { _, ready in
                    if ready {
                        let readyAt = Date()
                        let waited = max(0, readyAt.timeIntervalSince(startedAt) - motionDuration)
                        contentReadyAt = readyAt
                        loadingPhaseAtReady = (waited / loadingOrbitDuration).truncatingRemainder(dividingBy: 1)
                    } else {
                        contentReadyAt = nil
                        loadingPhaseAtReady = 0
                    }
                }
                .task(id: entryReady) {
                    guard entryReady, !didRequestFinish else { return }
                    didRequestFinish = true
                    isLeaving = true
                    if !reduceMotion { try? await Task.sleep(nanoseconds: transitionDuration) }
                    onFinish()
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.055, green: 0.052, blue: 0.066) : Color(red: 0.965, green: 0.946, blue: 0.954)
    }

    private var backdrop: some View {
        backgroundColor.accessibilityHidden(true)
    }

    @ViewBuilder
    private func brandLockup(elapsed: Double) -> some View {
        let reveal = smooth((elapsed - 0.82) / 0.46)
        VStack(spacing: 5) {
            (Text("okaneyan") + Text(".").foregroundColor(rose))
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(ink)
            Text("PERSONAL FINANCE")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(secondaryInk)
        }
        .opacity(reveal)
        .offset(y: 4 * (1 - reveal))
        .accessibilityHidden(true)
    }

    private var ink: Color { colorScheme == .dark ? Color(red: 0.97, green: 0.94, blue: 0.96) : Color(red: 0.16, green: 0.13, blue: 0.16) }
    private var secondaryInk: Color { colorScheme == .dark ? Color(red: 0.68, green: 0.62, blue: 0.68) : Color(red: 0.42, green: 0.36, blue: 0.42) }
    private var rose: Color { Color(red: 0.91, green: 0.57, blue: 0.70) }

    private func cameraScale(_ elapsed: Double) -> CGFloat {
        0.985 + 0.015 * smooth(elapsed / motionDuration)
    }
}

private struct OkaneyanCinematicMark: View {
    let elapsed: Double
    let waitingElapsed: Double
    let isContentReady: Bool
    let phaseAtReady: Double
    let dockProgress: Double
    let reduced: Bool
    let loadingOrbitDuration: Double
    let size: CGFloat

    private let orbitStart = 0.24
    private let orbitEnd = 2.60
    private let dotStart = 0.70
    private let dockAt = 2.90

    private var spin: Double { reduced ? 1 : smooth(elapsed / dockAt) }
    private var orbitProgress: Double { reduced ? 1 : smooth((elapsed - orbitStart) / (orbitEnd - orbitStart)) }
    private var dotProgress: Double { reduced ? 1 : smooth((elapsed - dotStart) / (dockAt - dotStart)) }
    private var satelliteAngle: Double {
        if elapsed < dockAt {
            return (-45.0 + 300.0 * (0.94 * (1 - dotProgress))) * .pi / 180
        }
        if reduced { return -45 * .pi / 180 }

        let phase = isContentReady
            ? phaseAtReady
            : (waitingElapsed / loadingOrbitDuration).truncatingRemainder(dividingBy: 1)
        let remaining = phase > 0.0001 ? 1 - phase : 0
        let dockEase = matchedDockEase(dockProgress, phase: phase, loopDuration: loadingOrbitDuration)
        return (-45 - 360 * (phase + remaining * dockEase)) * .pi / 180
    }

    var body: some View {
        let center = size / 2
        let radius = size * 0.34375
        let satelliteX = center + radius * CGFloat(cos(satelliteAngle))
        let satelliteY = center + radius * CGFloat(sin(satelliteAngle))

        ZStack {
            if waitingElapsed > 0, !isContentReady, !reduced {
                OkaneyanOrbitGap()
                    .stroke(Color(red: 0.62, green: 0.59, blue: 0.63).opacity(0.24),
                            style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
            }

            OkaneyanOrbitArc(progress: CGFloat(orbitProgress))
                .stroke(Color(red: 0.62, green: 0.59, blue: 0.63).opacity(0.82), style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round, lineJoin: .round))

            metallicO
                .frame(width: size * 0.254, height: size * 0.254)
                .rotation3DEffect(.degrees(360 * spin), axis: (x: 0.18, y: 1, z: 0.035), perspective: 0.48)
                .scaleEffect(0.965 + 0.035 * smooth(elapsed / 0.34))
                .opacity(smooth(elapsed / 0.26))

            satellite
                .frame(width: size * 0.094, height: size * 0.094)
                .position(x: satelliteX, y: satelliteY)
                .opacity(reduced ? 1 : smooth((elapsed - dotStart) / 0.22))
                .shadow(color: .black.opacity(0.20), radius: 2, x: 0, y: 1)

        }
        .frame(width: size, height: size)
        .scaleEffect(0.985 + 0.015 * smooth(elapsed / dockAt))
        .accessibilityHidden(true)
    }

    private var metallicO: some View {
        return ZStack {
            Circle()
                .stroke(orbitMetal, lineWidth: size * 0.045)
        }
    }

    private var orbitMetal: AngularGradient {
        AngularGradient(colors: [Color(red: 0.43, green: 0.40, blue: 0.44),
                                 Color(red: 0.83, green: 0.80, blue: 0.83),
                                 Color(red: 0.54, green: 0.51, blue: 0.56),
                                 Color(red: 0.70, green: 0.67, blue: 0.71),
                                 Color(red: 0.43, green: 0.40, blue: 0.44)],
                        center: .center,
                        startAngle: .degrees(-100),
                        endAngle: .degrees(260))
    }

    private var satellite: some View {
        ZStack {
            Circle().fill(Color(red: 0.84, green: 0.68, blue: 0.74))
            Circle()
                .fill(.white.opacity(0.58))
                .frame(width: max(1, size * 0.012), height: max(1, size * 0.012))
                .offset(x: -size * 0.021, y: -size * 0.021)
        }
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
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.34375
        let end = -45 + 300 * Double(min(1, max(0, progress)))
        path.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(end), clockwise: false)
        return path
    }
}

private struct OkaneyanOrbitGap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.34375
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-105), endAngle: .degrees(-45), clockwise: false)
        return path
    }
}

private func dockSettleDuration(phase: Double, loopDuration: Double) -> Double {
    let remaining = phase > 0.0001 ? 1 - phase : 0
    let travelDuration = remaining * loopDuration
    if travelDuration == 0 { return 0.38 }
    if travelDuration < 0.12 { return travelDuration }
    return min(1.4, max(0.25, travelDuration * 0.35))
}

private func matchedDockEase(_ progress: Double, phase: Double, loopDuration: Double) -> Double {
    let remaining = phase > 0.0001 ? 1 - phase : 0
    guard remaining > 0 else { return 1 }
    let duration = dockSettleDuration(phase: phase, loopDuration: loopDuration)
    let k = min(1, duration / (remaining * loopDuration))
    let p = min(1, max(0, progress))
    return min(1, max(0, k * p + (3 - 2 * k) * p * p + (k - 2) * p * p * p))
}

private func smooth(_ value: Double) -> Double {
    let q = min(1, max(0, value))
    return q * q * q * (q * (q * 6 - 15) + 10)
}
