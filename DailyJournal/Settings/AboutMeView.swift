import SwiftUI
import PencilKit

/// The "first page" of the journal: who you are, your favorites, and what you're up to.
/// Only filled-in items show. Tap Edit to change them.
struct AboutMeView: View {
    @Bindable var profile: UserProfile

    private var fullName: String {
        "\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces)
    }

    private var isEmpty: Bool {
        fullName.isEmpty && profile.nickname.isEmpty && profile.birthday == nil && profile.favorites.isEmpty
            && profile.threeWords.isEmpty && !profile.hasRightNow && profile.quote.isEmpty
            && profile.signature == nil && profile.photo == nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if profile.rightNowIsOld {
                    NavigationLink { ProfileView(profile: profile) } label: {
                        Label("It's been a year. Update your \"Right now\"?", systemImage: "hourglass")
                            .appFont(.subheadline, weight: .semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if isEmpty {
                    ContentUnavailableView {
                        Label("Your first page", systemImage: "book.closed")
                    } description: {
                        Text("Like the first page of a paper diary. Add your favorites, three words about you, and what you're into right now.")
                    } actions: {
                        NavigationLink("Start") { ProfileView(profile: profile) }
                            .buttonStyle(.borderedProminent)
                    }
                }

                if !profile.favorites.isEmpty {
                    PageCard(title: "Favorites") {
                        ForEach(profile.favorites, id: \.self) { item in
                            InfoRow(label: item.label, value: item.value)
                        }
                    }
                }

                if !profile.threeWords.isEmpty {
                    PageCard(title: "Three words about me") {
                        Text(profile.threeWords).appFont(.title3, weight: .semibold)
                    }
                }

                if profile.hasRightNow {
                    PageCard(title: "Right now", date: profile.rightNowUpdated) {
                        if !profile.mood.isEmpty { InfoRow(label: "Mood", value: profile.mood) }
                        if !profile.intoNow.isEmpty { InfoRow(label: "Into", value: profile.intoNow) }
                        if !profile.goals.isEmpty { InfoRow(label: "Goals", value: profile.goals) }
                    }
                }

                let capsule = profile.timeCapsule
                if !capsule.isEmpty {
                    PageCard(title: "Time capsule") {
                        ForEach(capsule) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date, format: .dateTime.month(.wide).year())
                                    .appFont(.subheadline, weight: .semibold)
                                    .foregroundStyle(Color.accentColor)
                                if !entry.mood.isEmpty { InfoRow(label: "Mood", value: entry.mood) }
                                if !entry.intoNow.isEmpty { InfoRow(label: "Into", value: entry.intoNow) }
                                if !entry.goals.isEmpty { InfoRow(label: "Goals", value: entry.goals) }
                            }
                            if entry != capsule.last { Divider() }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink("Edit") { ProfileView(profile: profile) }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ProfileAvatar(initials: profile.initials, photo: profile.photo, size: 104)
            if !fullName.isEmpty {
                Text(fullName).appFont(.title2, weight: .bold)
            }
            if !profile.nickname.isEmpty {
                Text("\u{201C}\(profile.nickname)\u{201D}").appFont(.subheadline).foregroundStyle(.secondary)
            }
            if let birthday = profile.birthday {
                HStack(spacing: 6) {
                    Text(birthday, format: .dateTime.month(.wide).day())
                    if let sign = profile.zodiac {
                        Text("·")
                        Text("\(sign.symbol) \(sign.rawValue)")
                    }
                }
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
            }
            if !profile.quote.isEmpty {
                Text(profile.quote)
                    .appFont(.body)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            if let data = profile.signature, let image = SignatureSheet.image(from: data) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 60)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct PageCard<Content: View>: View {
    let title: String
    var date: Date? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .kerning(0.6)
                Spacer()
                if let date {
                    Text(date, format: .dateTime.month(.abbreviated).year())
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value).appFont(.body)
            Spacer(minLength: 0)
        }
    }
}

/// Draw a signature with a finger.
struct SignatureSheet: View {
    @Binding var signature: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Sign with your finger")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                SignatureCanvas(drawing: $drawing)
                    .frame(height: 220)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1).padding(.horizontal, 24).padding(.bottom, 50)
                    }
                Button("Clear") { drawing = PKDrawing() }
                Spacer()
            }
            .padding()
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        signature = drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let signature, let saved = try? PKDrawing(data: signature) { drawing = saved }
            }
        }
        .presentationDetents([.medium])
    }

    /// The signature as an image, trimmed to the ink.
    static func image(from data: Data) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds.insetBy(dx: -4, dy: -4), scale: 3)
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawingPolicy = .anyInput
        view.tool = PKInkingTool(.pen, color: .label, width: 4)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawing = drawing
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        if view.drawing.dataRepresentation() != drawing.dataRepresentation() { view.drawing = drawing }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: SignatureCanvas
        init(_ parent: SignatureCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
