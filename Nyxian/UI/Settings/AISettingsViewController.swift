//
//  AISettingsViewController.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import UIKit
import Foundation

/// View controller for AI settings
class AISettingsViewController: UITableViewController {
    
    // MARK: - Properties
    
    /// The sections in the table view
    enum Section: Int, CaseIterable {
        case provider
        case configuration
        case features
        case actions
        
        /// The title for the section
        var title: String {
            switch self {
            case .provider:
                return "AI Provider"
            case .configuration:
                return "Configuration"
            case .features:
                return "Features"
            case .actions:
                return "Actions"
            }
        }
    }
    
    /// The rows in the provider section
    enum ProviderRow: Int, CaseIterable {
        case selection
    }
    
    /// The rows in the configuration section
    enum ConfigurationRow: Int, CaseIterable {
        case apiKey
        case model
        case streaming
        case advancedSettings
        
        /// The title for the row
        var title: String {
            switch self {
            case .apiKey:
                return "API Key"
            case .model:
                return "Model"
            case .streaming:
                return "Use Streaming"
            case .advancedSettings:
                return "Advanced Settings"
            }
        }
    }
    
    /// The rows in the actions section
    enum ActionRow: Int, CaseIterable {
        case validate
        case importExport
        case clearSettings
        
        /// The title for the row
        var title: String {
            switch self {
            case .validate:
                return "Validate API Key"
            case .importExport:
                return "Import/Export Settings"
            case .clearSettings:
                return "Clear AI Settings"
            }
        }
    }
    
    /// The current provider
    private var currentProvider: AIProvider {
        get {
            return AIServiceManager.shared.currentProvider
        }
        set {
            AIServiceManager.shared.setCurrentProvider(newValue)
        }
    }
    
    /// The current configuration
    private var currentConfiguration: AIServiceConfiguration? {
        get {
            return AIServiceManager.shared.getConfiguration(for: currentProvider)
        }
        set {
            if let newValue = newValue {
                AIServiceManager.shared.setConfiguration(newValue, for: currentProvider)
            }
        }
    }
    
    /// The enabled features
    private var enabledFeatures: Set<AIFeature> {
        get {
            return AIServiceManager.shared.enabledFeatures
        }
        set {
            AIServiceManager.shared.enabledFeatures = newValue
        }
    }
    
    // Strong references to text field delegates to prevent deallocation
    private var textFieldDelegates: [UITextField: TextFieldDelegateWithCallback] = [:]
    
    /// The activity indicator
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "AI Settings"
        self.tableView.rowHeight = 44
        
        // Add activity indicator to navigation bar
        let barButton = UIBarButtonItem(customView: activityIndicator)
        navigationItem.rightBarButtonItem = barButton
        
