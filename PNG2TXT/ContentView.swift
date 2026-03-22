import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Model

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var imageURLs: [URL] = []
    @Published var processedIndices: Set<Int> = []
    @Published var isConverting = false
    @Published var currentProgress: Int = 0
    @Published var totalProgress: Int = 0
    @Published var resultText: String = ""
    @Published var hasResults = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let engine = OCREngine()

    var imageCount: Int { imageURLs.count }

    func addImages(_ urls: [URL]) {
        let existing = Set(imageURLs)
        let newURLs = urls.filter { !existing.contains($0) }
        imageURLs.append(contentsOf: newURLs)
    }

    func removeImage(at index: Int) {
        guard imageURLs.indices.contains(index) else { return }
        imageURLs.remove(at: index)
        processedIndices.remove(index)
        // Shift processed indices
        processedIndices = Set(processedIndices.compactMap { $0 > index ? $0 - 1 : ($0 < index ? $0 : nil) })
    }

    func clearAll() {
        imageURLs.removeAll()
        processedIndices.removeAll()
        resultText = ""
        hasResults = false
        currentProgress = 0
        totalProgress = 0
    }

    func resetForNew() {
        processedIndices.removeAll()
        resultText = ""
        hasResults = false
        currentProgress = 0
        totalProgress = 0
        imageURLs.removeAll()
    }

    func convert() async {
        guard !imageURLs.isEmpty else { return }
        isConverting = true
        processedIndices.removeAll()
        resultText = ""
        currentProgress = 0
        totalProgress = imageURLs.count

        do {
            let results = try await engine.processImages(imageURLs) { [weak self] current, total in
                Task { @MainActor in
                    self?.currentProgress = current
                    self?.totalProgress = total
                    if current > 0 {
                        self?.processedIndices.insert(current - 1)
                    }
                }
            }
            resultText = Self.formatResults(results)
            hasResults = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isConverting = false
    }

    private static func formatResults(_ results: [(url: URL, text: String)]) -> String {
        results.map { item in
            let separator = String(repeating: "═", count: 38)
            let header = """
            \(separator)
            📄 \(item.url.lastPathComponent)
            \(separator)
            """
            let text = item.text.isEmpty ? "(No text detected)" : item.text
            return header + "\n" + text + "\n"
        }.joined(separator: "\n")
    }

    // MARK: - Actions

    func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .png, .jpeg, .tiff, .bmp, .gif, .heic
        ]
        panel.message = "Select images to extract text from"
        if panel.runModal() == .OK {
            addImages(panel.urls)
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "extracted_text.txt"
        panel.message = "Save extracted text"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try resultText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = "Failed to save file: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func openInTextEdit() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PNG2TXT_output.txt")
        do {
            try resultText.write(to: tempURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempURL)
        } catch {
            errorMessage = "Failed to open in TextEdit: \(error.localizedDescription)"
            showError = true
        }
    }

    func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @State private var isDropTargeted = false

    private let supportedTypes: [UTType] = [.png, .jpeg, .tiff, .bmp, .gif, .heic, .image]
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if vm.isConverting {
                progressView
            } else if vm.hasResults {
                resultsView
            } else {
                imageSelectionView
            }
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
        .onDrop(of: supportedTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PNG2TXT")
                    .font(.title2.bold())
                Text("Convert screenshots to text")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !vm.hasResults {
                HStack(spacing: 8) {
                    if !vm.imageURLs.isEmpty {
                        Text("\(vm.imageCount) image\(vm.imageCount == 1 ? "" : "s")")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        vm.selectImages()
                    } label: {
                        Label("Select Images", systemImage: "photo.on.rectangle.angled")
                    }

                    if !vm.imageURLs.isEmpty {
                        Button(role: .destructive) {
                            vm.clearAll()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }

                        Button {
                            Task { await vm.convert() }
                        } label: {
                            Label("Convert", systemImage: "text.viewfinder")
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Image Selection

    private var imageSelectionView: some View {
        Group {
            if vm.imageURLs.isEmpty {
                emptyPlaceholder
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(vm.imageURLs.enumerated()), id: \.offset) { index, url in
                            ImageThumbnail(
                                url: url,
                                isProcessed: vm.processedIndices.contains(index),
                                onRemove: { vm.removeImage(at: index) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Drop images here or click Select Images")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Supports PNG, JPEG, TIFF, BMP, GIF, HEIC")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { vm.selectImages() }
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: Double(vm.currentProgress), total: Double(max(vm.totalProgress, 1)))
                .progressViewStyle(.linear)
                .frame(width: 300)
            Text("Processing image \(vm.currentProgress) of \(vm.totalProgress)…")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        HSplitView {
            // Left: thumbnails
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 12) {
                    ForEach(Array(vm.imageURLs.enumerated()), id: \.offset) { index, url in
                        ImageThumbnail(
                            url: url,
                            isProcessed: true,
                            onRemove: {}
                        )
                        .allowsHitTesting(false)
                    }
                }
                .padding()
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Right: text preview + action buttons
            VStack(spacing: 0) {
                ScrollView {
                    Text(vm.resultText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(nsColor: .textBackgroundColor))

                Divider()

                HStack {
                    Button {
                        vm.saveAs()
                    } label: {
                        Label("Save As…", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        vm.openInTextEdit()
                    } label: {
                        Label("Open in TextEdit", systemImage: "doc.text")
                    }

                    Button {
                        vm.copyAll()
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }

                    Spacer()

                    Button {
                        vm.resetForNew()
                    } label: {
                        Label("New Conversion", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10)
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      Self.isImageFile(url) else { return }
                Task { @MainActor in
                    vm.addImages([url])
                }
            }
        }
    }

    private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic"].contains(ext)
    }
}
