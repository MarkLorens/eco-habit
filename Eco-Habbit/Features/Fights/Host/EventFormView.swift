import SwiftUI
import PhotosUI

/// Add / Edit Our Fights — the organiser's form, built to the hi-fi.
///
/// One screen for both, because the fields are identical and only the title differs.
/// Rows are label-left, value-right; **Done** commits and closes.
///
/// **Status is a switch here, not a workflow.** Off is a draft — invisible to everyone
/// but its host, which the security rules enforce, not just the UI. Turning it on asks
/// first, because it is the moment the event becomes public. Off again returns it to a
/// draft rather than cancelling: cancelling is a different promise, and the hi-fi has no
/// control for it.
struct EventFormView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Fight
    @State private var isEnabled: Bool
    @State private var confirmingEnable = false
    @State private var pickedPhoto: PhotosPickerItem?
    /// Set when a chosen photo will not fit the document even at lowest quality.
    @State private var photoError = false
    private let isNew: Bool

    init(editing fight: Fight? = nil, app: AppState) {
        let seed = fight ?? app.newDraft()
        _draft = State(initialValue: seed)
        _isEnabled = State(initialValue: seed.status == .published)
        isNew = fight == nil
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                        heading
                        card
                    }
                    .padding(.horizontal, Tokens.Spacing.xl)
                    .padding(.top, Tokens.Spacing.md)
                }

                // The hi-fi's Done is the same dark rounded rectangle as "See QR Code",
                // which is what the rest of these screens use.
                Button { save() } label: {
                    Text("Done")
                        .textStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Semantic.ourFightQR)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Tokens.Semantic.text)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
                .padding(.horizontal, Tokens.Spacing.xl)
                .padding(.bottom, Tokens.Spacing.lg)
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.Semantic.text)
                    }
                }
            }
            // Downscaled and re-encoded here rather than at save: an organiser should
            // find out immediately that a photo will not fit, not after tapping Done.
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    if let encoded = FightImage.encode(image) {
                        draft.imageData = encoded
                    } else {
                        photoError = true
                    }
                }
            }
            .alert("That image is too large", isPresented: $photoError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A Fight's photo travels inside the event itself, so it has to stay small. Try a different one.")
            }
            .alert("Enable Event ?", isPresented: $confirmingEnable) {
                Button("Cancel", role: .cancel) { isEnabled = false }
                Button("Enable") { isEnabled = true }
            } message: {
                Text("Event will be shown to all users after clicking enable")
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(isNew ? "Add Our Fights" : "Edit Our Fights")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)
            Text("Take action together for a greener tomorrow")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
    }

    // MARK: - The form

    private var card: some View {
        VStack(spacing: 0) {
            row("Title") {
                TextField("Our Fights", text: $draft.title)
                    .multilineTextAlignment(.trailing)
            }
            row("Caption") {
                TextField("Description", text: $draft.summary, axis: .vertical)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
            }
            row("Category") {
                Picker("", selection: $draft.category) {
                    ForEach(HabitCategory.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .tint(Tokens.Semantic.text)
            }
            row("Date") {
                // The hi-fi shows two chips, which is exactly what a compact DatePicker
                // renders. `endsAt` has no field: it follows the start, as `newDraft`
                // already assumes, so a host never has to reason about it.
                DatePicker("", selection: $draft.startsAt)
                    .labelsHidden()
                    .onChange(of: draft.startsAt) { _, start in
                        draft.endsAt = start.addingTimeInterval(3 * 3600)
                    }
            }
            row("Location") {
                TextField("Description", text: $draft.locationName)
                    .multilineTextAlignment(.trailing)
            }
            row("Link") {
                // What "More info" on the card opens. Free text — `Fight.infoURL`
                // adds the scheme and refuses anything without a host, so a typo
                // costs a hidden button rather than a dead one.
                TextField("instagram.com/…", text: Binding(
                    get: { draft.link ?? "" },
                    set: { draft.link = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .multilineTextAlignment(.trailing)
            }
            row("Picture") {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    HStack(spacing: Tokens.Spacing.sm) {
                        if let image = FightImage.decode(draft.imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Text(draft.imageData == nil ? "Add Image…" : "Change")
                            .foregroundStyle(Tokens.Semantic.statIcon)
                    }
                }
            }

            row("Status", showsDivider: false) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    // Going public asks first; going back to a draft does not need to.
                    set: { on in on ? confirmingEnable = true : (isEnabled = false) }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(Tokens.Semantic.buttonTintDefault)
        )
    }

    private func row<Value: View>(_ title: String,
                                  showsDivider: Bool = true,
                                  @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                Spacer(minLength: Tokens.Spacing.md)
                value()
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if showsDivider {
                Rectangle()
                    .fill(Tokens.Semantic.statIcon.opacity(0.3))
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - Saving

    /// One save, carrying the status the switch is showing.
    ///
    /// It used to write a draft and then publish it, so an event the host had marked
    /// active existed as a draft for a moment first — and the toast said "Saved as a
    /// draft" on the way past, which was simply wrong.
    private func save() {
        Task {
            await app.saveFight(draft, enabled: isEnabled)
            dismiss()
        }
    }
}
