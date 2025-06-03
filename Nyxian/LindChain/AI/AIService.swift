//
//  AIService.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation

/// Enum representing the available AI providers
public enum AIProvider: String, CaseIterable, Codable {
    /// Anthropic's Claude API
    case claude = "Claude"
    
    /// Google's Gemini API
    case gemini = "Gemini"
    
    /// OpenAI API and compatible providers
    case openAI = "OpenAI"
    
    /// Custom API endpoint compatible with OpenAI format
    case custom = "Custom OpenAI-compatible"
    
    /// Returns the default base URL for the provider
    var defaultBaseURL: String {
        switch self {
        case .claude:
            return "https://api.anthropic.com"
        case .gemini:
            return "https://generativelanguage.googleapis.com"
        case .openAI:
            return "https://api.openai.com"
        case .custom:
            return "" // Empty by default, to be set by user
        }
    }
    
    /// Returns the icon name for the provider
    var iconName: String {
        switch self {
        case .claude:
            return "bubble.left.and.text.bubble.right.fill"
        case .gemini:
            return "sparkles.square.filled.on.square"
        case .openAI:
            return "brain.head.profile"
        case .custom:
            return "network"
        }
    }
}

/// Enum representing the possible AI features
public enum AIFeature: String, CaseIterable, Codable {
    /// Auto-completion of code as you type
    case autoCompletion = "Auto Completion"
    
    /// Generate code based on comments or prompts
    case codeGeneration = "Code Generation"
    
    /// Explain selected code
    case codeExplanation = "Code Explanation"
    
    /// Refactor selected code
    case codeRefactoring = "Code Refactoring"
    
    /// Documentation generation for functions and classes
    case docGeneration = "Documentation Generation"
    
    /// Returns the icon name for the feature
    var iconName: String {
        switch self {
        case .autoCompletion:
            return "text.append"
        case .codeGeneration:
            return "hammer.fill"
        case .codeExplanation:
            return "text.bubble.fill"
        case .codeRefactoring:
            return "arrow.triangle.swap"
        case .docGeneration:
            return "doc.text.fill"
        }
    }
    
    /// Returns the description for the feature
    var description: String {
        switch self {
        case .autoCompletion:
            return "Suggests code completions as you type"
        case .codeGeneration:
            return "Generates code based on comments or natural language descriptions"
        case .codeExplanation:
            return "Explains what selected code does in plain language"
        case .codeRefactoring:
            return "Suggests improvements or alternative implementations for selected code"
        case .docGeneration:
            return "Generates documentation for functions, classes, and methods"
        }
    }
}

/// Errors that can occur when using AI services
public enum AIServiceError: Error {
    /// API key is missing or invalid
    case invalidAPIKey
    
    /// The request to the AI service failed
    case requestFailed(Error)
    
    /// The AI service returned an error
    case serviceError(String)
    
    /// The response from the AI service could not be parsed
    case parsingError
    
    /// The user has exceeded their rate limit
    case rateLimitExceeded
    
    /// The connection to the AI service timed out
    case timeout
    
    /// The AI service is not available
    case serviceUnavailable
    
    /// The user is not authorized to use this model or feature
    case unauthorized
    
    /// Custom error with description
    case custom(String)
    
    /// Returns a user-friendly error message
    var localizedDescription: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing API key. Please check your settings."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .serviceError(let message):
            return "Service error: \(message)"
        case .parsingError:
            return "Failed to parse the AI service response."
        case .rateLimitExceeded:
            return "You've exceeded the rate limit for this AI service. Please try again later."
        case .timeout:
            return "The request to the AI service timed out."
        case .serviceUnavailable:
            return "The AI service is currently unavailable. Please try again later."
        case .unauthorized:
            return "You're not authorized to use this model or feature."
        case .custom(let message):
            return message
        }
    }
}

/// Struct representing a completion request to an AI service
public struct AICompletionRequest {
    /// The text prompt for the completion
    let prompt: String
    
    /// The maximum number of tokens to generate
    let maxTokens: Int
    
    /// The temperature for the completion (0.0 - 1.0)
    let temperature: Double
    
    /// The file extension or language of the code
    let language: String
    
    /// The feature being used
    let feature: AIFeature
    
    /// Additional context to provide to the AI
    let context: String?
    
    /// The current project information
    let projectInfo: [String: String]?
    
    /// Creates a new completion request
    /// - Parameters:
    ///   - prompt: The text prompt for the completion
    ///   - maxTokens: The maximum number of tokens to generate
    ///   - temperature: The temperature for the completion (0.0 - 1.0)
    ///   - language: The file extension or language of the code
    ///   - feature: The feature being used
    ///   - context: Additional context to provide to the AI
    ///   - projectInfo: The current project information
    public init(
        prompt: String,
        maxTokens: Int = 1024,
        temperature: Double = 0.7,
        language: String,
        feature: AIFeature,
        context: String? = nil,
        projectInfo: [String: String]? = nil
    ) {
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.language = language
        self.feature = feature
        self.context = context
        self.projectInfo = projectInfo
    }
}

