import AppKit
import Vision

/// Handles OCR text recognition using Apple's Vision framework.
class OCREngine {

    enum OCRError: LocalizedError {
        case imageConversionFailed(String)
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed(let name):
                return "Could not convert image "\(name)" to a processable format."
            case .recognitionFailed(let name):
                return "Text recognition failed for "\(name)"."
            }
        }
    }

    /// Recognize text in a single NSImage.
    func recognizeText(in image: NSImage, filename: String = "image") async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            throw OCRError.imageConversionFailed(filename)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed("\(filename): \(error.localizedDescription)"))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Let Vision auto-detect languages; English preferred
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            request.recognitionLanguages = ["en"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed("\(filename): \(error.localizedDescription)"))
            }
        }
    }

    /// Process a batch of image URLs, reporting progress along the way.
    func processImages(
        _ urls: [URL],
        progress: @escaping (Int, Int) -> Void
    ) async throws -> [(url: URL, text: String)] {
        var results: [(url: URL, text: String)] = []
        for (index, url) in urls.enumerated() {
            progress(index + 1, urls.count)
            guard let image = NSImage(contentsOf: url) else {
                throw OCRError.imageConversionFailed(url.lastPathComponent)
            }
            let text = try await recognizeText(in: image, filename: url.lastPathComponent)
            results.append((url: url, text: text))
        }
        return results
    }
}
