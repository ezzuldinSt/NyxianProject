//
//  ClaudeService.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation

/// Service implementation for Anthropic's Claude API
public class ClaudeService: AIService {
    /// The provider type
    public var provider: AIProvider = .claude
    
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
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307",
        "claude-2.1",
        "claude-2.0",
        "claude-instant-1.2"
    ]
    
    /// The default model for this provider
    public var defaultModel: String = "claude-3-haiku-20240307"
    
    /// The current URLSession task
    private var currentTask: URLSessionDataTask?
    
    /// The current streaming task
    private var currentStreamingTask: URLSessionDataTask?
    
    /// The streaming delegate
    private weak var streamingDelegate: AICompletionStreamDelegate?
    
    /// The streaming buffer
    private var streamingBuffer: String = ""
    
    /// Creates a new Claude service
    /// - Parameter configuration: The configuration for the service
    public init(configuration: AIServiceConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - API Structures
    
    /// Structure for Claude API message
    private struct ClaudeMessage: Codable {
        /// The role of the message sender
        let role: String
        
        /// The content of the message
        let content: String
    }
    
    /// Structure for Claude API completion request
    private struct ClaudeCompletionRequest: Codable {
        /// The model to use
        let model: String
        
        /// The messages to send
        let messages: [ClaudeMessage]
        
        /// The maximum number of tokens to generate
        let max_tokens: Int
        
        /// The temperature to use
        let temperature: Double
        
        /// Whether to stream the response
        let stream: Bool
        
        /// The system prompt (optional)
        let system: String?
        
        /// The stop sequences
        let stop_sequences: [String]?
        
        /// The top-p value
        let top_p: Double?
        
        /// The top-k value
        let top_k: Int?
        
        /// Additional metadata
        let metadata: [String: String]?
    }
    
    /// Structure for Claude API completion response
    private struct ClaudeCompletionResponse: Codable {
        /// The ID of the response
        let id: String
        
        /// The type of the response
        let type: String
        
        /// The role of the response
        let role: String
        
        /// The content of the response
        let content: [ContentBlock]
        
        /// The model used
        let model: String
        
        /// The stop reason
        let stop_reason: String?
        
        /// The stop sequence
        let stop_sequence: String?
        
        /// The usage statistics
        let usage: Usage
        
        /// Structure for a content block in the response
        struct ContentBlock: Codable {
            /// The type of content
            let type: String
            
            /// The text content
            let text: String
        }
        
        /// Structure for usage statistics
        struct Usage: Codable {
            /// The number of input tokens
            let input_tokens: Int
            
            /// The number of output tokens
            let output_tokens: Int
        }
    }
    
    /// Structure for Claude API streaming response
    private struct ClaudeStreamingResponse: Codable {
        /// The type of the response
        let type: String
        
        /// The delta content (for streaming)
        let delta: Delta?
        
        /// The usage statistics
        let usage: ClaudeCompletionResponse.Usage?
        
        /// Structure for delta content
        struct Delta: Codable {
            /// The type of the delta
            let type: String
            
            /// The text content
            let text: String?
        }
    }
    
    /// Structure for Claude API error response
    private struct APIErrorResponse: Codable {
        /// The error type
        let type: String
        
        /// The error message
        let message: String
        
        /// The error code
        let error_code: String?
        
        /// The error status
        let error_status: Int?
    }
    
    // MARK: - AIService Protocol Implementation
    
    /// Validates the API key for the service
    /// - Parameter completion: Callback with the result of the validation
    public func validateAPIKey(completion: @escaping (Result<Bool, AIServiceError>) -> Void) {
        // Create a minimal request to check if the API key is valid
        let messages = [
            ClaudeMessage(role: "user", content: "Hello")
        ]
        
        let request = ClaudeCompletionRequest(
            model: configuration.model,
            messages: messages,
            max_tokens: 5,
            temperature: 0.7,
            stream: false,
            system: "You are a helpful assistant.",
            stop_sequences: nil,
            top_p: nil,
            top_k: nil,
            metadata: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            completion(.failure(.parsingError))
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("anthropic-version", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        
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
                case 401:
                    // Unauthorized
                    completion(.failure(.invalidAPIKey))
                case 429:
                    // Rate limit exceeded
                    completion(.failure(.rateLimitExceeded))
                case 500...599:
                    // Server error
                    completion(.failure(.serviceUnavailable))
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        completion(.failure(.serviceError(errorResponse.message)))
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
        
        // Create the messages array and system prompt based on the feature
        let (messages, systemPrompt) = createMessagesAndSystemPrompt(for: request)
        
        // Create the Claude request
        let claudeRequest = ClaudeCompletionRequest(
            model: configuration.model,
            messages: messages,
            max_tokens: request.maxTokens,
            temperature: request.temperature,
            stream: false,
            system: systemPrompt,
            stop_sequences: ["```"],
            top_p: 0.95,
            top_k: nil,
            metadata: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(claudeRequest) else {
            completion(.failure(.parsingError))
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("anthropic-version", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        
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
                        let claudeResponse = try JSONDecoder().decode(ClaudeCompletionResponse.self, from: data)
                        
                        // Extract the completion text
                        let completionText = claudeResponse.content.first(where: { $0.type == "text" })?.text ?? ""
                        
                        // Create the AI completion response
                        let aiResponse = AICompletionResponse(
                            completion: completionText,
                            isTruncated: claudeResponse.stop_reason == "max_tokens",
                            tokensUsed: claudeResponse.usage.input_tokens + claudeResponse.usage.output_tokens,
                            additionalInfo: [
                                "model": claudeResponse.model,
                                "id": claudeResponse.id
                            ]
                        )
                        
                        completion(.success(aiResponse))
                    } catch {
                        completion(.failure(.parsingError))
                    }
                case 401:
                    // Unauthorized
                    completion(.failure(.invalidAPIKey))
                case 429:
                    // Rate limit exceeded
                    completion(.failure(.rateLimitExceeded))
                case 500...599:
                    // Server error
                    completion(.failure(.serviceUnavailable))
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        completion(.failure(.serviceError(errorResponse.message)))
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
        
        // Create the messages array and system prompt based on the feature
        let (messages, systemPrompt) = createMessagesAndSystemPrompt(for: request)
        
        // Create the Claude request
        let claudeRequest = ClaudeCompletionRequest(
            model: configuration.model,
            messages: messages,
            max_tokens: request.maxTokens,
            temperature: request.temperature,
            stream: true,
            system: systemPrompt,
            stop_sequences: ["```"],
            top_p: 0.95,
            top_k: nil,
            metadata: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(claudeRequest) else {
            delegate.didEncounterError(.parsingError)
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("anthropic-version", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        
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
                case 401:
                    // Unauthorized
                    self.streamingDelegate?.didEncounterError(.invalidAPIKey)
                case 429:
                    // Rate limit exceeded
                    self.streamingDelegate?.didEncounterError(.rateLimitExceeded)
                case 500...599:
                    // Server error
                    self.streamingDelegate?.didEncounterError(.serviceUnavailable)
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        self.streamingDelegate?.didEncounterError(.serviceError(errorResponse.message))
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
    
    /// Creates messages and system prompt for a completion request
    /// - Parameter request: The completion request
    /// - Returns: A tuple containing the messages array and system prompt
    private func createMessagesAndSystemPrompt(for request: AICompletionRequest) -> ([ClaudeMessage], String) {
        var messages: [ClaudeMessage] = []
        
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
        
        // Add context if available
        if let context = request.context, !context.isEmpty {
            messages.append(ClaudeMessage(role: "user", content: "Here is some context for my request:\n```\n\(context)\n```"))
            messages.append(ClaudeMessage(role: "assistant", content: "I've reviewed the context you provided."))
        }
        
        // Add project info if available
        if let projectInfo = request.projectInfo, !projectInfo.isEmpty {
            let projectInfoString = projectInfo.map { key, value in "\(key): \(value)" }.joined(separator: "\n")
            messages.append(ClaudeMessage(role: "user", content: "Here is information about my project:\n\(projectInfoString)"))
            messages.append(ClaudeMessage(role: "assistant", content: "I understand the project details you've shared."))
        }
        
        // Add the user prompt
        messages.append(ClaudeMessage(role: "user", content: request.prompt))
        
        return (messages, systemPrompt)
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
    
    /// Processes streaming data from the Claude API
    /// - Parameter data: The data to process
    private func processStreamingData(_ data: Data) {
        // Convert data to string
        guard let string = String(data: data, encoding: .utf8) else {
            streamingDelegate?.didEncounterError(.parsingError)
            return
        }
        
        // Split the string by newlines to get individual events
        let events = string.components(separatedBy: "\n\n")
        
        for event in events {
            // Skip empty events
            if event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Check if the event is data
            if event.hasPrefix("data: ") {
                let jsonString = event.dropFirst(6) // Remove "data: " prefix
                
                // Try to parse the event as JSON
                if let data = jsonString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(ClaudeStreamingResponse.self, from: data) {
                    
                    // Check if this is a content delta
                    if response.type == "content_block_delta" && response.delta?.type == "text" {
                        if let text = response.delta?.text {
                            // Append the text to the buffer
                            streamingBuffer += text
                            
                            // Notify the delegate
                            streamingDelegate?.didReceiveCompletionChunk(text)
                        }
                    }
                    
                    // Check if this is the end of the stream
                    if response.type == "message_stop" {
                        // Notify the delegate that streaming is complete
                        streamingDelegate?.didFinishCompletion()
                    }
                }
            }
        }
    }
}
