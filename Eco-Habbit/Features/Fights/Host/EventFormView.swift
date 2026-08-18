import SwiftUI

/// PRD §6.5.1 — create or edit a Fight.
///
/// Saves as a **draft**. Publishing is a separate, explicit act from Manage, so
/// a half-written event never reaches the public list.
struct EventFormView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Fight
    private let isNew: Bool

    init(editing fight: Fight? = nil, app: AppState) {
        _draft = State(initialValue: fight ?? app.newDraft())
        isNew = fight == nil
    }

    /// Free text, one note per line — a repeating field with add/remove buttons
    /// is a lot of UI for something a host types once.
    @State private var notesText = ""

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.locationName.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.endsAt > draft.startsAt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Title", text: $draft.title)
                    Picker("Category", selection: $draft.category) {
                        ForEach(Category.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    TextField("Short description", text: $draft.summary, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("When") {
                    DatePicker("Starts", selection: $draft.startsAt)
                    DatePicker("Ends", selection: $draft.endsAt, in: draft.startsAt...)
                    if draft.endsAt <= draft.startsAt {
                        Label("The end has to come after the start.", systemImage: "exclamationmark.triangle")
                            .font(Theme.F.body(12.5))
                            .foregroundStyle(Theme.C.accent600)
                    }
                }

                Section {
                    TextField("Location name", text: $draft.locationName)
                    TextField("Address", text: $draft.address, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Where")
                } footer: {
                    // PRD §6.5.1 — free text, no autocomplete. Address lookup is a
                    // Places API dependency and a cost centre; the map pin that
                    // would fill in lat/lng is a v2 concern (§4.7).
                    Text("Typed by hand. There is no address lookup in v1.")
                }

                Section {
                    TextField("One per line", text: $notesText, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("What to bring")
                } footer: {
                    Text("Shown as a list on the Fight detail screen.")
                }

                Section {
                    Picker("Scale", selection: $draft.tier) {
                        ForEach(EventTier.allCases, id: \.self) { tier in
                            Text("\(tier.displayName) · \(tier.points) pts").tag(tier)
                        }
                    }
                } header: {
                    Text("Reward")
                } footer: {
                    Text("Micro is under an hour, Major is a full day. Points count against each attendee's monthly quota.")
                }

                Section {
                    // A fixed list, not free text: an organiser typing their own
                    // badge name gives every user a junk drawer of one-off
                    // trophies nobody can vouch for.
                    Picker("Badge", selection: $draft.rewardBadgeId) {
                        Text("None").tag(String?.none)
                        ForEach(MockBadgeData.fightRewards) { badge in
                            Text(badge.name).tag(String?.some(badge.id))
                        }
                    }
                    if let id = draft.rewardBadgeId,
                       let badge = MockBadgeData.fightReward(withID: id) {
                        Text(badge.description)
                            .font(Theme.F.body(12.5))
                            .foregroundStyle(Theme.C.neutral600)
                    }
                } footer: {
                    Text("Awarded once, to everyone who checks in. Optional — points alone are a fine reward.")
                }

                Section {
                    LabeledContent("Check-in code") {
                        Text(draft.checkInCode)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                } footer: {
                    Text("Show this at the venue. Everyone attending scans or types the same code.")
                }

                if isNew {
                    Section {
                        Text("Saves as a draft. You publish it from Manage when it's ready.")
                            .font(Theme.F.body(12.5))
                            .foregroundStyle(Theme.C.neutral600)
                    }
                }
            }
            .navigationTitle(isNew ? "New Fight" : "Edit Fight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .onAppear { notesText = draft.preparationNotes.joined(separator: "\n") }
        }
    }

    private func save() {
        draft.preparationNotes = notesText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task { await app.saveDraft(draft) }
        dismiss()
    }
}
