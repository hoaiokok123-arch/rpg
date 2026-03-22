import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var gameLibrary: GameLibrary

    @State private var isShowingPicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if gameLibrary.games.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(gameLibrary.games) { game in
                                    SwipeableGameCard(game: game) {
                                        withAnimation {
                                            gameLibrary.deleteGame(game)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .disabled(isImporting)

                if isImporting {
                    importOverlay
                }
            }
            .navigationTitle("RPGPlayer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingPicker) {
                ZipDocumentPicker { url in
                    isShowingPicker = false
                    importGame(at: url)
                } onCancel: {
                    isShowingPicker = false
                }
            }
            .alert("Import that bai", isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                gameLibrary.loadGames()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Nhấn + để thêm game")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Dang import game...")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func importGame(at url: URL) {
        Task {
            isImporting = true
            defer { isImporting = false }

            do {
                _ = try await gameLibrary.importGame(url: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct SwipeableGameCard: View {
    let game: Game
    let onDelete: () -> Void

    @GestureState private var dragOffsetX: CGFloat = 0
    @State private var committedOffsetX: CGFloat = 0

    private let revealWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.85))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth, height: 130)
            }
            .buttonStyle(.plain)

            NavigationLink {
                GamePlayerView(game: game)
            } label: {
                GameCard(game: game)
            }
            .buttonStyle(.plain)
            .offset(x: currentOffsetX)
            .simultaneousGesture(dragGesture)
            .contextMenu {
                Button("Xoá game", role: .destructive, action: onDelete)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.spring(response: 0.25, dampingFraction: 0.92), value: committedOffsetX)
    }

    private var currentOffsetX: CGFloat {
        let raw = committedOffsetX + dragOffsetX
        return min(0, max(-revealWidth, raw))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .updating($dragOffsetX) { value, state, _ in
                if value.translation.width < 0 || committedOffsetX < 0 {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                let finalOffset = committedOffsetX + value.translation.width
                withAnimation {
                    if finalOffset <= -revealWidth * 0.45 {
                        committedOffsetX = -revealWidth
                    } else {
                        committedOffsetX = 0
                    }
                }
            }
    }
}

private struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Text(game.version.badgeTitle)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
            Spacer()
            Text(game.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var badgeColor: Color {
        switch game.version {
        case .mz:
            return .orange
        case .mv:
            return .blue
        case .unknown:
            return .gray
        }
    }
}

private struct ZipDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.zip],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else {
                onCancel()
                return
            }
            onPick(selectedURL)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
