# PNG2TXT

A native macOS app that extracts text from screenshot images using Apple's Vision framework (OCR).

## Features

- **Batch Processing** — Select multiple images and extract text from all of them at once
- **Drag & Drop** — Drag image files directly onto the window
- **Multiple Formats** — Supports PNG, JPEG, TIFF, BMP, GIF, and HEIC
- **Accurate OCR** — Uses Apple's Vision framework with accurate recognition level and language correction
- **Clean Output** — Extracted text is organized with clear headers showing which image each section came from
- **Export Options** — Save as `.txt`, open in TextEdit, or copy to clipboard
- **Progress Tracking** — Real-time progress bar during conversion with per-image checkmarks
- **Native macOS** — Follows system appearance (light/dark mode), built with SwiftUI

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

## Building

### Open in Xcode

```bash
open PNG2TXT.xcodeproj
```

Then press **⌘R** to build and run.

### Command Line

```bash
xcodebuild -scheme PNG2TXT build
```

## Usage

1. Launch PNG2TXT
2. Click **Select Images** or drag image files onto the window
3. Click **Convert** (or press ⌘Return)
4. Review the extracted text in the preview pane
5. **Save As…** to export, **Copy All** to clipboard, or **Open in TextEdit**

## Architecture

| File | Purpose |
|------|---------|
| `PNG2TXTApp.swift` | SwiftUI app entry point |
| `ContentView.swift` | Main UI with image grid, progress, and results views |
| `OCREngine.swift` | Vision framework OCR logic |
| `ImageThumbnail.swift` | Reusable thumbnail card component |

No external dependencies — uses only Apple's built-in Vision framework.
