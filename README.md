# CameraAccess

A minimal iOS camera demo built with SwiftUI and AVFoundation. Provides a full-screen live preview with photo capture, front/back camera switching, and flash control.

## Features

- Live camera preview with full-screen viewfinder
- Photo capture with automatic save to the photo library
- Front/back camera switching
- Flash mode control (off, on, auto)
- Graceful camera and photo library permission handling
- Dark, minimal UI aesthetic

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Physical device (camera is not available in the iOS Simulator)

## Architecture

| File | Role |
|------|------|
| **CameraService.swift** | `ObservableObject` managing `AVCaptureSession` setup, photo capture, saving to the photo library, camera switching, and flash mode cycling. |
| **CameraPreview.swift** | `UIViewRepresentable` that bridges an `AVCaptureVideoPreviewLayer` into SwiftUI. |
| **ContentView.swift** | SwiftUI interface composing the live preview, shutter button, camera flip, flash toggle, captured-image thumbnail, and error alerts. |
