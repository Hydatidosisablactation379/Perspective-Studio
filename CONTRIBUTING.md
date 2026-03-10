# Contributing to Perspective Studio

Thank you for your interest in contributing to Perspective Studio. This project is built to make running open-source AI models approachable for everyone, and contributions that support that mission are welcome.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Open `perspective studio.xcodeproj` in Xcode 26+
4. Build and run on macOS 26+

### Requirements

- macOS 26 or later
- Xcode 26 or later
- Apple Silicon Mac (M1 or later) for local model inference

## How to Contribute

### Reporting Bugs

Use the [Bug Report](https://github.com/Techopolis/Perspective-Studio/issues/new?template=bug_report.yml) template. Include your macOS version, Mac model, and steps to reproduce.

### Reporting Accessibility Issues

Accessibility is a core priority. Use the [Accessibility Issue](https://github.com/Techopolis/Perspective-Studio/issues/new?template=accessibility.yml) template for any barriers you encounter with VoiceOver, keyboard navigation, or other assistive technologies.

### Suggesting Features

Use the [Feature Request](https://github.com/Techopolis/Perspective-Studio/issues/new?template=feature_request.yml) template. Describe the use case and how the feature would help.

### Submitting Code

1. Create a branch from `main`
2. Make your changes
3. Ensure the project builds without warnings
4. Test with VoiceOver enabled
5. Open a pull request using the PR template

## Code Guidelines

- **Swift 6.2** with strict concurrency
- **SwiftUI** for all UI (no UIKit unless absolutely necessary)
- Use `@Observable` instead of `ObservableObject`/`@Published`
- Use `async/await` instead of `DispatchQueue`
- Use `foregroundStyle()` instead of `foregroundColor()`
- Use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`
- No force unwraps or force try unless unrecoverable

## Accessibility Requirements

All UI contributions must be accessible. This is not optional.

- Add `.accessibilityLabel()` and `.accessibilityHint()` to all interactive elements
- Use `.accessibilityHidden(true)` on decorative images
- Test every UI change with VoiceOver
- Support keyboard navigation
- Do not convey information by color alone

## Code of Conduct

Be respectful, be kind, and be constructive. We are building something for everyone.
