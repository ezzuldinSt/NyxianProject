//
//  CodeEditorAIIntegration.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import UIKit
import Runestone

// MARK: - AI Suggestion Overlay

/// A view that displays AI suggestions over the text editor
class AISuggestionOverlay: UIView {
    
    // MARK: - Properties
    
    /// The text view that the overlay is attached to
    private weak var textView: TextView?
    
    /// The suggestion label
    private let suggestionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.systemGray
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// The accept button
    private let acceptButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Accept (Tab)", for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// The reject button
    private let rejectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dismiss (Esc)", for: .normal)
        button.backgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// The loading indicator
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    /// The current suggestion
    private var currentSuggestion: String = ""
    
    /// The current position
    private var currentPosition: UITextPosition?
    
    /// Callback when the suggestion is accepted
    var onAccept: ((String) -> Void)?
    
    /// Callback when the suggestion is rejected
    var onReject: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new AI suggestion overlay
    /// - Parameter textView: The text view to attach to
    init(textView: TextView) {
        self.textView = textView
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    /// Sets up the view
    private func setupView() {
        backgroundColor = UIColor.clear
        
        // Add suggestion label
        addSubview(suggestionLabel)
        
        // Add buttons
        addSubview(acceptButton)
        addSubview(rejectButton)
        
        // Add loading indicator
        addSubview(loadingIndicator)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            suggestionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            suggestionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            suggestionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            acceptButton.topAnchor.constraint(equalTo: suggestionLabel.bottomAnchor, constant: 8),
            acceptButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            acceptButton.heightAnchor.constraint(equalToConstant: 30),
            
            rejectButton.topAnchor.constraint(equalTo: suggestionLabel.bottomAnchor, constant: 8),
            rejectButton.leadingAnchor.constraint(equalTo: acceptButton.trailingAnchor, constant: 8),
            rejectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rejectButton.heightAnchor.constraint(equalToConstant: 30),
            rejectButton.widthAnchor.constraint(equalTo: acceptButton.widthAnchor),
            rejectButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Add button actions
        acceptButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onAccept?(self.currentSuggestion)
        }, for: .touchUpInside)
        
        rejectButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onReject?()
        }, for: .touchUpInside)
        
        // Initially hide the overlay
        isHidden = true
    }
    
    // MARK: - Public Methods
    
    /// Shows the overlay with a loading indicator
    func showLoading() {
        suggestionLabel.text = ""
        suggestionLabel.isHidden = true
        acceptButton.isHidden = true
        rejectButton.isHidden = true
        loadingIndicator.startAnimating()
        isHidden = false
    }
    
    /// Shows the overlay with a suggestion
    /// - Parameters:
    ///   - suggestion: The suggestion to display
    ///   - position: The position to display at
    func showSuggestion(_ suggestion: String, at position: UITextPosition?) {
        currentSuggestion = suggestion
        currentPosition = position
        
        suggestionLabel.text = suggestion
        suggestionLabel.isHidden = false
        acceptButton.isHidden = false
        rejectButton.isHidden = false
        loadingIndicator.stopAnimating()
        isHidden = false
        
        // Position the overlay near the cursor
        if let position = position, let textView = textView {
            let rect = textView.caretRect(for: position)
            frame = CGRect(x: rect.origin.x, y: rect.origin.y + rect.height, width: 300, height: 150)
        }
    }
    
    /// Hides the overlay
    func hide() {
        isHidden = true
        loadingIndicator.stopAnimating()
    }
    
    /// Updates the theme of the overlay
    /// - Parameter theme: The theme to use
    func updateTheme(theme: Theme) {
        suggestionLabel.font = theme.font
        suggestionLabel.textColor = theme.foregroundColor
        suggestionLabel.backgroundColor = theme.backgroundColor.withAlphaComponent(0.7)
    }
}

// MARK: - CodeEditorViewController AI Extension

extension CodeEditorViewController: AICompletionStreamDelegate {
    
    // MARK: - Properties
    