/// Struct representing a completion response from an AI service
public struct AICompletionResponse {
    /// The generated completion text
    let completion: String
    
    /// Whether the response was truncated
    let isTruncated: Bool
    
    /// The number of tokens used for the request
    let tokensUsed: Int?
    
    /// Any additional information from the provider
    let additionalInfo: [String: Any]?
    
    /// Creates a new completion response
    /// - Parameters:
    ///   - completion: The generated completion text
    ///   - isTruncated: Whether the response was truncated
    ///   - tokensUsed: The number of tokens used for the request
    ///   - additionalInfo: Any additional information from the provider
    public init(
        completion: String,
        isTruncated: Bool = false,
        tokensUsed: Int? = nil,
        additionalInfo: [String: Any]? = nil
    ) {
        self.completion = completion
        self.isTruncated = isTruncated
        self.tokensUsed = tokensUsed
        self.additionalInfo = additionalInfo
    }
}

/// Configuration for an AI service provider
public struct AIServiceConfiguration: Codable {
    /// The API key for the service
    var apiKey: String
    
    /// The base URL for the service
    var baseURL: String
    
    /// The model to use for the service
    var model: String
    
    /// Whether to use streaming for completions
    var useStreaming: Bool
    
    /// The organization ID (if applicable)
    var organizationID: String?
    
    /// Additional headers to include in requests
    var additionalHeaders: [String: String]?
    
    /// Additional parameters to include in requests
    var additionalParameters: [String: String]?
    
    /// Creates a new AI service configuration
    /// - Parameters:
    ///   - apiKey: The API key for the service
    ///   - baseURL: The base URL for the service
    ///   - model: The model to use for the service
    ///   - useStreaming: Whether to use streaming for completions
    ///   - organizationID: The organization ID (if applicable)
    ///   - additionalHeaders: Additional headers to include in requests
    ///   - additionalParameters: Additional parameters to include in requests
    public init(
        apiKey: String,
        baseURL: String,
        model: String,
        useStreaming: Bool = false,
        organizationID: String? = nil,
        additionalHeaders: [String: String]? = nil,
        additionalParameters: [String: String]? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.useStreaming = useStreaming
        self.organizationID = organizationID
        self.additionalHeaders = additionalHeaders
        self.additionalParameters = additionalParameters
    }
}

/// Protocol for streaming completion updates
public protocol AICompletionStreamDelegate: AnyObject {
    /// Called when a chunk of completion text is received
    /// - Parameter text: The new chunk of text
    func didReceiveCompletionChunk(_ text: String)
    
    /// Called when the completion stream has ended
    func didFinishCompletion()
    
    /// Called when an error occurs during streaming
    /// - Parameter error: The error that occurred
    func didEncounterError(_ error: AIServiceError)
}

/// Protocol that all AI service providers must implement
public protocol AIService {
    /// The provider type
    var provider: AIProvider { get }
    
    /// The configuration for the service
    var configuration: AIServiceConfiguration { get set }
    
    /// The features supported by this provider
    var supportedFeatures: [AIFeature] { get }
    
    /// The available models for this provider
    var availableModels: [String] { get }
    
    /// The default model for this provider
    var defaultModel: String { get }
    
    /// Validates the API key for the service
    /// - Parameter completion: Callback with the result of the validation
    func validateAPIKey(completion: @escaping (Result<Bool, AIServiceError>) -> Void)
    
    /// Gets a completion for the given request
    /// - Parameters:
    ///   - request: The completion request
    ///   - completion: Callback with the result of the completion
    func getCompletion(for request: AICompletionRequest, completion: @escaping (Result<AICompletionResponse, AIServiceError>) -> Void)
    
    /// Gets a streaming completion for the given request
    /// - Parameters:
    ///   - request: The completion request
    ///   - delegate: The delegate to receive streaming updates
    func getStreamingCompletion(for request: AICompletionRequest, delegate: AICompletionStreamDelegate)
    
    /// Cancels any ongoing completion requests
    func cancelCompletionRequests()
}

/// Factory for creating AI services
public class AIServiceFactory {
    /// Creates an AI service for the given provider
    /// - Parameters:
    ///   - provider: The provider to create a service for
    ///   - configuration: The configuration for the service
    /// - Returns: An AI service for the given provider
    public static func createService(for provider: AIProvider, with configuration: AIServiceConfiguration) -> AIService? {
        switch provider {
        case .claude:
            // Import the ClaudeService class
            if let claudeServiceClass = NSClassFromString("Nyxian.ClaudeService") as? NSObject.Type,
               let claudeService = claudeServiceClass.init() as? AIService {
                var service = claudeService
                service.configuration = configuration
                return service
            } else {
                // Fallback to using the class directly if available
                return ClaudeService(configuration: configuration)
            }
            
        case .gemini:
            // Import the GeminiService class
            if let geminiServiceClass = NSClassFromString("Nyxian.GeminiService") as? NSObject.Type,
               let geminiService = geminiServiceClass.init() as? AIService {
                var service = geminiService
                service.configuration = configuration
                return service
            } else {
                // Fallback to using the class directly if available
                return GeminiService(configuration: configuration)
            }
            
        case .openAI, .custom:
            // Import the OpenAIService class
            if let openAIServiceClass = NSClassFromString("Nyxian.OpenAIService") as? NSObject.Type,
               let openAIService = openAIServiceClass.init() as? AIService {
                var service = openAIService
                service.configuration = configuration
                return service
            } else {
                // Fallback to using the class directly if available
                return OpenAIService(configuration: configuration)
            }
        }
    }
}

