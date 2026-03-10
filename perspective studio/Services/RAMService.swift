import Foundation
import SwiftUI

struct RAMService: Sendable {
    enum Compatibility: String, Sendable {
        case comfortable = "Comfortable"
        case tight = "Tight Fit"
        case incompatible = "Too Large"
        case unknown = "Unknown Size"

        var systemImage: String {
            switch self {
            case .comfortable: "checkmark.circle.fill"
            case .tight: "exclamationmark.triangle.fill"
            case .incompatible: "xmark.circle.fill"
            case .unknown: "questionmark.circle.fill"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .comfortable: "Model fits comfortably in RAM"
            case .tight: "Model may be a tight fit for your RAM"
            case .incompatible: "Model is too large for your available RAM"
            case .unknown: "Model size could not be determined"
            }
        }

        var beginnerDescription: String {
            switch self {
            case .comfortable: "This model will run smoothly on your Mac."
            case .tight: "This model should work, but may run slowly on your Mac."
            case .incompatible: "This model is too large for your Mac to run."
            case .unknown: "We could not determine if this model fits your Mac."
            }
        }

        var color: Color {
            switch self {
            case .comfortable: .green
            case .tight: .orange
            case .incompatible: .red
            case .unknown: .secondary
            }
        }
    }

    /// Reserve a portion of total RAM for the OS and background apps.
    /// Scales proportionally: 25% of total RAM, capped at 5 GB.
    static var systemOverheadGB: Double {
        min(totalRAMInGB * 0.25, 5.0)
    }

    static var totalRAMInGB: Double {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        return Double(totalBytes) / 1_073_741_824
    }

    static var availableRAMForModels: Double {
        max(totalRAMInGB - systemOverheadGB, 0)
    }

    /// Estimate total RAM needed: model weights + KV cache + runtime overhead
    static func estimateRAMNeeded(modelWeightsGB: Double, parameterCountB: Double? = nil, contextLength: Int = 4096) -> Double {
        let kvCacheGB = estimateKVCacheGB(parameterCountB: parameterCountB, modelWeightsGB: modelWeightsGB, contextLength: contextLength)
        let runtimeOverheadGB = 0.5 // activations, tokenizer, buffers
        return modelWeightsGB + kvCacheGB + runtimeOverheadGB
    }

    /// Estimate KV cache size. KV cache is always fp16 and scales with parameter
    /// count, not quantized weight size. Uses paramB * 0.07 as a heuristic that
    /// accounts for GQA in modern architectures (e.g. 12B → ~0.84 GB at 4K context).
    /// Falls back to weight-based estimate when parameter count is unavailable.
    static func estimateKVCacheGB(parameterCountB: Double? = nil, modelWeightsGB: Double, contextLength: Int = 4096) -> Double {
        let contextScale = Double(contextLength) / 4096.0
        if let paramB = parameterCountB {
            return paramB * 0.07 * contextScale
        }
        // Fallback: assume fp16 weights, so modelWeightsGB ≈ paramB * 2
        return (modelWeightsGB / 2.0) * 0.07 * contextScale
    }

    static func checkCompatibility(modelSizeGB: Double, parameterCountB: Double? = nil) -> Compatibility {
        let totalNeeded = estimateRAMNeeded(modelWeightsGB: modelSizeGB, parameterCountB: parameterCountB)
        let available = availableRAMForModels

        if totalNeeded <= available * 0.70 {
            return .comfortable
        } else if totalNeeded <= available * 0.90 {
            return .tight
        } else {
            return .incompatible
        }
    }

    static func detailedBreakdown(modelWeightsGB: Double, parameterCountB: Double? = nil, contextLength: Int = 4096) -> RAMBreakdown {
        let kvCache = estimateKVCacheGB(parameterCountB: parameterCountB, modelWeightsGB: modelWeightsGB, contextLength: contextLength)
        let overhead = 0.5
        let total = modelWeightsGB + kvCache + overhead
        let available = availableRAMForModels
        return RAMBreakdown(
            modelWeightsGB: modelWeightsGB,
            kvCacheGB: kvCache,
            runtimeOverheadGB: overhead,
            totalNeededGB: total,
            availableGB: available,
            totalSystemGB: totalRAMInGB,
            compatibility: checkCompatibility(modelSizeGB: modelWeightsGB, parameterCountB: parameterCountB)
        )
    }

    static var ramDescription: String {
        let total = totalRAMInGB.formatted(.number.precision(.fractionLength(0)))
        return "\(total) GB Unified Memory"
    }

    typealias ModelCompatibility = Compatibility

    static func canRunModel(ramRequired: Double) -> Compatibility {
        checkCompatibility(modelSizeGB: ramRequired)
    }
}

struct RAMBreakdown: Sendable {
    let modelWeightsGB: Double
    let kvCacheGB: Double
    let runtimeOverheadGB: Double
    let totalNeededGB: Double
    let availableGB: Double
    let totalSystemGB: Double
    let compatibility: RAMService.Compatibility
}