    /// The AI suggestion overlay
    private var aiSuggestionOverlay: AISuggestionOverlay? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.aiSuggestionOverlay) as? AISuggestionOverlay
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.aiSuggestionOverlay, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// The AI completion debouncer
    private var aiCompletionDebouncer: Coordinator.Debouncer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.aiCompletionDebouncer) as? Coordinator.Debouncer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.aiCompletionDebouncer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// The current AI completion
    private var currentAICompletion: String? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentAICompletion) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentAICompletion, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Whether AI features are enabled
    private var aiEnabled: Bool {
        get {
            return AIServiceManager.shared.isFeatureEnabled(.autoCompletion)
        }
    }
    
    /// Associated keys for objc_getAssociatedObject
    private struct AssociatedKeys {
        static var aiSuggestionOverlay = "aiSuggestionOverlay"
        static var aiCompletionDebouncer = "aiCompletionDebouncer"
        static var currentAICompletion = "currentAICompletion"
    }
    
    // MARK: - Setup
    
    /// Sets up AI integration for the code editor
    func setupAIIntegration() {
        // Create the suggestion overlay
        let overlay = AISuggestionOverlay(textView: self.textView)
        overlay.updateTheme(theme: self.textView.theme)
        self.view.addSubview(overlay)
        self.aiSuggestionOverlay = overlay
        
        // Set up callbacks
        overlay.onAccept = { [weak self] suggestion in
            self?.acceptAISuggestion(suggestion)
        }
        
        overlay.onReject = { [weak self] in
            self?.rejectAISuggestion()
        }
        
        // Set up debouncer for auto-completion
        self.aiCompletionDebouncer = Coordinator.Debouncer(delay: 0.5)
        
        // Add keyboard shortcuts
        setupAIKeyboardShortcuts()
        
        // Hook into text changes
        setupAITextChangeHook()
    }
    
    /// Sets up keyboard shortcuts for AI features
    private func setupAIKeyboardShortcuts() {
        // Add key command for accepting suggestion (Tab)
        let acceptCommand = UIKeyCommand(
            input: "\t",
            modifierFlags: [],
            action: #selector(acceptAISuggestionKeyCommand),
            discoverabilityTitle: "Accept AI Suggestion"
        )
        acceptCommand.wantsPriorityOverSystemBehavior = true
        self.addKeyCommand(acceptCommand)
        
        // Add key command for rejecting suggestion (Escape)
        let rejectCommand = UIKeyCommand(
            input: UIKeyCommand.inputEscape,
            modifierFlags: [],
            action: #selector(rejectAISuggestionKeyCommand),
            discoverabilityTitle: "Reject AI Suggestion"
        )
        rejectCommand.wantsPriorityOverSystemBehavior = true
        self.addKeyCommand(rejectCommand)
        
        // Add key command for generating code (Cmd+G)
        let generateCommand = UIKeyCommand(
            input: "g",
            modifierFlags: .command,
            action: #selector(generateCodeKeyCommand),
            discoverabilityTitle: "Generate Code"
        )
        self.addKeyCommand(generateCommand)
        
        // Add key command for explaining code (Cmd+E)
        let explainCommand = UIKeyCommand(
            input: "e",
            modifierFlags: .command,
            action: #selector(explainCodeKeyCommand),
            discoverabilityTitle: "Explain Code"
        )
        self.addKeyCommand(explainCommand)
        
        // Add key command for refactoring code (Cmd+R)
        let refactorCommand = UIKeyCommand(
            input: "r",
            modifierFlags: [.command, .shift],
            action: #selector(refactorCodeKeyCommand),
            discoverabilityTitle: "Refactor Code"
        )
        self.addKeyCommand(refactorCommand)
        
        // Add key command for generating documentation (Cmd+D)
        let documentCommand = UIKeyCommand(
            input: "d",
            modifierFlags: [.command, .shift],
            action: #selector(generateDocumentationKeyCommand),
            discoverabilityTitle: "Generate Documentation"
        )
        self.addKeyCommand(documentCommand)
    }
    
    /// Sets up a hook for text changes to trigger AI completion
    private func setupAITextChangeHook() {
        // This is a bit of a hack, but we need to hook into the text changes
        // to trigger AI completion. We'll use method swizzling to do this.
        
        // Get the original method
        let originalSelector = #selector(Coordinator.textViewDidChange(_:))
        let swizzledSelector = #selector(Coordinator.swizzled_textViewDidChange(_:))
        
        // Get the method implementations
        guard let originalMethod = class_getInstanceMethod(Coordinator.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Coordinator.self, swizzledSelector) else {
            return
        }
        
        // Add the swizzled method to the class
        let didAddMethod = class_addMethod(
            Coordinator.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        // If the method was added, replace the original implementation
        if didAddMethod {
            class_replaceMethod(
                Coordinator.self,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            // Otherwise, just exchange the implementations
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    // MARK: - AI Completion
    
    /// Triggers AI completion based on the current text
    func triggerAICompletion() {
        guard aiEnabled, let aiCompletionDebouncer = aiCompletionDebouncer else { return }
        
        // Cancel any ongoing requests
        cancelAIRequests()
        
        // Debounce the completion request
        aiCompletionDebouncer.debounce { [weak self] in
            guard let self = self else { return }
            
            // Get the current text and cursor position
            guard let text = self.getCurrentText(),
                  let cursorPosition = self.getCurrentCursorPosition() else {
                return
            }
            
            // Extract context around the cursor
            let context = self.extractContext(from: text, around: cursorPosition)
            
            // Show the loading indicator
            DispatchQueue.main.async {
                self.aiSuggestionOverlay?.showLoading()
            }
            
            // Create the completion request
            let request = AICompletionRequest(
                prompt: context,
                maxTokens: 100,
                temperature: 0.3,
                language: self.getLanguageForFile(),
                feature: .autoCompletion,
                context: self.getFileContext(),
                projectInfo: self.getProjectInfo()
            )
            
            // Get the current service
            guard let service = AIServiceManager.shared.currentService else {
                self.showAIError("No AI service configured. Please check your settings.")
                return
            }
            
            // Check if streaming is enabled
            if let config = AIServiceManager.shared.getConfiguration(for: AIServiceManager.shared.currentProvider),
               config.useStreaming {
                // Use streaming completion
                service.getStreamingCompletion(for: request, delegate: self)
            } else {
                // Use regular completion
                service.getCompletion(for: request) { [weak self] result in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let response):
                            self.handleAICompletion(response.completion)
                        case .failure(let error):
                            self.showAIError(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    /// Handles an AI completion
    /// - Parameter completion: The completion text
    private func handleAICompletion(_ completion: String) {
        guard !completion.isEmpty else {
            aiSuggestionOverlay?.hide()
            return
        }
        
        // Store the completion
        currentAICompletion = completion
        
        // Show the suggestion
        aiSuggestionOverlay?.showSuggestion(completion, at: textView.selectedTextRange?.end)
    }
    
    /// Accepts the current AI suggestion
    /// - Parameter suggestion: The suggestion to accept
    private func acceptAISuggestion(_ suggestion: String) {
        guard let selectedRange = textView.selectedTextRange else {
            aiSuggestionOverlay?.hide()
            return
        }
        
        // Insert the suggestion
        textView.replace(selectedRange, withText: suggestion)
        
        // Hide the overlay
        aiSuggestionOverlay?.hide()
        
        // Clear the current completion
        currentAICompletion = nil
    }
    
    /// Rejects the current AI suggestion
    private func rejectAISuggestion() {
        // Hide the overlay
        aiSuggestionOverlay?.hide()
        
        // Clear the current completion
        currentAICompletion = nil
    }
    
    /// Cancels any ongoing AI requests
    func cancelAIRequests() {
        // Cancel any ongoing requests
        AIServiceManager.shared.currentService?.cancelCompletionRequests()
        
        // Hide the overlay
        aiSuggestionOverlay?.hide()
        
        // Clear the current completion
        currentAICompletion = nil
    }
    
    // MARK: - AI Features
    
    /// Generates code based on a comment or description
    @objc private func generateCode() {
        guard AIServiceManager.shared.isFeatureEnabled(.codeGeneration) else {
            showAIError("Code generation is not enabled. Please enable it in the AI settings.")
            return
        }
        
        // Get the selected text or current line
        guard let selectedText = getSelectedTextOrCurrentLine() else {
            return
        }
        
        // Show the loading indicator
        aiSuggestionOverlay?.showLoading()
        
        // Create the completion request
        let request = AICompletionRequest(
            prompt: selectedText,
            maxTokens: 500,
            temperature: 0.5,
            language: getLanguageForFile(),
            feature: .codeGeneration,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        // Get the current service
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        // Use regular completion for code generation
        service.getCompletion(for: request) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.handleGeneratedCode(response.completion, replacingSelection: true)
                case .failure(let error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Explains the selected code
    @objc private func explainCode() {
        guard AIServiceManager.shared.isFeatureEnabled(.codeExplanation) else {
            showAIError("Code explanation is not enabled. Please enable it in the AI settings.")
            return
        }
        
        // Get the selected text
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to explain.")
            return
        }
        
        // Show alert to ask where to show the explanation
        let alertController = UIAlertController(
            title: "Explain Code",
            message: "How would you like to see the explanation?",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "As Comment", style: .default) { [weak self] _ in
            self?.explainCodeAsComment(selectedText)
        })
        
        alertController.addAction(UIAlertAction(title: "In Popup", style: .default) { [weak self] _ in
            self?.explainCodeInPopup(selectedText)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    /// Explains code as a comment
    /// - Parameter code: The code to explain
    private func explainCodeAsComment(_ code: String) {
        // Show the loading indicator
        aiSuggestionOverlay?.showLoading()
        
        // Create the completion request
        let request = AICompletionRequest(
            prompt: "Explain this code as a comment:\n\(code)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeExplanation,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        // Get the current service
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        // Use regular completion for code explanation
        service.getCompletion(for: request) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Format the explanation as a comment
                    let commentPrefix = self.getCommentPrefixForLanguage()
                    let explanation = self.formatAsComment(response.completion, prefix: commentPrefix)
                    
                    // Insert the explanation before the selected code
                    self.insertTextBeforeSelection(explanation)
                    
                    // Hide the overlay
                    self.aiSuggestionOverlay?.hide()
                    
                case .failure(let error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Explains code in a popup
    /// - Parameter code: The code to explain
    private func explainCodeInPopup(_ code: String) {
        // Show the loading indicator
        aiSuggestionOverlay?.showLoading()
        
        // Create the completion request
        let request = AICompletionRequest(
            prompt: "Explain this code in detail:\n\(code)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeExplanation,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        // Get the current service
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        // Use regular completion for code explanation
        service.getCompletion(for: request) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Hide the overlay
                self.aiSuggestionOverlay?.hide()
                
                switch result {
                case .success(let response):
                    // Show the explanation in a popup
                    let alertController = UIAlertController(
                        title: "Code Explanation",
                        message: response.completion,
                        preferredStyle: .alert
                    )
                    
                    alertController.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    self.present(alertController, animated: true)
                    
                case .failure(let error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Refactors the selected code
    @objc private func refactorCode() {
        guard AIServiceManager.shared.isFeatureEnabled(.codeRefactoring) else {
            showAIError("Code refactoring is not enabled. Please enable it in the AI settings.")
            return
        }
        
        // Get the selected text
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to refactor.")
            return
        }
        
        // Show the loading indicator
        aiSuggestionOverlay?.showLoading()
        
        // Create the completion request
        let request = AICompletionRequest(
            prompt: "Refactor this code to improve its quality, maintainability, and performance:\n\(selectedText)",
            maxTokens: 1000,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeRefactoring,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        // Get the current service
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        // Use regular completion for code refactoring
        service.getCompletion(for: request) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Show a preview of the refactored code
                    self.showRefactoredCodePreview(original: selectedText, refactored: response.completion)
                case .failure(let error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Shows a preview of refactored code
    /// - Parameters:
    ///   - original: The original code
    ///   - refactored: The refactored code
    private func showRefactoredCodePreview(original: String, refactored: String) {
        // Hide the overlay
        aiSuggestionOverlay?.hide()
        
        // Create a view controller to show the preview
        let previewVC = UIViewController()
        previewVC.title = "Refactored Code Preview"
        
        // Create a text view to show the refactored code
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.text = refactored
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the text view to the view controller
        previewVC.view.addSubview(textView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: previewVC.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: previewVC.view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: previewVC.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Add buttons to accept or reject the refactoring
        let acceptButton = UIBarButtonItem(title: "Apply", style: .done, target: nil, action: nil)
        acceptButton.action = #selector(previewVC.acceptRefactoring)
        
        let rejectButton = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
        rejectButton.action = #selector(previewVC.dismissVC)
        
        previewVC.navigationItem.rightBarButtonItem = acceptButton
        previewVC.navigationItem.leftBarButtonItem = rejectButton
        
        // Store the original and refactored code
        objc_setAssociatedObject(previewVC, &AssociatedKeys.currentAICompletion, refactored, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Add methods to the view controller
        let acceptMethod = class_getInstanceMethod(self.classForCoder, #selector(acceptRefactoredCode(_:)))!
        let acceptImp = method_getImplementation(acceptMethod)
        class_addMethod(previewVC.classForCoder, #selector(previewVC.acceptRefactoring), acceptImp, method_getTypeEncoding(acceptMethod))
        
        let dismissMethod = class_getInstanceMethod(self.classForCoder, #selector(dismissViewController(_:)))!
        let dismissImp = method_getImplementation(dismissMethod)
        class_addMethod(previewVC.classForCoder, #selector(previewVC.dismissVC), dismissImp, method_getTypeEncoding(dismissMethod))
        
        // Present the preview
        let navController = UINavigationController(rootViewController: previewVC)
        self.present(navController, animated: true)
    }
    
    /// Accepts refactored code
    /// - Parameter sender: The sender of the action
    @objc private func acceptRefactoredCode(_ sender: Any) {
        guard let viewController = sender as? UIViewController,
              let refactoredCode = objc_getAssociatedObject(viewController, &AssociatedKeys.currentAICompletion) as? String,
              let selectedRange = textView.selectedTextRange else {
            return
        }
        
        // Replace the selected text with the refactored code
        textView.replace(selectedRange, withText: refactoredCode)
        
        // Dismiss the preview
        viewController.dismiss(animated: true)
    }
    
    /// Dismisses a view controller
    /// - Parameter sender: The sender of the action
    @objc private func dismissViewController(_ sender: Any) {
        guard let viewController = sender as? UIViewController else {
            return
        }
        
        viewController.dismiss(animated: true)
    }
    
    /// Generates documentation for the selected code
    @objc private func generateDocumentation() {
        guard AIServiceManager.shared.isFeatureEnabled(.docGeneration) else {
            showAIError("Documentation generation is not enabled. Please enable it in the AI settings.")
            return
        }
        
        // Get the selected text
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to document.")
            return
        }
        
        // Show the loading indicator
        aiSuggestionOverlay?.showLoading()
        
        // Create the completion request
        let request = AICompletionRequest(
            prompt: "Generate documentation for this code:\n\(selectedText)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .docGeneration,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        // Get the current service
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        // Use regular completion for documentation generation
        service.getCompletion(for: request) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Replace the selected code with the documented code
                    self.handleGeneratedCode(response.completion, replacingSelection: true)
                case .failure(let error):
                    self.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Handles generated code
    /// - Parameters:
    ///   - code: The generated code
    ///   - replacingSelection: Whether to replace the selection
    private func handleGeneratedCode(_ code: String, replacingSelection: Bool) {
        guard !code.isEmpty else {
            aiSuggestionOverlay?.hide()
            return
        }
        
        if replacingSelection, let selectedRange = textView.selectedTextRange {
            // Replace the selected text with the generated code
            textView.replace(selectedRange, withText: code)
            
            // Hide the overlay
            aiSuggestionOverlay?.hide()
        } else {
            // Show the generated code as a suggestion
            aiSuggestionOverlay?.showSuggestion(code, at: textView.selectedTextRange?.end)
        }
    }
    
    // MARK: - Key Commands
    
    /// Accepts the AI suggestion via keyboard shortcut
    @objc private func acceptAISuggestionKeyCommand() {
        guard let currentAICompletion = currentAICompletion, !aiSuggestionOverlay!.isHidden else {
            return
        }
        
        acceptAISuggestion(currentAICompletion)
    }
    
    /// Rejects the AI suggestion via keyboard shortcut
    @objc private func rejectAISuggestionKeyCommand() {
        guard !aiSuggestionOverlay!.isHidden else {
            return
        }
        
        rejectAISuggestion()
    }
    
    /// Generates code via keyboard shortcut
    @objc private func generateCodeKeyCommand() {
        generateCode()
    }
    
    /// Explains code via keyboard shortcut
    @objc private func explainCodeKeyCommand() {
        explainCode()
    }
    
    /// Refactors code via keyboard shortcut
    @objc private func refactorCodeKeyCommand() {
        refactorCode()
    }
    
    /// Generates documentation via keyboard shortcut
    @objc private func generateDocumentationKeyCommand() {
        generateDocumentation()
    }
    
    // MARK: - Helper Methods
    
    /// Gets the current text
    /// - Returns: The current text
    private func getCurrentText() -> String? {
        return textView.text
    }
    
    /// Gets the current cursor position
    /// - Returns: The current cursor position
    private func getCurrentCursorPosition() -> Int? {
        guard let selectedRange = textView.selectedTextRange else {
            return nil
        }
        
        return textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
    }
    
    /// Extracts context around a position
    /// - Parameters:
    ///   - text: The text to extract from
    ///   - position: The position to extract around
    /// - Returns: The extracted context
    private func extractContext(from text: String, around position: Int) -> String {
        // Get the text before the cursor
        let beforeCursor = String(text.prefix(position))
        
        // Get the current line and previous lines
        let lines = beforeCursor.components(separatedBy: .newlines)
        let currentLine = lines.last ?? ""
        
        // Get the previous few lines for context
        let previousLines = Array(lines.dropLast().suffix(5))
        
        // Combine the context
        var context = previousLines.joined(separator: "\n")
        if !context.isEmpty {
            context += "\n"
        }
        context += currentLine
        
        return context
    }
    
    /// Gets the selected text
    /// - Returns: The selected text
    private func getSelectedText() -> String? {
        guard let selectedRange = textView.selectedTextRange else {
            return nil
        }
        
        return textView.text(in: selectedRange)
    }
    
    /// Gets the selected text or current line
    /// - Returns: The selected text or current line
    private func getSelectedTextOrCurrentLine() -> String? {
        // If there's selected text, use that
        if let selectedText = getSelectedText(), !selectedText.isEmpty {
            return selectedText
        }
        
        // Otherwise, get the current line
        guard let text = getCurrentText(),
              let cursorPosition = getCurrentCursorPosition() else {
            return nil
        }
        
        // Get the text before the cursor
        let beforeCursor = String(text.prefix(cursorPosition))
        
        // Get the current line
        let lines = beforeCursor.components(separatedBy: .newlines)
        let currentLine = lines.last ?? ""
        
        return currentLine
    }
    
    /// Gets the file context
    /// - Returns: The file context
    private func getFileContext() -> String? {
        return textView.text
    }
    
    /// Gets the project info
    /// - Returns: The project info
    private func getProjectInfo() -> [String: String]? {
        guard let project = project else {
            return nil
        }
        
        return [
            "projectName": project.projectConfig.executable,
            "bundleId": project.projectConfig.bundleid,
            "filePath": path
        ]
    }
    
    /// Gets the language for the current file
    /// - Returns: The language
    private func getLanguageForFile() -> String {
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        switch fileExtension {
        case "c":
            return "C"
        case "m":
            return "Objective-C"
        case "h":
            return "Objective-C"
        case "cpp", "cc", "cxx":
            return "C++"
        case "mm":
            return "Objective-C++"
        case "swift":
            return "Swift"
        case "js":
            return "JavaScript"
        case "py":
            return "Python"
        case "java":
            return "Java"
        case "html":
            return "HTML"
        case "css":
            return "CSS"
        case "json":
            return "JSON"
        case "xml", "plist":
            return "XML"
        default:
            return fileExtension
        }
    }
    
    /// Gets the comment prefix for the current language
    /// - Returns: The comment prefix
    private func getCommentPrefixForLanguage() -> String {
        let language = getLanguageForFile()
        
        switch language {
        case "C", "Objective-C", "Objective-C++", "C++", "Swift", "Java", "JavaScript":
            return "//"
        case "Python":
            return "#"
        case "HTML", "XML":
            return "<!-- "
        case "CSS":
            return "/* "
        default:
            return "//"
        }
    }
    
    /// Formats text as a comment
    /// - Parameters:
    ///   - text: The text to format
    ///   - prefix: The comment prefix
    /// - Returns: The formatted comment
    private func formatAsComment(_ text: String, prefix: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let commentedLines = lines.map { "\(prefix) \($0)" }
        return commentedLines.joined(separator: "\n") + "\n"
    }
    
    /// Inserts text before the selection
    /// - Parameter text: The text to insert
    private func insertTextBeforeSelection(_ text: String) {
        guard let selectedRange = textView.selectedTextRange,
              let start = selectedRange.start else {
            return
        }
        
        // Create a range at the start of the selection
        let emptyRange = textView.textRange(from: start, to: start)!
        
        // Insert the text
        textView.replace(emptyRange, withText: text)
    }
    
    /// Shows an AI error
    /// - Parameter message: The error message
    private func showAIError(_ message: String) {
        // Hide the overlay
        aiSuggestionOverlay?.hide()
        
        // Show an alert
        let alertController = UIAlertController(
            title: "AI Error",
            message: message,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alertController, animated: true)
    }
    
    // MARK: - AICompletionStreamDelegate
    
    /// Called when a chunk of completion text is received
    /// - Parameter text: The new chunk of text
    public func didReceiveCompletionChunk(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Append the chunk to the current completion
            let newCompletion = (self.currentAICompletion ?? "") + text
            self.currentAICompletion = newCompletion
            
            // Update the suggestion overlay
            self.aiSuggestionOverlay?.showSuggestion(newCompletion, at: self.textView.selectedTextRange?.end)
        }
    }
    
    /// Called when the completion stream has ended
    public func didFinishCompletion() {
        // Nothing to do here, the completion is already displayed
    }
    
    /// Called when an error occurs during streaming
    /// - Parameter error: The error that occurred
    public func didEncounterError(_ error: AIServiceError) {
        DispatchQueue.main.async { [weak self] in
            self?.showAIError(error.localizedDescription)
        }
    }
}

// MARK: - Coordinator Extension for Method Swizzling

extension Coordinator {
    
    /// Swizzled version of textViewDidChange
    /// - Parameter textView: The text view that changed
    @objc func swizzled_textViewDidChange(_ textView: TextView) {
        // Call the original implementation
        self.swizzled_textViewDidChange(textView)
        
        // Trigger AI completion
        if let parent = self.parent as? CodeEditorViewController {
            parent.triggerAICompletion()
        }
    }
}

// MARK: - UIViewController Extension for Method Swizzling

extension UIViewController {
    
    /// Swizzled version of viewDidLoad
    @objc func swizzled_viewDidLoad() {
        // Call the original implementation
        self.swizzled_viewDidLoad()
        
        // Set up AI integration if this is a CodeEditorViewController
        if let codeEditorVC = self as? CodeEditorViewController {
            codeEditorVC.setupAIIntegration()
        }
    }
}

// MARK: - Load Method Swizzling

/// Loads method swizzling for AI integration
@objc public class AIIntegrationLoader: NSObject {
    
    /// Loads the AI integration
    @objc public static func load() {
        // Swizzle viewDidLoad
        let originalSelector = #selector(UIViewController.viewDidLoad)
        let swizzledSelector = #selector(UIViewController.swizzled_viewDidLoad)
        
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }
        
        // Add the swizzled method to the class
        let didAddMethod = class_addMethod(
            UIViewController.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        // If the method was added, replace the original implementation
        if didAddMethod {
            class_replaceMethod(
                UIViewController.self,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            // Otherwise, just exchange the implementations
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}
