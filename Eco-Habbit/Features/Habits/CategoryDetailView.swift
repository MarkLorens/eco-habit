import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let category: HabitCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                EHCard(padding: 4) {
                    VStack(spacing: 0) {
                        let rows = app.rows(in: category)
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            HabitRowView(row: row, onToggle: { toggle(row) })

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
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Theme.C.bg)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

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

    private func toggle(_ row: HabitRow) {
        // Same-day undo (PRD §3.4) — tapping a completed row takes it back.
        if row.isCompletedToday {
            app.revertTodaysLog(habitId: row.habit.id)
            app.toast = Toast(kind: .info, message: "Removed \(row.habit.name).")
        } else {
            app.logAndToast(row.habit, source: .checklist)
        }
    }
}

private struct HabitRowView: View {
    let row: HabitRow
    let onToggle: () -> Void

    private var isDone: Bool { row.isCompletedToday }
    private var points: Int { PointsEngine.tierPoints(row.habit.tier) }

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
            .accessibilityLabel(isDone ? "\(row.habit.name), completed today" : "Mark \(row.habit.name) as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(row.habit.name)
                    .font(Theme.F.body(15, weight: .semibold))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if row.habit.isCameraDetectable, !isDone {
                    Label("Camera can detect this", systemImage: "camera.viewfinder")
                        .font(Theme.F.body(11.5))
                        .foregroundStyle(Theme.C.neutral500)
                }
            }

            Spacer(minLength: 4)

            EHTag(text: "+\(points) pts", style: isDone ? .accent2 : .neutral)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .opacity(isDone ? 0.62 : 1)
        .animation(.easeOut(duration: 0.2), value: isDone)
    }
}
