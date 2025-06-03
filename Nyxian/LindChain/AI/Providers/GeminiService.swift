//
//  GeminiService.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation

/// Service implementation for Google's Gemini API
public class GeminiService: AIService {
    /// The provider type
    public var provider: AIProvider = .gemini
    
    /// The configuration for the service
    public var configuration: AIServiceConfiguration
    
    /// The features supported by this provider
    public var supportedFeatures: [AIFeature] = [
        .autoCompletion,
        .codeGeneration,
        .codeExplanation,
        .codeRefactoring,
        .docGeneration
    ]
    
    /// The available models for this provider
    public var availableModels: [String] = [
        "gemini-pro",
        "gemini-pro-vision",
        "gemini-1.5-pro",
        "gemini-1.5-flash"
    ]
    
    /// The default model for this provider
    public var defaultModel: String = "gemini-1.5-pro"
    
    /// The current URLSession task
    private var currentTask: URLSessionDataTask?
    
    /// The current streaming task
    private var currentStreamingTask: URLSessionDataTask?
    
    /// The streaming delegate
    private weak var streamingDelegate: AICompletionStreamDelegate?
    
    /// The streaming buffer
    private var streamingBuffer: String = ""
    
    /// The API version to use
    private let apiVersion: String = "v1"
    
    /// Creates a new Gemini service
    /// - Parameter configuration: The configuration for the service
    public init(configuration: AIServiceConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - API Structures
    
    /// Structure for Gemini API content part
    private struct ContentPart: Codable {
        /// The text content
        let text: String?
        
        /// Creates a new content part with text
        /// - Parameter text: The text content
        static func text(_ text: String) -> ContentPart {
            return ContentPart(text: text)
        }
    }
    
    /// Structure for Gemini API content
    private struct Content: Codable {
        /// The role of the message sender
        let role: String?
        
        /// The parts of the content
        let parts: [ContentPart]
    }
    
    /// Structure for Gemini API generation config
    private struct GenerationConfig: Codable {
        /// The temperature to use
        let temperature: Double?
        
        /// The top-p value
        let topP: Double?
        
        /// The top-k value
        let topK: Int?
        
        /// The maximum output tokens
        let maxOutputTokens: Int?
        
        /// The stop sequences
        let stopSequences: [String]?
    }
    
    /// Structure for Gemini API safety settings
    private struct SafetySetting: Codable {
        /// The category of the safety setting
        let category: String
        
        /// The threshold for the safety setting
        let threshold: String
    }
    
    /// Structure for Gemini API request
    private struct GeminiRequest: Codable {
        /// The contents of the request
        let contents: [Content]
        
        /// The generation config
        let generationConfig: GenerationConfig?
        
        /// The safety settings
        let safetySettings: [SafetySetting]?
    }
    
    /// Structure for Gemini API streaming request
    private struct GeminiStreamRequest: Codable {
        /// The contents of the request
        let contents: [Content]
        
        /// The generation config
        let generationConfig: GenerationConfig?
        
        /// The safety settings
        let safetySettings: [SafetySetting]?
        
        /// Whether to stream the response
        let stream: Bool
    }
    
    /// Structure for Gemini API candidate
    private struct Candidate: Codable {
        /// The content of the candidate
        let content: Content?
        
        /// The finish reason
        let finishReason: String?
        
        /// The safety ratings
        let safetyRatings: [SafetyRating]?
        
        /// The token count
        let tokenCount: Int?
    }
    
    /// Structure for Gemini API safety rating
    private struct SafetyRating: Codable {
        /// The category of the safety rating
        let category: String
        
        /// The probability of the safety rating
        let probability: String
    }
    
    /// Structure for Gemini API prompt feedback
    private struct PromptFeedback: Codable {
        /// The safety ratings
        let safetyRatings: [SafetyRating]?
    }
    
    /// Structure for Gemini API usage metadata
    private struct UsageMetadata: Codable {
        /// The prompt token count
        let promptTokenCount: Int
        
        /// The candidate token count
        let candidateTokenCount: Int
        
        /// The total token count
        let totalTokenCount: Int
    }
    
    /// Structure for Gemini API response
    private struct GeminiResponse: Codable {
        /// The candidates in the response
        let candidates: [Candidate]?
        
        /// The prompt feedback
        let promptFeedback: PromptFeedback?
        
        /// The usage metadata
        let usageMetadata: UsageMetadata?
    }
    
    /// Structure for Gemini API error
    private struct GeminiError: Codable {
        /// The error details
        let error: ErrorDetails
        
        /// Structure for error details
        struct ErrorDetails: Codable {
            /// The error code
            let code: Int
            
            /// The error message
            let message: String
            
            /// The error status
            let status: String
        }
    }
    
    // MARK: - AIService Protocol Implementation
    
    /// Validates the API key for the service
    /// - Parameter completion: Callback with the result of the validation
    public func validateAPIKey(completion: @escaping (Result<Bool, AIServiceError>) -> Void) {
        // Create a minimal request to check if the API key is valid
        let content = Content(
            role: "user",
            parts: [ContentPart.text("Hello")]
        )
        
        let generationConfig = GenerationConfig(
            temperature: 0.7,
            topP: nil,
            topK: nil,
            maxOutputTokens: 5,
            stopSequences: nil
        )
        
        let request = GeminiRequest(
            contents: [content],
            generationConfig: generationConfig,
            safetySettings: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            completion(.failure(.parsingError))
            return
        }
        
        let modelName = configuration.model.replacingOccurrences(of: ".", with: "-")
        let url = URL(string: "\(configuration.baseURL)/\(apiVersion)/models/\(modelName):generateContent?key=\(configuration.apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 10
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            // Handle network errors
            if let error = error {
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        completion(.failure(.timeout))
                    case .notConnectedToInternet:
                        completion(.failure(.serviceUnavailable))
                    default:
                        completion(.failure(.requestFailed(error)))
                    }
                } else {
                    completion(.failure(.requestFailed(error)))
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success
                    completion(.success(true))
                case 400:
                    // Bad request - likely invalid API key or model
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        if errorResponse.error.message.contains("API key") {
                            completion(.failure(.invalidAPIKey))
                        } else {
                            completion(.failure(.serviceError(errorResponse.error.message)))
                        }
                    } else {
                        completion(.failure(.invalidAPIKey))
                    }
                case 401:
                    // Unauthorized
                    completion(.failure(.invalidAPIKey))
                case 403:
                    // Forbidden - API key doesn't have access to this model
                    completion(.failure(.unauthorized))
                case 429:
                    // Rate limit exceeded
                    completion(.failure(.rateLimitExceeded))
                case 500...599:
                    // Server error
                    completion(.failure(.serviceUnavailable))
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        completion(.failure(.serviceError(errorResponse.error.message)))
                    } else {
                        completion(.failure(.serviceError("Unknown error with status code: \(httpResponse.statusCode)")))
                    }
                }
            } else {
                completion(.failure(.serviceError("Invalid response from server")))
            }
        }
        
        task.resume()
    }
    
    /// Gets a completion for the given request
    /// - Parameters:
    ///   - request: The completion request
    ///   - completion: Callback with the result of the completion
    public func getCompletion(for request: AICompletionRequest, completion: @escaping (Result<AICompletionResponse, AIServiceError>) -> Void) {
        // Cancel any existing task
        cancelCompletionRequests()
        
        // Create the contents array based on the feature
        let contents = createContents(for: request)
        
        // Create the generation config
        let generationConfig = GenerationConfig(
            temperature: request.temperature,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: request.maxTokens,
            stopSequences: ["```"]
        )
        
        // Create the Gemini request
        let geminiRequest = GeminiRequest(
            contents: contents,
            generationConfig: generationConfig,
            safetySettings: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(geminiRequest) else {
            completion(.failure(.parsingError))
            return
        }
        
        let modelName = configuration.model.replacingOccurrences(of: ".", with: "-")
        let url = URL(string: "\(configuration.baseURL)/\(apiVersion)/models/\(modelName):generateContent?key=\(configuration.apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 30
        
        currentTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard self != nil else { return }
            
            // Handle network errors
            if let error = error {
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        completion(.failure(.timeout))
                    case .notConnectedToInternet:
                        completion(.failure(.serviceUnavailable))
                    case .cancelled:
                        // Request was cancelled, don't call completion
                        return
                    default:
                        completion(.failure(.requestFailed(error)))
                    }
                } else {
                    completion(.failure(.requestFailed(error)))
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success, parse the response
                    guard let data = data else {
                        completion(.failure(.parsingError))
                        return
                    }
                    
                    do {
                        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                        
                        // Extract the completion text
                        guard let firstCandidate = geminiResponse.candidates?.first,
                              let content = firstCandidate.content,
                              let firstPart = content.parts.first,
                              let text = firstPart.text else {
                            completion(.failure(.parsingError))
                            return
                        }
                        
                        // Create the AI completion response
                        let aiResponse = AICompletionResponse(
                            completion: text,
                            isTruncated: firstCandidate.finishReason == "MAX_TOKENS",
                            tokensUsed: geminiResponse.usageMetadata?.totalTokenCount,
                            additionalInfo: [
                                "model": modelName,
                                "tokenCount": firstCandidate.tokenCount ?? 0
                            ] as [String : Any]
                        )
                        
                        completion(.success(aiResponse))
                    } catch {
                        completion(.failure(.parsingError))
                    }
                case 400:
                    // Bad request
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        completion(.failure(.serviceError(errorResponse.error.message)))
                    } else {
                        completion(.failure(.serviceError("Bad request")))
                    }
                case 401:
                    // Unauthorized
                    completion(.failure(.invalidAPIKey))
                case 403:
                    // Forbidden
                    completion(.failure(.unauthorized))
                case 429:
                    // Rate limit exceeded
                    completion(.failure(.rateLimitExceeded))
                case 500...599:
                    // Server error
                    completion(.failure(.serviceUnavailable))
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        completion(.failure(.serviceError(errorResponse.error.message)))
                    } else {
                        completion(.failure(.serviceError("Unknown error with status code: \(httpResponse.statusCode)")))
                    }
                }
            } else {
                completion(.failure(.serviceError("Invalid response from server")))
            }
        }
        
        currentTask?.resume()
    }
    
    /// Gets a streaming completion for the given request
    /// - Parameters:
    ///   - request: The completion request
    ///   - delegate: The delegate to receive streaming updates
    public func getStreamingCompletion(for request: AICompletionRequest, delegate: AICompletionStreamDelegate) {
        // Cancel any existing task
        cancelCompletionRequests()
        
        // Store the delegate
        self.streamingDelegate = delegate
        
        // Reset the streaming buffer
        self.streamingBuffer = ""
        
        // Create the contents array based on the feature
        let contents = createContents(for: request)
        
        // Create the generation config
        let generationConfig = GenerationConfig(
            temperature: request.temperature,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: request.maxTokens,
            stopSequences: ["```"]
        )
        
        // Create the Gemini streaming request
        let geminiRequest = GeminiStreamRequest(
            contents: contents,
            generationConfig: generationConfig,
            safetySettings: nil,
            stream: true
        )
        
        guard let requestData = try? JSONEncoder().encode(geminiRequest) else {
            delegate.didEncounterError(.parsingError)
            return
        }
        
        let modelName = configuration.model.replacingOccurrences(of: ".", with: "-")
        let url = URL(string: "\(configuration.baseURL)/\(apiVersion)/models/\(modelName):streamGenerateContent?key=\(configuration.apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 60
        
        currentStreamingTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        self.streamingDelegate?.didEncounterError(.timeout)
                    case .notConnectedToInternet:
                        self.streamingDelegate?.didEncounterError(.serviceUnavailable)
                    case .cancelled:
                        // Request was cancelled, don't call delegate
                        return
                    default:
                        self.streamingDelegate?.didEncounterError(.requestFailed(error))
                    }
                } else {
                    self.streamingDelegate?.didEncounterError(.requestFailed(error))
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success, parse the response
                    guard let data = data else {
                        self.streamingDelegate?.didEncounterError(.parsingError)
                        return
                    }
                    
                    // Process the streaming data
                    self.processStreamingData(data)
                    
                    // Signal completion
                    self.streamingDelegate?.didFinishCompletion()
                case 400:
                    // Bad request
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        self.streamingDelegate?.didEncounterError(.serviceError(errorResponse.error.message))
                    } else {
                        self.streamingDelegate?.didEncounterError(.serviceError("Bad request"))
                    }
                case 401:
                    // Unauthorized
                    self.streamingDelegate?.didEncounterError(.invalidAPIKey)
                case 403:
                    // Forbidden
                    self.streamingDelegate?.didEncounterError(.unauthorized)
                case 429:
                    // Rate limit exceeded
                    self.streamingDelegate?.didEncounterError(.rateLimitExceeded)
                case 500...599:
                    // Server error
                    self.streamingDelegate?.didEncounterError(.serviceUnavailable)
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                        self.streamingDelegate?.didEncounterError(.serviceError(errorResponse.error.message))
                    } else {
                        self.streamingDelegate?.didEncounterError(.serviceError("Unknown error with status code: \(httpResponse.statusCode)"))
                    }
                }
            } else {
                self.streamingDelegate?.didEncounterError(.serviceError("Invalid response from server"))
            }
        }
        
        currentStreamingTask?.resume()
    }
    
    /// Cancels any ongoing completion requests
    public func cancelCompletionRequests() {
        currentTask?.cancel()
        currentTask = nil
        
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
    }
    
    // MARK: - Helper Methods
    
    /// Creates contents for a completion request
    /// - Parameter request: The completion request
    /// - Returns: An array of content objects
    private func createContents(for request: AICompletionRequest) -> [Content] {
        var contents: [Content] = []
        
        // Create system prompt based on the feature
        let systemPrompt: String
        switch request.feature {
        case .autoCompletion:
            systemPrompt = createAutoCompletionSystemPrompt(language: request.language)
        case .codeGeneration:
            systemPrompt = createCodeGenerationSystemPrompt(language: request.language)
        case .codeExplanation:
            systemPrompt = createCodeExplanationSystemPrompt(language: request.language)
        case .codeRefactoring:
            systemPrompt = createCodeRefactoringSystemPrompt(language: request.language)
        case .docGeneration:
            systemPrompt = createDocGenerationSystemPrompt(language: request.language)
        }
        
        // Add system prompt
        contents.append(Content(
            role: "system",
            parts: [ContentPart.text(systemPrompt)]
        ))
        
        // Add context if available
        if let context = request.context, !context.isEmpty {
            contents.append(Content(
                role: "user",
                parts: [ContentPart.text("Here is some context for my request:\n```\n\(context)\n```")]
            ))
            
            contents.append(Content(
                role: "model",
                parts: [ContentPart.text("I've reviewed the context you provided.")]
            ))
        }
        
        // Add project info if available
        if let projectInfo = request.projectInfo, !projectInfo.isEmpty {
            let projectInfoString = projectInfo.map { key, value in "\(key): \(value)" }.joined(separator: "\n")
            contents.append(Content(
                role: "user",
                parts: [ContentPart.text("Here is information about my project:\n\(projectInfoString)")]
            ))
            
            contents.append(Content(
                role: "model",
                parts: [ContentPart.text("I understand the project details you've shared.")]
            ))
        }
        
        // Add the user prompt
        contents.append(Content(
            role: "user",
            parts: [ContentPart.text(request.prompt)]
        ))
        
        return contents
    }
    
    /// Creates a system prompt for auto completion
    /// - Parameter language: The language to create the prompt for
    /// - Returns: The system prompt
    private func createAutoCompletionSystemPrompt(language: String) -> String {
        return """
        You are an expert \(language) programmer assistant that specializes in auto-completing code.
        
        Guidelines:
        1. Only generate the code that would complete what the user is typing
        2. Do not include explanations or comments unless they are part of the completion
        3. Do not repeat code that the user has already written
        4. Understand the context and intent of the code to provide relevant completions
        5. Follow best practices and conventions for \(language)
        6. Keep completions concise and focused on the immediate next steps
        7. Prioritize completions that are syntactically correct and would compile
        8. Respect the coding style evident in the existing code
        
        The user will provide code that needs to be completed. Respond only with the completion, not the entire code.
        """
    }
    
    /// Creates a system prompt for code generation
    /// - Parameter language: The language to create the prompt for
    /// - Returns: The system prompt
    private func createCodeGenerationSystemPrompt(language: String) -> String {
        return """
        You are an expert \(language) programmer assistant that specializes in generating code.
        
        Guidelines:
        1. Generate complete, working code based on the user's requirements
        2. Include helpful comments to explain complex logic
        3. Follow best practices and conventions for \(language)
        4. Optimize for readability and maintainability
        5. Consider edge cases and include appropriate error handling
        6. Respect any constraints or specific requirements mentioned by the user
        7. Provide code that is secure and free from common vulnerabilities
        8. If the user's request is ambiguous, generate the most likely implementation
        
        The user will provide a description of what they want to implement. Respond with complete, working code.
        """
    }
    
    /// Creates a system prompt for code explanation
    /// - Parameter language: The language to create the prompt for
    /// - Returns: The system prompt
    private func createCodeExplanationSystemPrompt(language: String) -> String {
        return """
        You are an expert \(language) programmer assistant that specializes in explaining code.
        
        Guidelines:
        1. Provide clear, concise explanations of what the code does
        2. Break down complex logic into understandable components
        3. Highlight any potential issues, bugs, or inefficiencies
        4. Explain the purpose and functionality of each section
        5. Use simple language while maintaining technical accuracy
        6. Point out any best practices or anti-patterns present in the code
        7. Explain any language-specific features or idioms used
        8. Focus on helping the user understand the code thoroughly
        
        The user will provide code that they want explained. Respond with a detailed explanation.
        """
    }
    
    /// Creates a system prompt for code refactoring
    /// - Parameter language: The language to create the prompt for
    /// - Returns: The system prompt
    private func createCodeRefactoringSystemPrompt(language: String) -> String {
        return """
        You are an expert \(language) programmer assistant that specializes in refactoring code.
        
        Guidelines:
        1. Improve the code while preserving its functionality
        2. Apply design patterns and best practices appropriate for \(language)
        3. Enhance readability, maintainability, and performance
        4. Remove code smells, redundancies, and unnecessary complexity
        5. Optimize algorithms and data structures where appropriate
        6. Improve error handling and edge case management
        7. Ensure the refactored code is well-structured and follows conventions
        8. Explain the key improvements made in your refactoring
        
        The user will provide code that needs refactoring. Respond with the refactored code and a brief explanation of the improvements.
        """
    }
    
    /// Creates a system prompt for documentation generation
    /// - Parameter language: The language to create the prompt for
    /// - Returns: The system prompt
    private func createDocGenerationSystemPrompt(language: String) -> String {
        return """
        You are an expert \(language) programmer assistant that specializes in generating documentation.
        
        Guidelines:
        1. Create comprehensive documentation that follows standard conventions for \(language)
        2. Document function parameters, return values, and thrown exceptions
        3. Include clear descriptions of what each component does
        4. Add usage examples where appropriate
        5. Document any assumptions or constraints
        6. Ensure documentation is accurate and aligned with the code
        7. Use a consistent style throughout the documentation
        8. Focus on information that would be helpful to other developers
        
        The user will provide code that needs documentation. Respond with the properly documented code.
        """
    }
    
    /// Processes streaming data from the Gemini API
    /// - Parameter data: The data to process
    private func processStreamingData(_ data: Data) {
        // Convert data to string
        guard let string = String(data: data, encoding: .utf8) else {
            streamingDelegate?.didEncounterError(.parsingError)
            return
        }
        
        // Split the string by newlines to get individual chunks
        let chunks = string.components(separatedBy: "\n")
        
        for chunk in chunks {
            // Skip empty chunks
            if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Try to parse the chunk as JSON
            if let data = chunk.data(using: .utf8),
               let response = try? JSONDecoder().decode(GeminiResponse.self, from: data),
               let candidates = response.candidates,
               let firstCandidate = candidates.first,
               let content = firstCandidate.content,
               let firstPart = content.parts.first,
               let text = firstPart.text {
                
                // Append the text to the buffer
                streamingBuffer += text
                
                // Notify the delegate
                streamingDelegate?.didReceiveCompletionChunk(text)
                
                // Check if this is the end of the stream
                if firstCandidate.finishReason != nil {
                    // Notify the delegate that streaming is complete
                    streamingDelegate?.didFinishCompletion()
                }
            }
        }
    }
}
