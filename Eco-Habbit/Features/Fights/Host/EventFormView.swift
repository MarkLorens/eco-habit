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
                    Picker("Type", selection: $draft.type) {
                        ForEach(FightType.allCases) { type in
                            Label(type.name, systemImage: type.symbol).tag(type)
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

        app.saveDraft(draft)
        dismiss()
    }
}
