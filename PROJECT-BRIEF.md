# Perspective Studio

## Product Definition

Perspective Studio is a free, open-source, native macOS app for experimenting with local AI models on Apple devices.

It should feel like a serious Apple-native answer to LM Studio: a lab for downloading, inspecting, running, and later tuning models locally, with strong accessibility and clear system-compatibility guidance.

Tagline: Your LLM playground on Apple devices.

## Product Strategy

Perspective Studio and Intelligence serve different roles:

- Perspective Studio is the open-source experimentation product.
- Intelligence is the polished consumer-facing app, including Mac App Store distribution.
- Studio features can be proven in the open-source product first, then selectively brought into Intelligence.
- Perspective Server should evolve into the backend path for advanced Studio features.

This keeps Studio focused on experimentation without forcing the App Store product to carry every advanced workflow immediately.

## Audience

Primary audience:

- Advanced users
- Experimenters
- Researchers
- Builders working with local models on Apple hardware

Secondary audience:

- Curious intermediate users willing to learn

Studio should be more approachable than terminal-first tools, but it should not default to the broadest beginner audience. Advanced functionality should be intentionally enabled.

## Core Principles

- Local-first: models run on-device whenever possible.
- Apple-native: SwiftUI, SwiftData, MLX, Apple Silicon optimization.
- Accessible: strong VoiceOver support, clear labels, and understandable status messaging.
- Honest compatibility: estimate RAM needs before download and before load.
- Community-first: open source from the beginning and built in public.
- Lab-oriented: experimentation comes before general productivity workflows.

## Phase 1 Scope

Phase 1 should stay narrow and solve the core local-model workflow well.

### Must Have

- Model discovery for MLX-compatible models
- Download flow for supported MLX models
- RAM estimation before download and before load
- Clear compatibility warnings for models unlikely to run on the current Mac
- Chat interface for interacting with downloaded models
- Model status UI: downloading, loading, ready, failed
- Basic model management for downloaded assets
- Familiar lab-style UI inspired by LM Studio, but native to macOS
- Benchmarking: tokens per second, time to first token, memory usage

### Explicit Non-Goals For Phase 1

- Adapter training
- Model conversion pipelines
- Benchmarking suites
- Projects/workspaces

## Phase 2 Scope

After the basic model workflow is stable:

- Foundation model adapter training
- Model conversion workflows such as GGUF to MLX
- Core ML support where it helps Apple-platform experimentation
- Better downloaded model management and inspection

## Phase 3 Scope

- Perspective Server integration
- Local/remote hybrid execution
- Projects and repeatable experiment workflows
- Optional enterprise packaging after the open-source core is solid

## UX Direction

The app should feel like a lab.

- Main surface: chat-first workspace
- Familiar message layout, similar to iMessage styling
- Strong model context in the UI: current model, state, memory fit, source
- Discovery and configuration should feel visual, not terminal-like
- Advanced features should be gated, not casually exposed by default

## Compatibility Model

A core product promise is: do not let users waste time downloading models they cannot realistically run.

The app should:

- Estimate required RAM from model size and quantization
- Reserve system memory for macOS overhead
- Classify models as comfortable, tight, or incompatible
- Explain the result in plain language
- Warn before download and before load

## Technical Direction

Initial platform direction:

- App: native macOS app
- Language: Swift 6.2
- UI: SwiftUI
- Persistence: SwiftData
- Inference path: MLX Swift
- Initial model source: Hugging Face, especially MLX-compatible catalogs
- Backend evolution path: Perspective Server

## Distribution

- Perspective Studio: direct distribution, GitHub releases, open source
- Intelligence: App Store and broader consumer distribution

## Repository Reality

Current repository status:

- The Xcode project exists.
- The app is still a starter SwiftUI scaffold.
- `ContentView.swift` is currently a simple placeholder.
- This brief describes the target direction, not completed implementation.

## Recommended Implementation Order

1. Replace the starter UI with a shell app structure.
2. Build model catalog and compatibility logic.
3. Add model download and load state management.
4. Build the chat workspace.
5. Add downloaded-model management.
6. Add advanced-mode gating.
7. Move into training, conversion, and benchmarking only after the core loop is solid.

## Open Questions

These still need product decisions before implementation gets deep:

- Should Studio support only MLX at launch, or also allow non-MLX discovery with conversion prompts later?
Only mlx first

- How much of the UI should be shared conceptually with Intelligence?
The chat portion and conversations not the moddle downloader or the homescreen
- What minimum macOS version is acceptable for MLX and the intended audience?
Let's do 26
- What should the first Perspective Server-backed feature actually be?
Not sure yet
## Working Summary

New changes
I want to have the homescreen bee a bunch of grids it will have catagories like chat and assistant and things like that voice and audio look at the public hf mlx api
Get all moddles plit into catagories i also want to make this app easy for the normal user to learn about ondevice ai
I want onboarding screen that asks like what is your expierence with ai 
I also want it to say what do you plan to use this for
Then have a for you and based on the answers it will recomend good starter moddles also keeping in fact that the ram and computer stats
we also should do ram calculations and things like lm studio 
it should bee voiceover accessible as well
Perspective Studio should launch as an open-source, advanced Apple-platform AI lab focused first on MLX model discovery, compatibility checking, downloading, and chat. Training, conversion, benchmarking, projects, and server-backed workflows matter, but they should come after the basic local experimentation loop is reliable.