        // Register cell classes
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload the table view to reflect any changes
        self.tableView.reloadData()
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .provider:
            return ProviderRow.allCases.count
        case .configuration:
            return ConfigurationRow.allCases.count
        case .features:
            return AIFeature.allCases.count
        case .actions:
            return ActionRow.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .provider:
            return providerCell(for: indexPath)
        case .configuration:
            return configurationCell(for: indexPath)
        case .features:
            return featureCell(for: indexPath)
        case .actions:
            return actionCell(for: indexPath)
        }
    }
    
    // MARK: - Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .provider:
            handleProviderSelection(at: indexPath)
        case .configuration:
            handleConfigurationSelection(at: indexPath)
        case .features:
            // Feature toggles are handled by the switch cell
            break
        case .actions:
            handleActionSelection(at: indexPath)
        }
    }
    
    // MARK: - Cell Configuration
    
    /// Creates a cell for the provider section
    /// - Parameter indexPath: The index path for the cell
    /// - Returns: The configured cell
    private func providerCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let row = ProviderRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .selection:
            let cell = PickerTableCell(
                options: AIProvider.allCases.map { $0.rawValue },
                title: "Provider",
                key: "AI_CurrentProvider",
                defaultValue: AIProvider.allCases.firstIndex(of: currentProvider) ?? 0
            )
            cell.callback = { [weak self] index in
                if let provider = AIProvider.allCases[safe: index] {
                    self?.currentProvider = provider
                    self?.tableView.reloadSections(IndexSet(integer: Section.configuration.rawValue), with: .automatic)
                }
            }
            
            return cell
        }
    }
    
    /// Creates a cell for the configuration section
    /// - Parameter indexPath: The index path for the cell
    /// - Returns: The configured cell
    private func configurationCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let row = ConfigurationRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .apiKey:
            // Create a key for this provider's API key
            let key = "AI_\(currentProvider.rawValue)_APIKey"
            let currentApiKey = currentConfiguration?.apiKey ?? ""
            
            let cell = TextFieldCell(title: "API Key", key: key, defaultValue: currentApiKey)
            cell.textField.isSecureTextEntry = true
            cell.textField.placeholder = "Enter API key"
            
            // Update configuration when text changes
            let originalDelegate = cell.textField.delegate
            cell.textField.delegate = nil
            let delegate = TextFieldDelegateWithCallback(
                originalDelegate: originalDelegate,
                onTextChange: { [weak self] newText in
                    var config = self?.currentConfiguration ?? AIServiceConfiguration(
                        apiKey: newText,
                        baseURL: self?.currentProvider.defaultBaseURL ?? "",
                        model: "",
                        useStreaming: true
                    )
                    config.apiKey = newText
                    self?.currentConfiguration = config
                }
            )
            textFieldDelegates[cell.textField] = delegate
            cell.textField.delegate = delegate
            
            return cell
            
        case .model:
            let models = getAvailableModels()
            let key = "AI_\(currentProvider.rawValue)_Model"
            let currentModel = currentConfiguration?.model ?? models.first ?? ""
            
            let cell = PickerTableCell(
                options: models,
                title: "Model",
                key: key,
                defaultValue: models.firstIndex(of: currentModel) ?? 0
            )
            
            // Add selection change handler
            cell.callback = { [weak self] selectedIndex in
                if let model = models[safe: selectedIndex] {
                    var config = self?.currentConfiguration ?? AIServiceConfiguration(
                        apiKey: "",
                        baseURL: self?.currentProvider.defaultBaseURL ?? "",
                        model: model,
                        useStreaming: true
                    )
                    config.model = model
                    self?.currentConfiguration = config
                }
            }
            
            return cell
            
        case .streaming:
            let key = "AI_\(currentProvider.rawValue)_UseStreaming"
            let useStreaming = currentConfiguration?.useStreaming ?? true
            
            let cell = SwitchTableCell(title: "Use Streaming", key: key, defaultValue: useStreaming)
            
            return cell
            
        case .advancedSettings:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "DefaultCell")
            cell.textLabel?.text = "Advanced Settings"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    /// Creates a cell for the features section
    /// - Parameter indexPath: The index path for the cell
    /// - Returns: The configured cell
    private func featureCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let feature = AIFeature.allCases[safe: indexPath.row] else {
            return UITableViewCell()
        }
        
        let isEnabled = enabledFeatures.contains(feature)
        
        // Check if the current provider supports this feature
        let isSupported = isFeatureSupported(feature)
        
        // Create a custom cell with subtitle style for feature description
        let customCell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        customCell.selectionStyle = .none
        
        // Add label
        let label = UILabel()
        label.text = feature.rawValue
        label.translatesAutoresizingMaskIntoConstraints = false
        customCell.contentView.addSubview(label)
        
        // Add switch
        let toggle = UISwitch()
        toggle.onTintColor = UIColor.systemBlue
        toggle.setOn(isEnabled, animated: false)
        toggle.isEnabled = isSupported
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(featureToggleChanged(_:)), for: .valueChanged)
        toggle.tag = indexPath.row // Use tag to identify which feature
        customCell.contentView.addSubview(toggle)
        
        // Add description label
        let descriptionLabel = UILabel()
        descriptionLabel.font = UIFont.systemFont(ofSize: 12)
        descriptionLabel.numberOfLines = 0
        if !isSupported {
            descriptionLabel.text = "\(feature.description) (Not supported by \(currentProvider.rawValue))"
            descriptionLabel.textColor = .systemRed
        } else {
            descriptionLabel.text = feature.description
            descriptionLabel.textColor = .secondaryLabel
        }
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        customCell.contentView.addSubview(descriptionLabel)
        
        // Set constraints
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: customCell.contentView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: customCell.contentView.leadingAnchor, constant: 16),
            
            toggle.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
            toggle.trailingAnchor.constraint(equalTo: customCell.contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: customCell.contentView.centerYAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: customCell.contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: customCell.contentView.bottomAnchor, constant: -8)
        ])
        
        return customCell
    }
    
    @objc private func featureToggleChanged(_ sender: UISwitch) {
        guard let feature = AIFeature.allCases[safe: sender.tag] else { return }
        
        let key = "AI_Feature_\(feature.rawValue)"
        UserDefaults.standard.set(sender.isOn, forKey: key)
        
        // Update enabled features
        if sender.isOn {
            enabledFeatures.insert(feature)
        } else {
            enabledFeatures.remove(feature)
        }
    }
    
    /// Creates a cell for the actions section
    /// - Parameter indexPath: The index path for the cell
    /// - Returns: The configured cell
    private func actionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let row = ActionRow(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch row {
        case .validate:
            let cell = ButtonTableCell(title: "Validate API Key")
            cell.button?.addAction(UIAction { [weak self] _ in
                self?.validateAPIKey()
            }, for: .touchUpInside)
            return cell
            
        case .importExport:
            let cell = ButtonTableCell(title: "Import/Export Settings")
            cell.button?.addAction(UIAction { [weak self] _ in
                self?.showImportExportOptions()
            }, for: .touchUpInside)
            return cell
            
        case .clearSettings:
            let cell = ButtonTableCell(title: "Clear AI Settings")
            cell.button?.backgroundColor = .systemRed
            cell.button?.setTitleColor(.white, for: .normal)
            cell.button?.layer.cornerRadius = 8
            cell.button?.addAction(UIAction { [weak self] _ in
                self?.showClearSettingsConfirmation()
            }, for: .touchUpInside)
            return cell
        }
    }
    
    // MARK: - Actions
    
    /// Handles selection in the provider section
    /// - Parameter indexPath: The index path that was selected
    private func handleProviderSelection(at indexPath: IndexPath) {
        // Provider selection is handled by the picker cell
    }
    
    /// Handles selection in the configuration section
    /// - Parameter indexPath: The index path that was selected
    private func handleConfigurationSelection(at indexPath: IndexPath) {
        guard let row = ConfigurationRow(rawValue: indexPath.row) else { return }
        
        switch row {
        case .apiKey, .model, .streaming:
            // These are handled by their respective cells
            break
            
        case .advancedSettings:
            let advancedVC = AIAdvancedSettingsViewController(style: .insetGrouped)
            advancedVC.provider = currentProvider
            advancedVC.configuration = currentConfiguration
            advancedVC.onConfigurationChanged = { [weak self] config in
                self?.currentConfiguration = config
            }
            navigationController?.pushViewController(advancedVC, animated: true)
        }
    }
    
    /// Handles selection in the actions section
    /// - Parameter indexPath: The index path that was selected
    private func handleActionSelection(at indexPath: IndexPath) {
        // Actions are handled by the button cells
    }
    
    /// Validates the API key
    private func validateAPIKey() {
        guard let configuration = currentConfiguration, !configuration.apiKey.isEmpty else {
            showAlert(title: "Error", message: "Please enter an API key first.")
            return
        }
        
        // Show activity indicator
        activityIndicator.startAnimating()
        
        // Create a service to validate the API key
        guard let service = AIServiceFactory.createService(for: currentProvider, with: configuration) else {
            activityIndicator.stopAnimating()
            showAlert(title: "Error", message: "Failed to create service for \(currentProvider.rawValue).")
            return
        }
        
        service.validateAPIKey { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                switch result {
                case .success:
                    self?.showAlert(title: "Success", message: "API key is valid.")
                case .failure(let error):
                    self?.showAlert(title: "Validation Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    /// Shows the import/export options
    private func showImportExportOptions() {
        let alertController = UIAlertController(
            title: "Import/Export Settings",
            message: "Choose an option:",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Import from File", style: .default) { [weak self] _ in
            self?.importSettingsFromFile()
        })
        
        alertController.addAction(UIAlertAction(title: "Export to File", style: .default) { [weak self] _ in
            self?.exportSettingsToFile()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    /// Imports settings from a file
    private func importSettingsFromFile() {
        // Create a document picker to select a file
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        
        present(documentPicker, animated: true)
    }
    
    /// Exports settings to a file
    private func exportSettingsToFile() {
        do {
            // Create a temporary file to export the settings
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "nyxian_ai_settings_\(Date().timeIntervalSince1970).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Export the settings
            try AIKeychainManager.shared.exportConfigurationsToFile(at: fileURL)
            
            // Create a document picker to save the file
            let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL])
            documentPicker.delegate = self
            
            present(documentPicker, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }
    
    /// Shows a confirmation dialog for clearing settings
    private func showClearSettingsConfirmation() {
        let alertController = UIAlertController(
            title: "Clear AI Settings",
            message: "This will remove all AI provider configurations and reset to defaults. Are you sure?",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alertController.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.clearAISettings()
        })
        
        present(alertController, animated: true)
    }
    
    /// Clears all AI settings
    private func clearAISettings() {
        do {
            try AIKeychainManager.shared.clearAllConfigurations()
            
            // Reset to defaults
            AIServiceManager.shared.loadConfigurations()
            
            // Reload the table view
            tableView.reloadData()
            
            showAlert(title: "Success", message: "AI settings have been cleared and reset to defaults.")
        } catch {
            showAlert(title: "Error", message: "Failed to clear AI settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the available models for the current provider
    /// - Returns: An array of model names
    private func getAvailableModels() -> [String] {
        // Create a temporary service to get the available models
        guard let configuration = currentConfiguration else {
            return []
        }
        
        guard let service = AIServiceFactory.createService(for: currentProvider, with: configuration) else {
            return []
        }
        
        return service.availableModels
    }
    
    /// Checks if a feature is supported by the current provider
    /// - Parameter feature: The feature to check
    /// - Returns: Whether the feature is supported
    private func isFeatureSupported(_ feature: AIFeature) -> Bool {
        // Create a temporary service to check if the feature is supported
        guard let configuration = currentConfiguration else {
            return false
        }
        
        guard let service = AIServiceFactory.createService(for: currentProvider, with: configuration) else {
            return false
        }
        
        return service.supportedFeatures.contains(feature)
    }
    
    /// Shows an alert with the given title and message
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message of the alert
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alertController, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension AISettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Handle import or export based on the URL access
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Check if this is an import operation by checking if we can read the file
            if FileManager.default.isReadableFile(atPath: url.path) {
                // Import
                do {
                    try AIKeychainManager.shared.importConfigurationsFromFile(at: url)
                    
                    // Reload configurations
                    AIServiceManager.shared.loadConfigurations()
                    
                    // Reload the table view
                    tableView.reloadData()
                    
                    showAlert(title: "Success", message: "AI settings have been imported.")
                } catch {
                    showAlert(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Advanced Settings View Controller

/// View controller for advanced AI settings
class AIAdvancedSettingsViewController: UITableViewController {
    
    // MARK: - Properties
    
    /// The sections in the table view
    enum Section: Int, CaseIterable {
        case baseURL
        case organizationID
        case additionalHeaders
        case additionalParameters
        
        /// The title for the section
        var title: String {
            switch self {
            case .baseURL:
                return "Base URL"
            case .organizationID:
                return "Organization ID"
            case .additionalHeaders:
                return "Additional Headers"
            case .additionalParameters:
                return "Additional Parameters"
            }
        }
    }
    
    /// The provider for these settings
    var provider: AIProvider = .openAI
    
    /// The configuration for these settings
    var configuration: AIServiceConfiguration?
    
    /// Callback when the configuration changes
    var onConfigurationChanged: ((AIServiceConfiguration) -> Void)?
    
    /// The additional headers
    private var additionalHeaders: [String: String] = [:]
    
    /// The additional parameters
    private var additionalParameters: [String: String] = [:]
    
    // Strong references to text field delegates to prevent deallocation
    private var textFieldDelegates: [UITextField: TextFieldDelegateWithCallback] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Advanced Settings"
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44
        
        // Load additional headers and parameters
        additionalHeaders = configuration?.additionalHeaders ?? [:]
        additionalParameters = configuration?.additionalParameters ?? [:]
        
        // Add add button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addHeaderOrParameter)
        )
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .baseURL, .organizationID:
            return 1
        case .additionalHeaders:
            return additionalHeaders.isEmpty ? 1 : additionalHeaders.count
        case .additionalParameters:
            return additionalParameters.isEmpty ? 1 : additionalParameters.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .baseURL:
            let key = "AI_\(provider.rawValue)_BaseURL"
            let baseURL = configuration?.baseURL ?? provider.defaultBaseURL
            
            let cell = TextFieldCell(title: "Base URL", key: key, defaultValue: baseURL)
            cell.textField.placeholder = "Enter base URL"
            
            // Update configuration when text changes
            let originalDelegate = cell.textField.delegate
            cell.textField.delegate = nil
            let delegate = TextFieldDelegateWithCallback(
                originalDelegate: originalDelegate,
                onTextChange: { [weak self] newText in
                    var config = self?.configuration ?? AIServiceConfiguration(
                        apiKey: "",
                        baseURL: newText,
                        model: "",
                        useStreaming: true
                    )
                    config.baseURL = newText
                    self?.configuration = config
                    self?.onConfigurationChanged?(config)
                }
            )
            textFieldDelegates[cell.textField] = delegate
            cell.textField.delegate = delegate
            
            return cell
            
        case .organizationID:
            let key = "AI_\(provider.rawValue)_OrganizationID"
            let organizationID = configuration?.organizationID ?? ""
            
            let cell = TextFieldCell(title: "Organization ID", key: key, defaultValue: organizationID)
            cell.textField.placeholder = "Enter organization ID (if applicable)"
            
            // Update configuration when text changes
            let originalDelegate = cell.textField.delegate
            cell.textField.delegate = nil
            let delegate = TextFieldDelegateWithCallback(
                originalDelegate: originalDelegate,
                onTextChange: { [weak self] newText in
                    var config = self?.configuration ?? AIServiceConfiguration(
                        apiKey: "",
                        baseURL: "",
                        model: "",
                        useStreaming: true
                    )
                    config.organizationID = newText.isEmpty ? nil : newText
                    self?.configuration = config
                    self?.onConfigurationChanged?(config)
                }
            )
            textFieldDelegates[cell.textField] = delegate
            cell.textField.delegate = delegate
            
            return cell
            
        case .additionalHeaders:
            if additionalHeaders.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "DefaultCell")
                cell.textLabel?.text = "No additional headers"
                cell.textLabel?.textColor = .secondaryLabel
                return cell
            } else {
                let keys = Array(additionalHeaders.keys).sorted()
                let key = keys[indexPath.row]
                let value = additionalHeaders[key] ?? ""
                
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DefaultCell")
                cell.textLabel?.text = key
                cell.detailTextLabel?.text = value
                cell.accessoryType = .detailDisclosureButton
                return cell
            }
            
        case .additionalParameters:
            if additionalParameters.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "DefaultCell")
                cell.textLabel?.text = "No additional parameters"
                cell.textLabel?.textColor = .secondaryLabel
                return cell
            } else {
                let keys = Array(additionalParameters.keys).sorted()
                let key = keys[indexPath.row]
                let value = additionalParameters[key] ?? ""
                
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DefaultCell")
                cell.textLabel?.text = key
                cell.detailTextLabel?.text = value
                cell.accessoryType = .detailDisclosureButton
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .baseURL, .organizationID:
            // These are handled by their respective cells
            break
            
        case .additionalHeaders:
            if !additionalHeaders.isEmpty {
                let keys = Array(additionalHeaders.keys).sorted()
                let key = keys[indexPath.row]
                showEditHeaderOrParameter(key: key, value: additionalHeaders[key] ?? "", isHeader: true)
            }
            
        case .additionalParameters:
            if !additionalParameters.isEmpty {
                let keys = Array(additionalParameters.keys).sorted()
                let key = keys[indexPath.row]
                showEditHeaderOrParameter(key: key, value: additionalParameters[key] ?? "", isHeader: false)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .baseURL, .organizationID:
            break
            
        case .additionalHeaders:
            if !additionalHeaders.isEmpty {
                let keys = Array(additionalHeaders.keys).sorted()
                let key = keys[indexPath.row]
                showDeleteHeaderOrParameter(key: key, isHeader: true)
            }
            
        case .additionalParameters:
            if !additionalParameters.isEmpty {
                let keys = Array(additionalParameters.keys).sorted()
                let key = keys[indexPath.row]
                showDeleteHeaderOrParameter(key: key, isHeader: false)
            }
        }
    }
    
    // MARK: - Actions
    
    /// Shows a dialog to add a header or parameter
    @objc private func addHeaderOrParameter() {
        let alertController = UIAlertController(
            title: "Add",
            message: "Choose what to add:",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Header", style: .default) { [weak self] _ in
            self?.showAddHeaderOrParameter(isHeader: true)
        })
        
        alertController.addAction(UIAlertAction(title: "Parameter", style: .default) { [weak self] _ in
            self?.showAddHeaderOrParameter(isHeader: false)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    /// Shows a dialog to add a header or parameter
    /// - Parameter isHeader: Whether to add a header or parameter
    private func showAddHeaderOrParameter(isHeader: Bool) {
        let alertController = UIAlertController(
            title: "Add \(isHeader ? "Header" : "Parameter")",
            message: nil,
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Key"
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Value"
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alertController.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alertController] _ in
            guard let key = alertController?.textFields?[0].text, !key.isEmpty,
                  let value = alertController?.textFields?[1].text, !value.isEmpty else {
                return
            }
            
            if isHeader {
                self?.additionalHeaders[key] = value
            } else {
                self?.additionalParameters[key] = value
            }
            
            self?.updateConfiguration()
            self?.tableView.reloadData()
        })
        
        present(alertController, animated: true)
    }
    
    /// Shows a dialog to edit a header or parameter
    /// - Parameters:
    ///   - key: The key to edit
    ///   - value: The current value
    ///   - isHeader: Whether it's a header or parameter
    private func showEditHeaderOrParameter(key: String, value: String, isHeader: Bool) {
        let alertController = UIAlertController(
            title: "Edit \(isHeader ? "Header" : "Parameter")",
            message: nil,
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Key"
            textField.text = key
            textField.isEnabled = false // Don't allow editing the key
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Value"
            textField.text = value
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alertController.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alertController] _ in
            guard let newValue = alertController?.textFields?[1].text, !newValue.isEmpty else {
                return
            }
            
            if isHeader {
                self?.additionalHeaders[key] = newValue
            } else {
                self?.additionalParameters[key] = newValue
            }
            
            self?.updateConfiguration()
            self?.tableView.reloadData()
        })
        
        present(alertController, animated: true)
    }
    
    /// Shows a dialog to delete a header or parameter
    /// - Parameters:
    ///   - key: The key to delete
    ///   - isHeader: Whether it's a header or parameter
    private func showDeleteHeaderOrParameter(key: String, isHeader: Bool) {
        let alertController = UIAlertController(
            title: "Delete \(isHeader ? "Header" : "Parameter")",
            message: "Are you sure you want to delete '\(key)'?",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            if isHeader {
                self?.additionalHeaders.removeValue(forKey: key)
            } else {
                self?.additionalParameters.removeValue(forKey: key)
            }
            
            self?.updateConfiguration()
            self?.tableView.reloadData()
        })
        
        present(alertController, animated: true)
    }
    
    /// Updates the configuration with the current headers and parameters
    private func updateConfiguration() {
        var config = configuration ?? AIServiceConfiguration(
            apiKey: "",
            baseURL: "",
            model: "",
            useStreaming: true
        )
        
        config.additionalHeaders = additionalHeaders.isEmpty ? nil : additionalHeaders
        config.additionalParameters = additionalParameters.isEmpty ? nil : additionalParameters
        
        configuration = config
        onConfigurationChanged?(config)
    }
}

// MARK: - Array Extension

extension Array {
    /// Safely accesses an element at the given index
    /// - Parameter index: The index to access
    /// - Returns: The element at the index, or nil if out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TextField Delegate with Callback

/// A delegate for text fields that calls a callback when the text changes
class TextFieldDelegateWithCallback: NSObject, UITextFieldDelegate {
    /// The original delegate
    private weak var originalDelegate: UITextFieldDelegate?
    
    /// The callback to call when the text changes
    private let onTextChange: (String) -> Void
    
    /// Creates a new delegate with a callback
    /// - Parameters:
    ///   - originalDelegate: The original delegate
    ///   - onTextChange: The callback to call when the text changes
    init(originalDelegate: UITextFieldDelegate?, onTextChange: @escaping (String) -> Void) {
        self.originalDelegate = originalDelegate
        self.onTextChange = onTextChange
        super.init()
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        originalDelegate?.textFieldDidEndEditing?(textField)
        onTextChange(textField.text ?? "")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let result = originalDelegate?.textFieldShouldReturn?(textField) ?? true
        textField.resignFirstResponder()
        return result
    }
}
