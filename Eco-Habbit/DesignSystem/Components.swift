import SwiftUI

// MARK: - Buttons

/// `.btn.btn-primary` — a solid accent fill, pill shaped.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var fontSize: CGFloat = 17

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.F.heading(fontSize))
            .foregroundStyle(Theme.C.bg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Capsule().fill(configuration.isPressed ? Theme.C.accent700 : Theme.C.accent)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// `.btn.btn-secondary` — outlined, tints on press.
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fontSize: CGFloat = 15
    var expands: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.F.heading(fontSize))
            .foregroundStyle(Theme.C.text)
            .padding(.horizontal, expands ? 0 : Theme.S.x4)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(Theme.C.text.opacity(configuration.isPressed ? 0.14 : 0))
                    .overlay(Capsule().stroke(Theme.C.divider, lineWidth: 1))
            )
    }
}

/// `.btn.btn-ghost` — accent text, tinted press state.
struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var fontSize: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.F.heading(fontSize))
            .foregroundStyle(Theme.C.accent700)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Capsule().fill(Theme.C.accent.opacity(configuration.isPressed ? 0.18 : 0))
            )
    }
}

/// A whole card that behaves as a button without the default blue tint.
struct PlainPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Card

/// `.card` — a surface-filled container. Elevation is opt-in.
struct EHCard<Content: View>: View {
    var padding: CGFloat = Theme.S.x3
    var background: AnyShapeStyle = AnyShapeStyle(Theme.C.surface)
    var shadow: Theme.Shadow? = Theme.E.sm
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.R.card).fill(background))
            .modifier(OptionalShadow(shadow: shadow))
    }
}

private struct OptionalShadow: ViewModifier {
    let shadow: Theme.Shadow?
    func body(content: Content) -> some View {
        if let shadow {
            content.elevation(shadow)
        } else {
            content
        }
    }
}

// MARK: - Tag

enum TagStyle {
    case accent, accent2, neutral, outline

    var fg: Color {
        switch self {
        case .accent: return Theme.C.accent800
        case .accent2: return Theme.C.accent2_800
        case .neutral: return Theme.C.neutral800
        case .outline: return Theme.C.accent700
        }
    }

    var bg: Color {
        switch self {
        case .accent: return Theme.C.accent100
        case .accent2: return Theme.C.accent2_100
        case .neutral: return Theme.C.neutral100
        case .outline: return .clear
        }
    }
}

/// `.tag` in its four variants.
struct EHTag: View {
    let text: String
    var style: TagStyle = .accent
    var fontSize: CGFloat = 11

    var body: some View {
        Text(text)
            .font(Theme.F.body(fontSize, weight: .semibold))
            .foregroundStyle(style.fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(style.bg)
                    .overlay(
                        Capsule().stroke(
                            style == .outline ? Theme.C.accent : .clear,
                            lineWidth: 1
                        )
                    )
            )
    }
}

// MARK: - Segmented control

struct EHSegmented<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(Theme.F.body(13.5, weight: .bold))
                        .foregroundStyle(selection == option.value ? .white : Theme.C.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selection == option.value ? Theme.C.accent500 : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().stroke(Theme.C.divider, lineWidth: 1))
    }
}

// MARK: - Text field

struct EHTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var error: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Theme.F.body(12))
                .foregroundStyle(Theme.C.text.opacity(0.7))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(Theme.F.body(14))
            .foregroundStyle(Theme.C.text)
            .tint(Theme.C.accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .textContentType(contentType)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(Theme.C.surface)
                    .overlay(
                        Capsule().stroke(
                            error != nil ? Theme.C.accent700
                                : (focused ? Theme.C.accent : Theme.C.divider),
                            lineWidth: focused || error != nil ? 1.5 : 1
                        )
                    )
            )

            if let error {
                Text(error)
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.accent700)
                    .padding(.leading, 14)
            }
        }
    }
}

// MARK: - Progress bar

struct EHProgressBar: View {
    /// 0...1
    let value: Double
    var height: CGFloat = 8
    var tint: Color = Theme.C.accent500

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.C.neutral200)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Section heading

struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.F.body(15, weight: .bold))
            .foregroundStyle(Theme.C.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Circular back button (used on pushed detail screens)

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 34
    var background: Color = Theme.C.neutral200
    var foreground: Color = Theme.C.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
        }
        .buttonStyle(PlainPressStyle())
    }
}

// MARK: - Settings row

struct SettingsRow<Trailing: View>: View {
    let title: String
    var showsDivider: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(Theme.F.body(14.5))
                    .foregroundStyle(Theme.C.text)
                Spacer()
                trailing
            }
            .padding(14)

            if showsDivider {
                Rectangle()
                    .fill(Theme.C.neutral200)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
        }
    }
}

extension SettingsRow where Trailing == Image {
    init(title: String, showsDivider: Bool = true) {
        self.init(title: title, showsDivider: showsDivider) {
            Image(systemName: "chevron.right")
        }
    }
}

struct ChevronRight: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.C.neutral400)
    }
}

struct OurFightCategoryIcon: View {
    let color: Color
    
    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 10, height: 85)
    }
}

#Preview {
    OurFightCategoryIcon(color: Tokens.Palette.purple)
}
