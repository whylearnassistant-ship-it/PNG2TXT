import SwiftUI

/// A reusable thumbnail card for a selected image file.
struct ImageThumbnail: View {
    let url: URL
    let isProcessed: Bool
    let onRemove: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .red)
                        .shadow(radius: 1)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)

                // Checkmark when processed
                if isProcessed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .green)
                        .shadow(radius: 1)
                        .offset(x: 6, y: 100)
                }
            }

            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 120)
        }
        .onAppear { loadImage() }
        .onChange(of: url) { _ in loadImage() }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { image = img }
        }
    }
}
