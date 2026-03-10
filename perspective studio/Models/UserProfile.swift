import Foundation
import SwiftData

@Model
final class UserProfile {
    var experienceLevel: ExperienceLevel
    var interests: [AIInterest]
    var hasCompletedOnboarding: Bool

    init(experienceLevel: ExperienceLevel = .beginner, interests: [AIInterest] = [], hasCompletedOnboarding: Bool = false) {
        self.experienceLevel = experienceLevel
        self.interests = interests
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner
    case intermediate
    case powerUser

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "I'm New to AI"
        case .intermediate: "I've Used AI a Bit"
        case .powerUser: "I'm Experienced with AI"
        }
    }

    var description: String {
        switch self {
        case .beginner: "I have not used local AI models before and want a simple experience."
        case .intermediate: "I have tried ChatGPT or similar tools and want to explore more."
        case .powerUser: "I run models locally and understand quantization, parameters, and inference."
        }
    }

    var icon: String {
        switch self {
        case .beginner: "sparkles"
        case .intermediate: "brain"
        case .powerUser: "hammer"
        }
    }
}

enum AIInterest: String, Codable, CaseIterable, Identifiable, Sendable {
    case creativeWriting
    case coding
    case research
    case learning
    case generalChat
    case brainstorming

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .creativeWriting: "Creative Writing"
        case .coding: "Coding Help"
        case .research: "Research & Analysis"
        case .learning: "Learning New Things"
        case .generalChat: "General Conversation"
        case .brainstorming: "Brainstorming Ideas"
        }
    }

    var icon: String {
        switch self {
        case .creativeWriting: "pencil.and.outline"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .research: "magnifyingglass"
        case .learning: "book"
        case .generalChat: "bubble.left.and.bubble.right"
        case .brainstorming: "lightbulb"
        }
    }

    var description: String {
        switch self {
        case .creativeWriting: "Stories, poems, blog posts, and creative content"
        case .coding: "Write, debug, and explain code"
        case .research: "Analyze information and answer complex questions"
        case .learning: "Explain concepts and teach new skills"
        case .generalChat: "Have natural conversations about anything"
        case .brainstorming: "Generate ideas and explore possibilities"
        }
    }
}
