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
        label.textColor = UIColor.label // Fixed: Use UIColor.label
        label.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.8) // Fixed: Use appropriate system color
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
            let fittingSize = suggestionLabel.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            let buttonHeight: CGFloat = 30
            let padding: CGFloat = 8
            let totalHeight = fittingSize.height + buttonHeight + (padding * 3)
            frame = CGRect(x: rect.origin.x, y: rect.origin.y + rect.height, width: max(200, fittingSize.width + (padding * 2)), height: totalHeight)
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
        suggestionLabel.textColor = UIColor.label // Fixed
        suggestionLabel.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.8) // Fixed
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
    private var aiCompletionDebouncer: Coordinator.Debouncer? { // Coordinator.Debouncer is already internal
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
    
    /// Whether AI features are enabled (general check, specific features checked individually)
    private var aiFeaturesGenerallyEnabled: Bool {
        return !AIServiceManager.shared.enabledFeatures.isEmpty
    }
    
    /// Associated keys for objc_getAssociatedObject
    private struct AssociatedKeys {
        static var aiSuggestionOverlay = "aiSuggestionOverlay"
        static var aiCompletionDebouncer = "aiCompletionDebouncer"
        static var currentAICompletion = "currentAICompletion"
    }
    
    // MARK: - Setup
    
    /// Sets up AI integration for the code editor
    /// This method should be called from CodeEditorViewController's viewDidLoad
    public func setupAIIntegration() {
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
        // Accessing coordinator's debouncer if it's made accessible
        // Or create a new one if preferred for AI-specific timing
        if let coordinatorDebouncer = self.coordinator?.debounce {
             self.aiCompletionDebouncer = coordinatorDebouncer // Use coordinator's debouncer
        } else {
             self.aiCompletionDebouncer = Coordinator.Debouncer(delay: 0.5) // Or a new one
        }
        
        // Add keyboard shortcuts
        setupAIKeyboardShortcuts()
    }
    
    /// Sets up keyboard shortcuts for AI features
    private func setupAIKeyboardShortcuts() {
        // Add key command for accepting suggestion (Tab)
        let acceptCommand = UIKeyCommand(
            action: #selector(acceptAISuggestionKeyCommand),
            input: "\t", // Tab key
            modifierFlags: [] // No modifiers
        )
        if #available(iOS 15.0, *) {
            acceptCommand.wantsPriorityOverSystemBehavior = true
        }
        self.addKeyCommand(acceptCommand)
        
        // Add key command for rejecting suggestion (Escape)
        let rejectCommand = UIKeyCommand(
            action: #selector(rejectAISuggestionKeyCommand),
            input: UIKeyCommand.inputEscape, // Escape key
            modifierFlags: [] // No modifiers
        )
        if #available(iOS 15.0, *) {
            rejectCommand.wantsPriorityOverSystemBehavior = true
        }
        self.addKeyCommand(rejectCommand)
        
        // Add key command for generating code (Cmd+G)
        let generateCommand = UIKeyCommand(
            action: #selector(generateCodeKeyCommand),
            input: "g",
            modifierFlags: .command
        )
        self.addKeyCommand(generateCommand)
        
        // Add key command for explaining code (Cmd+E)
        let explainCommand = UIKeyCommand(
            action: #selector(explainCodeKeyCommand),
            input: "e",
            modifierFlags: .command
        )
        self.addKeyCommand(explainCommand)
        
        // Add key command for refactoring code (Cmd+Shift+R)
        let refactorCommand = UIKeyCommand(
            action: #selector(refactorCodeKeyCommand),
            input: "r",
            modifierFlags: [.command, .shift]
        )
        self.addKeyCommand(refactorCommand)
        
        // Add key command for generating documentation (Cmd+Shift+D)
        let documentCommand = UIKeyCommand(
            action: #selector(generateDocumentationKeyCommand),
            input: "d",
            modifierFlags: [.command, .shift]
        )
        self.addKeyCommand(documentCommand)
    }
    
    // MARK: - AI Completion
    
    /// Triggers AI completion based on the current text.
    /// This is called by Coordinator's textViewDidChange.
    public func triggerAICompletion() {
        guard AIServiceManager.shared.isFeatureEnabled(.autoCompletion),
              let aiCompletionDebouncer = aiCompletionDebouncer else { return }
        
        cancelAIRequests() // Cancel previous requests
        
        aiCompletionDebouncer.debounce { [weak self] in
            guard let self = self else { return }
            
            guard let text = self.getCurrentText(),
                  let cursorPosition = self.getCurrentCursorPosition() else {
                return
            }
            
            let context = self.extractContext(from: text, around: cursorPosition)
            
            DispatchQueue.main.async {
                self.aiSuggestionOverlay?.showLoading()
            }
            
            let request = AICompletionRequest(
                prompt: context,
                maxTokens: 100,
                temperature: 0.3,
                language: self.getLanguageForFile(),
                feature: .autoCompletion,
                context: self.getFileContext(),
                projectInfo: self.getProjectInfo()
            )
            
            guard let service = AIServiceManager.shared.currentService else {
                self.showAIError("No AI service configured. Please check your settings.")
                return
            }
            
            if let config = AIServiceManager.shared.getConfiguration(for: AIServiceManager.shared.currentProvider), config.useStreaming {
                service.getStreamingCompletion(for: request, delegate: self)
            } else {
                service.getCompletion(for: request) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let response):
                            self?.handleAICompletion(response.completion)
                        case .failure(let error):
                            self?.showAIError(error.localizedDescription)
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
        
        currentAICompletion = completion
        aiSuggestionOverlay?.showSuggestion(completion, at: textView.selectedTextRange?.end)
    }
    
    /// Accepts the current AI suggestion
    /// - Parameter suggestion: The suggestion to accept
    private func acceptAISuggestion(_ suggestion: String) {
        guard let selectedRange = textView.selectedTextRange else {
            aiSuggestionOverlay?.hide()
            return
        }
        
        textView.replace(selectedRange, withText: suggestion)
        aiSuggestionOverlay?.hide()
        currentAICompletion = nil
    }
    
    /// Rejects the current AI suggestion
    private func rejectAISuggestion() {
        aiSuggestionOverlay?.hide()
        currentAICompletion = nil
    }
    
    /// Cancels any ongoing AI requests
    func cancelAIRequests() {
        AIServiceManager.shared.currentService?.cancelCompletionRequests()
        aiSuggestionOverlay?.hide()
        currentAICompletion = nil
    }
    
    // MARK: - AI Features
    
    /// Generates code based on a comment or description
    @objc private func generateCode() {
        guard AIServiceManager.shared.isFeatureEnabled(.codeGeneration) else {
            showAIError("Code generation is not enabled. Please enable it in the AI settings.")
            return
        }
        
        guard let selectedText = getSelectedTextOrCurrentLine() else {
            return
        }
        
        aiSuggestionOverlay?.showLoading()
        
        let request = AICompletionRequest(
            prompt: selectedText,
            maxTokens: 500,
            temperature: 0.5,
            language: getLanguageForFile(),
            feature: .codeGeneration,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        service.getCompletion(for: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.handleGeneratedCode(response.completion, replacingSelection: true)
                case .failure(let error):
                    self?.showAIError(error.localizedDescription)
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
        
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to explain.")
            return
        }
        
        let alertController = UIAlertController(
            title: "Explain Code",
            message: "How would you like to see the explanation?",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "As Comment", style: .default) { [weak self] _ in
            self?.explainCodeAsComment(selectedText)
        })
        
        alertController.addAction(UIAlertAction(title: "In Popup", style: .default) { [weak self] _ in
            self?.explainCodeInPopup(selectedText)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alertController, animated: true)
    }
    
    /// Explains code as a comment
    /// - Parameter code: The code to explain
    private func explainCodeAsComment(_ code: String) {
        aiSuggestionOverlay?.showLoading()
        
        let request = AICompletionRequest(
            prompt: "Explain this code as a comment:\n\(code)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeExplanation,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        service.getCompletion(for: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let commentPrefix = self?.getCommentPrefixForLanguage() ?? "//"
                    let explanation = self?.formatAsComment(response.completion, prefix: commentPrefix) ?? response.completion
                    self?.insertTextBeforeSelection(explanation)
                    self?.aiSuggestionOverlay?.hide()
                case .failure(let error):
                    self?.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Explains code in a popup
    /// - Parameter code: The code to explain
    private func explainCodeInPopup(_ code: String) {
        aiSuggestionOverlay?.showLoading()
        
        let request = AICompletionRequest(
            prompt: "Explain this code in detail:\n\(code)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeExplanation,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        service.getCompletion(for: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.aiSuggestionOverlay?.hide()
                switch result {
                case .success(let response):
                    let alertController = UIAlertController(
                        title: "Code Explanation",
                        message: response.completion,
                        preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alertController, animated: true)
                case .failure(let error):
                    self?.showAIError(error.localizedDescription)
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
        
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to refactor.")
            return
        }
        
        aiSuggestionOverlay?.showLoading()
        
        let request = AICompletionRequest(
            prompt: "Refactor this code to improve its quality, maintainability, and performance:\n\(selectedText)",
            maxTokens: 1000,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .codeRefactoring,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        service.getCompletion(for: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.aiSuggestionOverlay?.hide() // Hide loading here
                switch result {
                case .success(let response):
                    self?.showRefactoredCodePreview(original: selectedText, refactored: response.completion)
                case .failure(let error):
                    self?.showAIError(error.localizedDescription)
                }
            }
        }
    }
    
    /// Shows a preview of refactored code
    /// - Parameters:
    ///   - original: The original code
    ///   - refactored: The refactored code
    private func showRefactoredCodePreview(original: String, refactored: String) {
        let previewVC = RefactorPreviewViewController(
            originalCode: original,
            refactoredCode: refactored,
            onApply: { [weak self] appliedCode in
                guard let self = self, let selectedRange = self.textView.selectedTextRange else { return }
                self.textView.replace(selectedRange, withText: appliedCode)
            }
        )
        let navController = UINavigationController(rootViewController: previewVC)
        self.present(navController, animated: true)
    }
    
    /// Generates documentation for the selected code
    @objc private func generateDocumentation() {
        guard AIServiceManager.shared.isFeatureEnabled(.docGeneration) else {
            showAIError("Documentation generation is not enabled. Please enable it in the AI settings.")
            return
        }
        
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showAIError("Please select some code to document.")
            return
        }
        
        aiSuggestionOverlay?.showLoading()
        
        let request = AICompletionRequest(
            prompt: "Generate documentation for this code:\n\(selectedText)",
            maxTokens: 500,
            temperature: 0.3,
            language: getLanguageForFile(),
            feature: .docGeneration,
            context: getFileContext(),
            projectInfo: getProjectInfo()
        )
        
        guard let service = AIServiceManager.shared.currentService else {
            showAIError("No AI service configured. Please check your settings.")
            return
        }
        
        service.getCompletion(for: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.handleGeneratedCode(response.completion, replacingSelection: true)
                case .failure(let error):
                    self?.showAIError(error.localizedDescription)
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
            textView.replace(selectedRange, withText: code)
            aiSuggestionOverlay?.hide()
        } else {
            aiSuggestionOverlay?.showSuggestion(code, at: textView.selectedTextRange?.end)
        }
    }
    
    // MARK: - Key Commands
    
    /// Accepts the AI suggestion via keyboard shortcut
    @objc private func acceptAISuggestionKeyCommand() {
        guard let currentAICompletion = currentAICompletion, let overlay = aiSuggestionOverlay, !overlay.isHidden else {
            return
        }
        acceptAISuggestion(currentAICompletion)
    }
    
    /// Rejects the AI suggestion via keyboard shortcut
    @objc private func rejectAISuggestionKeyCommand() {
        guard let overlay = aiSuggestionOverlay, !overlay.isHidden else {
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
        let beforeCursor = String(text.prefix(position))
        let lines = beforeCursor.components(separatedBy: .newlines)
        let currentLine = lines.last ?? ""
        let previousLines = Array(lines.dropLast().suffix(5))
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
        guard let selectedRange = textView.selectedTextRange, !selectedRange.isEmpty else { // Ensure range is not empty
            return nil
        }
        return textView.text(in: selectedRange)
    }
    
    /// Gets the selected text or current line
    /// - Returns: The selected text or current line
    private func getSelectedTextOrCurrentLine() -> String? {
        if let selectedText = getSelectedText(), !selectedText.isEmpty {
            return selectedText
        }
        guard let text = getCurrentText(), let cursorPosition = getCurrentCursorPosition() else {
            return nil
        }
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPosition, length: 0))
        return nsText.substring(with: lineRange)
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
        case "c": return "C"
        case "m", "h": return "Objective-C" // Group .h with .m for iOS context
        case "cpp", "cc", "cxx": return "C++"
        case "mm": return "Objective-C++"
        case "swift": return "Swift"
        case "js": return "JavaScript"
        case "py": return "Python"
        case "java": return "Java"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "xml", "plist": return "XML"
        default: return fileExtension
        }
    }
    
    /// Gets the comment prefix for the current language
    /// - Returns: The comment prefix
    private func getCommentPrefixForLanguage() -> String {
        let language = getLanguageForFile()
        switch language {
        case "C", "Objective-C", "Objective-C++", "C++", "Swift", "Java", "JavaScript": return "//"
        case "Python": return "#"
        case "HTML", "XML": return "<!--"
        case "CSS": return "/*"
        default: return "//"
        }
    }
    
    /// Formats text as a comment
    /// - Parameters:
    ///   - text: The text to format
    ///   - prefix: The comment prefix
    /// - Returns: The formatted comment
    private func formatAsComment(_ text: String, prefix: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let suffix: String
        switch prefix {
        case "<!--": suffix = " -->"
        case "/*": suffix = " */"
        default: suffix = ""
        }
        if lines.count == 1 {
            return "\(prefix) \(lines[0])\(suffix)\n"
        }
        let commentedLines = lines.map { "\(prefix) \($0)" }
        return commentedLines.joined(separator: "\n") + "\n"
    }
    
    /// Inserts text before the selection
    /// - Parameter text: The text to insert
    private func insertTextBeforeSelection(_ text: String) {
        guard let selectedRange = textView.selectedTextRange else { return }
        let start = selectedRange.start // UITextPosition is not optional
        let emptyRange = textView.textRange(from: start, to: start)!
        textView.replace(emptyRange, withText: text)
    }
    
    /// Shows an AI error
    /// - Parameter message: The error message
    private func showAIError(_ message: String) {
        aiSuggestionOverlay?.hide()
        let alertController = UIAlertController(title: "AI Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
    // MARK: - AICompletionStreamDelegate
    
    public func didReceiveCompletionChunk(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newCompletion = (self.currentAICompletion ?? "") + text
            self.currentAICompletion = newCompletion
            self.aiSuggestionOverlay?.showSuggestion(newCompletion, at: self.textView.selectedTextRange?.end)
        }
    }
    
    public func didFinishCompletion() {
        // Handled by continuous updates in didReceiveCompletionChunk
    }
    
    public func didEncounterError(_ error: AIServiceError) {
        DispatchQueue.main.async { [weak self] in
            self?.showAIError(error.localizedDescription)
        }
    }
}

// MARK: - Refactor Preview View Controller
private class RefactorPreviewViewController: UIViewController {
    private let originalCode: String
    private let refactoredCode: String
    private let onApply: (String) -> Void

    private lazy var originalTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.text = originalCode
        tv.layer.borderColor = UIColor.systemGray.cgColor
        tv.layer.borderWidth = 1
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var refactoredTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false // Or true if you want to allow edits before applying
        tv.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.text = refactoredCode
        tv.layer.borderColor = UIColor.systemGray.cgColor
        tv.layer.borderWidth = 1
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    init(originalCode: String, refactoredCode: String, onApply: @escaping (String) -> Void) {
        self.originalCode = originalCode
        self.refactoredCode = refactoredCode
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Refactor Preview"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissPreview))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(applyRefactoring))

        let originalLabel = UILabel()
        originalLabel.text = "Original Code:"
        originalLabel.font = .preferredFont(forTextStyle: .headline)
        originalLabel.translatesAutoresizingMaskIntoConstraints = false

        let refactoredLabel = UILabel()
        refactoredLabel.text = "Refactored Code:"
        refactoredLabel.font = .preferredFont(forTextStyle: .headline)
        refactoredLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [originalLabel, originalTextView, refactoredLabel, refactoredTextView])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            originalTextView.heightAnchor.constraint(equalTo: refactoredTextView.heightAnchor)
        ])
    }

    @objc private func dismissPreview() {
        dismiss(animated: true)
    }

    @objc private func applyRefactoring() {
        onApply(refactoredTextView.text)
        dismiss(animated: true)
    }
}
