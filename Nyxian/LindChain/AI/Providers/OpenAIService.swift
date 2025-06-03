//
//  OpenAIService.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation

/// Service implementation for OpenAI and compatible APIs
public class OpenAIService: AIService {
    /// The provider type
    public var provider: AIProvider = .openAI
    
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
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo",
        "gpt-3.5-turbo-16k",
        // Common Claude models that might be used via a compatible API
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307"
    ]
    
    /// The default model for this provider
    public var defaultModel: String = "gpt-3.5-turbo"
    
    /// The current URLSession task
    private var currentTask: URLSessionDataTask?
    
    /// The current streaming task
    private var currentStreamingTask: URLSessionDataTask?
    
    /// The streaming delegate
    private weak var streamingDelegate: AICompletionStreamDelegate?
    
    /// The streaming buffer
    private var streamingBuffer: String = ""
    
    /// Creates a new OpenAI service
    /// - Parameter configuration: The configuration for the service
    public init(configuration: AIServiceConfiguration) {
        self.configuration = configuration
        
        // Set the provider based on the base URL, useful for custom OpenAI-compatible endpoints
        if configuration.baseURL.contains("anthropic.com") {
            self.provider = .claude // Or a specific custom type if distinguished
        } else if configuration.baseURL.contains("googleapis.com") {
            self.provider = .gemini // Or a specific custom type
        } else if configuration.baseURL != AIProvider.openAI.defaultBaseURL { // Check against default OpenAI URL
            self.provider = .custom
        } else {
            self.provider = .openAI
        }
    }
    
    // MARK: - API Structures
    
    /// Structure for OpenAI API chat message
    private struct ChatMessage: Codable {
        /// The role of the message sender
        let role: String
        
        /// The content of the message
        let content: String? // Changed to String? to handle null content in streaming deltas
    }
    
    /// Structure for OpenAI API chat completion request
    private struct ChatCompletionRequest: Codable {
        /// The model to use
        let model: String
        
        /// The messages to send
        let messages: [ChatMessage]
        
        /// The temperature to use
        let temperature: Double
        
        /// The maximum number of tokens to generate
        let max_tokens: Int
        
        /// Whether to stream the response
        let stream: Bool
        
        /// The stop sequences
        let stop: [String]?
        
        /// Additional parameters
        var additional_parameters: [String: String]? // For custom parameters
    }
    
    /// Structure for OpenAI API chat completion response
    private struct ChatCompletionResponse: Codable {
        /// The ID of the response
        let id: String
        
        /// The object type
        let object: String
        
        /// The timestamp of the response
        let created: Int
        
        /// The model used
        let model: String
        
        /// The choices returned
        let choices: [Choice]
        
        /// The usage statistics
        let usage: Usage?
        
        /// Structure for a choice in the response
        struct Choice: Codable {
            /// The index of the choice
            let index: Int
            
            /// The message in the choice
            let message: ChatMessage?
            
            /// The delta in the choice (for streaming)
            let delta: ChatMessage?
            
            /// The finish reason
            let finish_reason: String?
        }
        
        /// Structure for usage statistics
        struct Usage: Codable {
            /// The number of prompt tokens
            let prompt_tokens: Int
            
            /// The number of completion tokens
            let completion_tokens: Int
            
            /// The total number of tokens
            let total_tokens: Int
        }
    }
    
    /// Structure for OpenAI API error response
    private struct APIErrorResponse: Codable {
        /// The error details
        let error: ErrorDetails
        
        /// Structure for error details
        struct ErrorDetails: Codable {
            /// The error message
            let message: String
            
            /// The error type
            let type: String?
            
            /// The error code
            let code: String?
        }
    }
    
    // MARK: - AIService Protocol Implementation
    
    /// Validates the API key for the service
    /// - Parameter completion: Callback with the result of the validation
    public func validateAPIKey(completion: @escaping (Result<Bool, AIServiceError>) -> Void) {
        // Create a minimal request to check if the API key is valid
        let messages = [
            ChatMessage(role: "system", content: "You are a helpful assistant."),
            ChatMessage(role: "user", content: "Hello")
        ]
        
        let request = ChatCompletionRequest(
            model: configuration.model, // Use configured model
            messages: messages,
            temperature: 0.7,
            max_tokens: 5,
            stream: false,
            stop: nil
        )
        
        guard let requestData = try? JSONEncoder().encode(request) else {
            completion(.failure(.parsingError))
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add organization ID if provided
        if let organizationID = configuration.organizationID, !organizationID.isEmpty {
            urlRequest.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 10 // Short timeout for validation
        
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
        
        // Create the messages array based on the feature
        let messages = createMessages(for: request)
        
        // Create the OpenAI request
        let openAIRequest = ChatCompletionRequest(
            model: configuration.model,
            messages: messages,
            temperature: request.temperature,
            max_tokens: request.maxTokens,
            stream: false, // Not streaming for this method
            stop: ["```"], // Common stop sequence for code
            additional_parameters: configuration.additionalParameters
        )
        
        guard let requestData = try? JSONEncoder().encode(openAIRequest) else {
            completion(.failure(.parsingError))
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add organization ID if provided
        if let organizationID = configuration.organizationID, !organizationID.isEmpty {
            urlRequest.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 30 // Longer timeout for actual requests
        
        currentTask = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard self != nil else { return } // Ensure self is still around
            
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
                        let openAIResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                        
                        // Extract the completion text
                        guard let firstChoice = openAIResponse.choices.first,
                              let message = firstChoice.message else {
                            completion(.failure(.parsingError))
                            return
                        }
                        
                        // Create the AI completion response
                        let aiResponse = AICompletionResponse(
                            completion: message.content ?? "", // Handle optional content
                            isTruncated: firstChoice.finish_reason == "length",
                            tokensUsed: openAIResponse.usage?.total_tokens,
                            additionalInfo: [
                                "model": openAIResponse.model,
                                "id": openAIResponse.id
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
        
        // Create the messages array based on the feature
        let messages = createMessages(for: request)
        
        // Create the OpenAI request
        let openAIRequest = ChatCompletionRequest(
            model: configuration.model,
            messages: messages,
            temperature: request.temperature,
            max_tokens: request.maxTokens,
            stream: true, // Enable streaming
            stop: ["```"],
            additional_parameters: configuration.additionalParameters
        )
        
        guard let requestData = try? JSONEncoder().encode(openAIRequest) else {
            delegate.didEncounterError(.parsingError)
            return
        }
        
        let url = URL(string: "\(configuration.baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Add organization ID if provided
        if let organizationID = configuration.organizationID, !organizationID.isEmpty {
            urlRequest.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Add additional headers if provided
        configuration.additionalHeaders?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set timeout
        urlRequest.timeoutInterval = 60 // Longer timeout for streaming
        
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
                    
                    // Signal completion (Note: OpenAI stream might not have a single "finish" event in the same way,
                    // rely on finish_reason in delta or [DONE] marker)
                    // The didFinishCompletion might be called multiple times if not handled carefully,
                    // or after the last chunk is processed.
                    // For OpenAI, the [DONE] marker is the primary indicator.
                    
                case 401:
                    // Unauthorized
                    self.streamingDelegate?.didEncounterError(.invalidAPIKey)
                    self.streamingDelegate?.didFinishCompletion() // Ensure delegate is notified of finish
                case 429:
                    // Rate limit exceeded
                    self.streamingDelegate?.didEncounterError(.rateLimitExceeded)
                    self.streamingDelegate?.didFinishCompletion()
                case 500...599:
                    // Server error
                    self.streamingDelegate?.didEncounterError(.serviceUnavailable)
                    self.streamingDelegate?.didFinishCompletion()
                default:
                    // Parse error response if available
                    if let data = data,
                       let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        self.streamingDelegate?.didEncounterError(.serviceError(errorResponse.error.message))
                    } else {
                        // Corrected line:
                        self.streamingDelegate?.didEncounterError(.serviceError("Unknown error with status code: \(httpResponse.statusCode)"))
                    }
                    self.streamingDelegate?.didFinishCompletion()
                }
            } else {
                self.streamingDelegate?.didEncounterError(.serviceError("Invalid response from server"))
                self.streamingDelegate?.didFinishCompletion()
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
    
    /// Creates messages for a completion request
    /// - Parameter request: The completion request
    /// - Returns: An array of chat messages
    private func createMessages(for request: AICompletionRequest) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        // Add system message based on the feature
        switch request.feature {
        case .autoCompletion:
            messages.append(ChatMessage(role: "system", content: createAutoCompletionSystemPrompt(language: request.language)))
        case .codeGeneration:
            messages.append(ChatMessage(role: "system", content: createCodeGenerationSystemPrompt(language: request.language)))
        case .codeExplanation:
            messages.append(ChatMessage(role: "system", content: createCodeExplanationSystemPrompt(language: request.language)))
        case .codeRefactoring:
            messages.append(ChatMessage(role: "system", content: createCodeRefactoringSystemPrompt(language: request.language)))
        case .docGeneration:
            messages.append(ChatMessage(role: "system", content: createDocGenerationSystemPrompt(language: request.language)))
        }
        
        // Add context if available
        if let context = request.context, !context.isEmpty {
            messages.append(ChatMessage(role: "user", content: "Here is some context for my request:\n```\n\(context)\n```"))
        }
        
        // Add project info if available
        if let projectInfo = request.projectInfo, !projectInfo.isEmpty {
            let projectInfoString = projectInfo.map { key, value in "\(key): \(value)" }.joined(separator: "\n")
            messages.append(ChatMessage(role: "user", content: "Here is information about my project:\n\(projectInfoString)"))
        }
        
        // Add the user prompt
        messages.append(ChatMessage(role: "user", content: request.prompt))
        
        return messages
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
    
    /// Processes streaming data from the OpenAI API
    /// - Parameter data: The data to process
    private func processStreamingData(_ data: Data) {
        // Convert data to string
        guard let string = String(data: data, encoding: .utf8) else {
            streamingDelegate?.didEncounterError(.parsingError)
            streamingDelegate?.didFinishCompletion() // Ensure finish is called on error
            return
        }
        
        // Split the string by "data: " to get individual chunks
        // OpenAI streaming responses are typically newline-separated JSON objects prefixed with "data: "
        let eventStrings = string.components(separatedBy: "\n").filter { !$0.isEmpty }

        for eventString in eventStrings {
            if eventString.hasPrefix("data: ") {
                let jsonString = String(eventString.dropFirst(6)) // Remove "data: "
                
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    streamingDelegate?.didFinishCompletion()
                    return // Stream is finished
                }
                
                // Try to parse the chunk as JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(ChatCompletionResponse.self, from: jsonData),
                   let choice = response.choices.first,
                   let delta = choice.delta,
                   let content = delta.content { // This will now correctly unwrap the optional content
                    
                    // Append the content to the buffer
                    streamingBuffer += content
                    
                    // Notify the delegate
                    streamingDelegate?.didReceiveCompletionChunk(content)

                    // Check for finish reason in delta (though [DONE] is more reliable for OpenAI)
                    if choice.finish_reason != nil {
                         streamingDelegate?.didFinishCompletion()
                         return
                    }
                }
            }
        }
    }
}
