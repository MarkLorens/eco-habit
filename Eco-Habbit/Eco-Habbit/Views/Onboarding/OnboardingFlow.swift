import SwiftUI

/// Six steps, first run only. Every choice is held here and committed to `AppState`
/// in one go at the end, so backing out mid-flow leaves nothing half-saved.
struct OnboardingFlow: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var permissions = PermissionsService()

    @State private var step = 0
    @State private var motivations: Set<Motivation> = []
    @State private var categories: Set<ActivityCategory> = []

    var body: some View {
        ZStack {
            switch step {
            case 0: WelcomeStep(name: app.firstName) { advance() }
            case 1: EarthStoryStep { advance() }
            case 2: MotivationStep(selection: $motivations) { advance() }
            case 3: CategoryPickStep(selection: $categories) { advance() }
            case 4: PermissionsStep(permissions: permissions) { advance() }
            default: FirstMissionStep(categories: categories, finish: finish)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .transition(.opacity)
    }

    private func advance() {
        withAnimation { step += 1 }
    }

    private func finish() {
        app.completeOnboarding(
            motivations: motivations,
            categories: categories,
            locationEnabled: permissions.locationGranted,
            cameraEnabled: permissions.cameraGranted
        )
    }
}

// MARK: - Step 0 · Welcome

private struct WelcomeStep: View {
    let name: String
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("ECO HABIT")
                .font(Theme.F.heading(15))
                .tracking(1)
                .foregroundStyle(Theme.C.accent700)

            Spacer()

            GlobeView(health: 82, size: 180, interactive: false)

            VStack(spacing: 12) {
                Text("Welcome, \(name).")
                    .font(Theme.F.heading(30))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.center)

                Text("Every day you'll log a few small sustainable actions. They earn points, the points heal your globe, and the globe is only ever as healthy as your habits.")
                    .font(Theme.F.body(15.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
            }
            .padding(.top, 26)

            Spacer()

            Button("Get Started", action: next)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.C.accent2_100, Theme.C.bg],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.65)
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Step 1 · The Earth story

/// The globe starts thriving and degrades to near-dead while the copy narrates it.
/// Skipping jumps straight to the end state and still shows the summary.
private struct EarthStoryStep: View {
    let next: () -> Void

    @State private var health: Double = 100
    @State private var phase: Phase = .playing

    private enum Phase { case playing, done }

    private let narration = [
        (threshold: 100.0, text: "A century ago, this is what it looked like."),
        (threshold: 72.0, text: "Then the forests started thinning."),
        (threshold: 46.0, text: "The oceans warmed. The rivers ran low."),
        (threshold: 22.0, text: "This is where we are now."),
    ]

    private var currentNarration: String {
        narration.last { health <= $0.threshold }?.text ?? narration[0].text
    }

    var body: some View {
        ZStack {
            Theme.C.neutral900.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if phase == .playing {
                        Button("Skip", action: skip)
                            .font(Theme.F.body(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
                .frame(height: 36)

                Spacer()

                GlobeView(health: health, size: 200, interactive: false)

                Group {
                    if phase == .playing {
                        Text(currentNarration)
                            .font(Theme.F.body(15))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .id(currentNarration)
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 14) {
                            Text("Every small action helps\nrepair what's been lost.")
                                .font(Theme.F.heading(23))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)

                            Text("Log your daily habits and watch the Earth come back to life, one point at a time.")
                                .font(Theme.F.body(14))
                                .foregroundStyle(.white.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 265)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.top, 30)
                .frame(height: 110)

                Spacer()

                if phase == .done {
                    Button("I'm ready to help", action: next)
                        .buttonStyle(PrimaryButtonStyle())
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .task { await play() }
    }

    private func play() async {
        while health > 8, phase == .playing {
            try? await Task.sleep(for: .milliseconds(90))
            guard phase == .playing else { return }
            withAnimation(.linear(duration: 0.09)) {
                health = max(8, health - 4)
            }
        }
        guard phase == .playing else { return }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 0.4)) { phase = .done }
    }

    private func skip() {
        withAnimation(.easeInOut(duration: 0.4)) {
            health = 8
            phase = .done
        }
    }
}

// MARK: - Step 2 · Motivation (multi-select)

private struct MotivationStep: View {
    @Binding var selection: Set<Motivation>
    let next: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What brings you here?",
            subtitle: "Pick everything that applies — you can change this later.",
            primaryTitle: "Continue",
            primaryDisabled: selection.isEmpty,
            primaryAction: next
        ) {
            VStack(spacing: 12) {
                ForEach(Motivation.allCases) { motivation in
                    let isOn = selection.contains(motivation)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if isOn { selection.remove(motivation) } else { selection.insert(motivation) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(isOn ? Theme.C.accent500 : .clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(isOn ? Theme.C.accent500 : Theme.C.neutral300, lineWidth: 2)
                                    )
                                    .frame(width: 22, height: 22)
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(motivation.label)
                                .font(Theme.F.body(16, weight: .semibold))
                                .foregroundStyle(Theme.C.text)

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.R.lg)
                                .fill(isOn ? Theme.C.accent100 : .white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.R.lg)
                                        .stroke(isOn ? Theme.C.accent500 : Theme.C.neutral200, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainPressStyle())
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Step 3 · Favourite categories (2–3)

private struct CategoryPickStep: View {
    @Binding var selection: Set<ActivityCategory>
    let next: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        OnboardingScaffold(
            title: "Pick 2–3 favorites",
            subtitle: "We'll surface missions from these categories first.",
            footnote: "\(selection.count) of 3 selected",
            primaryTitle: "Continue",
            primaryDisabled: selection.count < 2,
            primaryAction: next
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ActivityCategory.allCases) { category in
                    let isOn = selection.contains(category)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { toggle(category) }
                    } label: {
                        VStack(spacing: 8) {
                            CategoryIconView(
                                glyph: category.glyph,
                                size: 28,
                                color: isOn ? Theme.C.accent600 : Theme.C.neutral600
                            )
                            Text(category.name)
                                .font(Theme.F.body(13, weight: .semibold))
                                .foregroundStyle(Theme.C.text)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.R.lg)
                                .fill(isOn ? Theme.C.accent100 : .white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.R.lg)
                                        .stroke(isOn ? Theme.C.accent500 : Theme.C.neutral200, lineWidth: 2)
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            if isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Theme.C.accent500))
                                    .padding(8)
                            }
                        }
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func toggle(_ category: ActivityCategory) {
        if selection.contains(category) {
            selection.remove(category)
        } else if selection.count < 3 {
            selection.insert(category)
        }
    }
}

// MARK: - Step 4 · Permissions

private struct PermissionsStep: View {
    @ObservedObject var permissions: PermissionsService
    let next: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingScaffold(
            title: "Enable the essentials",
            subtitle: "Both are optional — you can always turn these on later.",
            primaryTitle: isRequesting ? "Asking…" : "Allow & Continue",
            primaryDisabled: isRequesting,
            primaryAction: request,
            secondaryTitle: "Skip for now",
            secondaryAction: next
        ) {
            VStack(spacing: 14) {
                PermissionCard(
                    glyph: "mappin.and.ellipse",
                    tint: Theme.C.accent2_700,
                    background: Theme.C.accent2_100,
                    title: "Location",
                    detail: "Lets us surface regional missions and events happening near you.",
                    granted: permissions.locationGranted
                )
                PermissionCard(
                    glyph: "camera.fill",
                    tint: Theme.C.accent700,
                    background: Theme.C.accent100,
                    title: "Camera",
                    detail: "Needed to snap photos of your actions so we can detect and reward them.",
                    granted: permissions.cameraGranted
                )
                Spacer(minLength: 0)
            }
        }
    }

    private func request() {
        isRequesting = true
        Task {
            _ = await permissions.requestCamera()
            _ = await permissions.requestLocation()
            isRequesting = false
            next()
        }
    }
}

private struct PermissionCard: View {
    let glyph: String
    let tint: Color
    let background: Color
    let title: String
    let detail: String
    let granted: Bool

    var body: some View {
        EHCard(padding: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: glyph)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(background))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(Theme.F.body(16, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        if granted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.C.accent2_600)
                        }
                    }
                    Text(detail)
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Step 5 · First mission

private struct FirstMissionStep: View {
    let categories: Set<ActivityCategory>
    let finish: () -> Void

    private var firstMission: Activity {
        MockData.activities.first { categories.contains($0.category) } ?? MockData.activities[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Your Earth needs you")
                .font(Theme.F.heading(25))
                .foregroundStyle(Theme.C.text)

            GlobeView(health: 8, size: 160, interactive: false)
                .padding(.top, 18)

            Text("Current health: 8% — let's change that.")
                .font(Theme.F.body(13.5))
                .foregroundStyle(Theme.C.neutral600)
                .padding(.top, 12)

            EHCard(padding: 16) {
                HStack(spacing: 12) {
                    CategoryIconView(glyph: firstMission.category.glyph, size: 24, color: Theme.C.accent600)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(firstMission.name)
                            .font(Theme.F.body(15, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        Text("Your first mission")
                            .font(Theme.F.body(13))
                            .foregroundStyle(Theme.C.neutral600)
                    }
                    Spacer()
                    EHTag(text: "+\(firstMission.basePoints) pts", style: .accent)
                }
            }
            .padding(.top, 24)

            Spacer()

            Button("Start My First Mission", action: finish)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.C.neutral200, Theme.C.bg],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.55)
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Shared step chrome

private struct OnboardingScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var footnote: String?
    let primaryTitle: String
    var primaryDisabled: Bool = false
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Theme.F.heading(26))
                .foregroundStyle(Theme.C.text)

            Text(subtitle)
                .font(Theme.F.body(14.5))
                .foregroundStyle(Theme.C.neutral700)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 0) { content }
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            if let footnote {
                Text(footnote)
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(primaryDisabled)
                .padding(.top, footnote == nil ? 16 : 0)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.C.bg.ignoresSafeArea())
    }
}

#Preview {
    OnboardingFlow().environmentObject(AppState(data: {
        var s = PersistedState()
        s.isLoggedIn = true
        s.userName = MockData.demoName
        return s
    }()))
}