/// Manager for AI services
public class AIServiceManager {
    /// Shared instance of the manager
    public static let shared = AIServiceManager()
    
    /// The current provider
    public var currentProvider: AIProvider = .openAI
    
    /// The configurations for each provider
    public var configurations: [AIProvider: AIServiceConfiguration] = [:]
    
    /// The current service
    public var currentService: AIService? {
        guard let configuration = configurations[currentProvider] else {
            return nil
        }
        
        return AIServiceFactory.createService(for: currentProvider, with: configuration)
    }
    
    /// The enabled features
    public var enabledFeatures: Set<AIFeature> = [.autoCompletion, .codeGeneration]
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Load initial settings from UserDefaults
        if let providerRawValue = UserDefaults.standard.string(forKey: "AICurrentProvider"),
           let provider = AIProvider(rawValue: providerRawValue) {
            currentProvider = provider
        }
        
        // Load enabled features from UserDefaults
        if let enabledFeatureRawValues = UserDefaults.standard.stringArray(forKey: "AIEnabledFeatures") {
            let features = enabledFeatureRawValues.compactMap { AIFeature(rawValue: $0) }
            enabledFeatures = Set(features)
        } else {
            // Default enabled features if none are saved
            enabledFeatures = [.autoCompletion, .codeGeneration]
        }
        
        // Load configurations from keychain
        loadConfigurations()
    }
    
    /// Loads configurations from secure storage
    public func loadConfigurations() {
        for provider in AIProvider.allCases {
            do {
                let configuration = try AIKeychainManager.shared.retrieveConfiguration(for: provider)
                configurations[provider] = configuration
            } catch {
                // If no configuration is found, create a default one
                if error is AIKeychainError {
                    let defaultConfig = AIServiceConfiguration(
                        apiKey: "",
                        baseURL: provider.defaultBaseURL,
                        model: getDefaultModel(for: provider),
                        useStreaming: true
                    )
                    configurations[provider] = defaultConfig
                }
            }
        }
    }
    
    /// Saves configurations to secure storage
    public func saveConfigurations() {
        for (provider, configuration) in configurations {
            do {
                try AIKeychainManager.shared.saveConfiguration(configuration, for: provider)
            } catch {
                print("Failed to save configuration for \(provider): \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the default model for a provider
    /// - Parameter provider: The provider to get the default model for
    /// - Returns: The default model for the provider
    private func getDefaultModel(for provider: AIProvider) -> String {
        switch provider {
        case .claude:
            return "claude-3-haiku-20240307"
        case .gemini:
            return "gemini-1.5-pro"
        case .openAI:
            return "gpt-3.5-turbo"
        case .custom:
            return "gpt-3.5-turbo"
        }
    }
    
    /// Sets the configuration for a provider
    /// - Parameters:
    ///   - configuration: The configuration to set
    ///   - provider: The provider to set the configuration for
    public func setConfiguration(_ configuration: AIServiceConfiguration, for provider: AIProvider) {
        configurations[provider] = configuration
        saveConfigurations()
    }
    
    /// Gets the configuration for a provider
    /// - Parameter provider: The provider to get the configuration for
    /// - Returns: The configuration for the provider, or nil if not set
    public func getConfiguration(for provider: AIProvider) -> AIServiceConfiguration? {
        return configurations[provider]
    }
    
    /// Sets the current provider
    /// - Parameter provider: The provider to set as current
    public func setCurrentProvider(_ provider: AIProvider) {
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "AICurrentProvider")
    }
    
    /// Toggles a feature on or off
    /// - Parameter feature: The feature to toggle
    public func toggleFeature(_ feature: AIFeature) {
        if enabledFeatures.contains(feature) {
            enabledFeatures.remove(feature)
        } else {
            enabledFeatures.insert(feature)
        }
        
        // Save to UserDefaults
        let enabledFeatureRawValues = enabledFeatures.map { $0.rawValue }
        UserDefaults.standard.set(enabledFeatureRawValues, forKey: "AIEnabledFeatures")
    }
    
    /// Checks if a feature is enabled
    /// - Parameter feature: The feature to check
    /// - Returns: Whether the feature is enabled
    public func isFeatureEnabled(_ feature: AIFeature) -> Bool {
        return enabledFeatures.contains(feature)
    }
}
