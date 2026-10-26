import SwiftUI

struct ApprovalCard: View {
    let request: ApprovalRequest
    let index: Int
    let total: Int
    let reduceMotion: Bool
    let onDecide: (Decision) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MascotView(agent: request.agent, mood: .waiting, size: 34, reduceMotion: reduceMotion)
                    .padding(.trailing, 6)
                HStack(spacing: 5) {
                    Image(systemName: request.agent.symbol)
                    Text(request.agent.displayName)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(request.agent.color))

                Text(request.project)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                if total > 1 {
                    Text(L("%ld of %ld", index + 1, total))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text(request.toolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            if !request.summary.isEmpty {
                Text(request.summary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
            }

            HStack(spacing: 8) {
                Button { onDecide(.deny) } label: { label(L("Deny"), hint: "\u{2318}\u{232B}") }
                    .buttonStyle(CardButtonStyle(fill: .white.opacity(0.14), foreground: .white))
                    .keyboardShortcut(.delete, modifiers: .command)
                Button { onDecide(.allow) } label: { label(L("Allow"), hint: "\u{21A9}") }
                    .buttonStyle(CardButtonStyle(fill: request.agent.color, foreground: .black))
                    .keyboardShortcut(.return, modifiers: [])
            }

            Button(L("Answer in terminal")) { onDecide(.terminal) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
        }
    }

    private func label(_ title: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Text(title).fontWeight(.semibold)
            Text(hint).opacity(0.55)
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity)
    }
}

struct CardButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
