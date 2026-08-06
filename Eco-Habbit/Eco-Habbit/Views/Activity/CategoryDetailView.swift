import PhotosUI
import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let category: ActivityCategory

    /// The activity waiting on a photo, and how that photo will be used.
    @State private var evidenceTarget: EvidenceTarget?
    @State private var showingSourceDialog = false
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var showingLibrary = false

    private struct EvidenceTarget: Identifiable {
        let activity: Activity
        /// True when the activity isn't logged yet, so the photo comes with the credit.
        let logsAtSameTime: Bool
        var id: String { activity.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                EHCard(padding: 4) {
                    VStack(spacing: 0) {
                        let rows = app.rows(in: category)
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            ActivityRowView(
                                row: row,
                                previewPoints: PointsEngine.preview(
                                    basePoints: row.activity.basePoints,
                                    streakDays: app.streakDays
                                ),
                                onToggle: { toggle(row) },
                                onEvidence: { requestEvidence(for: row) }
                            )

                            if index < rows.count - 1 {
                                Rectangle()
                                    .fill(Theme.C.neutral200)
                                    .frame(height: 1)
                                    .padding(.horizontal, 10)
                            }
                        }
                    }
                }
                .padding(.top, 18)

                footnote
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Theme.C.bg)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Add evidence",
            isPresented: $showingSourceDialog,
            titleVisibility: .visible
        ) {
            if ImagePicker.isCameraAvailable {
                Button("Take a photo") { showingCamera = true }
            }
            Button("Choose from library") { showingLibrary = true }
            Button("Cancel", role: .cancel) { evidenceTarget = nil }
        } message: {
            Text("A photo earns a +\(Int(PointsEngine.evidenceBonusRate * 100))% bonus on this activity.")
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                handlePicked(image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handlePicked(image)
                }
                libraryItem = nil
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "chevron.left") { dismiss() }

            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(Theme.F.heading(20))
                    .foregroundStyle(Theme.C.text)
                Text(category.blurb)
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral600)
            }

            Spacer()
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "Completed activities lock until tomorrow.",
                systemImage: "clock.arrow.circlepath"
            )
            if app.streakMultiplier > 1 {
                Label(
                    "Your \(app.streakDays)-day streak is multiplying every point by ×\(PointsEngine.multiplierLabel(app.streakMultiplier)).",
                    systemImage: "flame.fill"
                )
            }
        }
        .font(Theme.F.body(12.5))
        .foregroundStyle(Theme.C.neutral600)
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }

    // MARK: Actions

    private func toggle(_ row: ActivityRow) {
        guard !row.isCompletedToday else {
            app.toast = Toast(kind: .info, message: "Already logged today — back tomorrow.")
            return
        }
        switch app.logActivity(row.activity, source: .checklist) {
        case .awarded(let award):
            app.toast = Toast(kind: .success, message: "+\(award.points) pts · \(award.activity.name)")
        case .alreadyDoneToday:
            app.toast = Toast(kind: .info, message: "Already logged today — back tomorrow.")
        }
    }

    private func requestEvidence(for row: ActivityRow) {
        evidenceTarget = EvidenceTarget(
            activity: row.activity,
            logsAtSameTime: !row.isCompletedToday
        )
        showingSourceDialog = true
    }

    private func handlePicked(_ image: UIImage) {
        guard let target = evidenceTarget else { return }
        evidenceTarget = nil

        if target.logsAtSameTime {
            switch app.logActivity(target.activity, source: .checklist, evidenceImage: image) {
            case .awarded(let award):
                app.toast = Toast(
                    kind: .success,
                    message: "+\(award.points) pts with evidence · \(award.activity.name)"
                )
            case .alreadyDoneToday:
                _ = app.attachEvidence(image, to: target.activity)
            }
        } else {
            _ = app.attachEvidence(image, to: target.activity)
        }
    }
}

// MARK: - Row

private struct ActivityRowView: View {
    let row: ActivityRow
    let previewPoints: Int
    let onToggle: () -> Void
    let onEvidence: () -> Void

    private var isDone: Bool { row.isCompletedToday }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isDone ? Theme.C.accent500 : .clear)
                        .overlay(
                            Circle().stroke(
                                isDone ? Theme.C.accent500 : Theme.C.neutral300,
                                lineWidth: 2
                            )
                        )
                        .frame(width: 28, height: 28)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(PlainPressStyle())
            .disabled(isDone)
            .accessibilityLabel(isDone ? "\(row.activity.name), completed today" : "Mark \(row.activity.name) as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(row.activity.name)
                    .font(Theme.F.body(15, weight: .semibold))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if row.hasEvidence {
                    Label("Evidence added", systemImage: "checkmark.seal.fill")
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.accent2_700)
                } else {
                    Button(action: onEvidence) {
                        Text(isDone ? "+ Add evidence for a bonus" : "+ Add evidence (optional)")
                            .font(Theme.F.body(12.5))
                            .foregroundStyle(Theme.C.accent700)
                    }
                    .buttonStyle(PlainPressStyle())
                }

                if row.activity.isCameraDetectable, !isDone {
                    Label("Camera can detect this", systemImage: "camera.viewfinder")
                        .font(Theme.F.body(11.5))
                        .foregroundStyle(Theme.C.neutral500)
                }
            }

            Spacer(minLength: 4)

            EHTag(
                text: isDone ? "+\(row.completion?.pointsAwarded ?? previewPoints) pts" : "+\(previewPoints) pts",
                style: isDone ? .accent2 : .neutral
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .opacity(isDone ? 0.62 : 1)
        .animation(.easeOut(duration: 0.2), value: isDone)
    }
}
