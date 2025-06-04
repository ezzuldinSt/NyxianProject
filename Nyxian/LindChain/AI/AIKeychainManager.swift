//
//  AIKeychainManager.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation
import Security

/// Errors that can occur during keychain operations
public enum AIKeychainError: Error {
    /// The operation could not be completed
    case operationFailed(OSStatus)
    
    /// The data could not be encoded
    case encodingFailed
    
    /// The data could not be decoded
    case decodingFailed
    
    /// No data was found for the given key
    case noDataFound
    
    /// The backup file could not be created
    case backupCreationFailed
    
    /// The backup file could not be restored
    case backupRestoreFailed
    
    /// Returns a user-friendly error message
    var localizedDescription: String {
        switch self {
        case .operationFailed(let status):
            return "Keychain operation failed with status: \(status)"
        case .encodingFailed:
            return "Failed to encode data for keychain storage"
        case .decodingFailed:
            return "Failed to decode data from keychain storage"
        case .noDataFound:
            return "No data found in keychain for the specified key"
        case .backupCreationFailed:
            return "Failed to create backup of configurations"
        case .backupRestoreFailed:
            return "Failed to restore configurations from backup"
        }
    }
}

/// Manager for securely storing AI service configurations in the keychain
public class AIKeychainManager {
    /// Shared instance of the manager
    public static let shared = AIKeychainManager()
    
    /// The service name for keychain entries
    private let serviceName = "com.seanistethered.nyxian.ai"
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Core Keychain Operations
    
    /// Saves data to the keychain for a given key
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The key to save the data under
    /// - Throws: AIKeychainError if the operation fails
    private func saveToKeychain(_ data: Data, forKey key: String) throws {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // First, try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Now add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Check for success
        guard status == errSecSuccess else {
            throw AIKeychainError.operationFailed(status)
        }
    }
    
    /// Retrieves data from the keychain for a given key
    /// - Parameter key: The key to retrieve data for
    /// - Returns: The retrieved data
    /// - Throws: AIKeychainError if the operation fails
    private func retrieveFromKeychain(forKey key: String) throws -> Data {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Try to retrieve the item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Check for success
        if status == errSecSuccess {
            // Ensure we got data back
            guard let data = result as? Data else {
                throw AIKeychainError.noDataFound
            }
            return data
        } else if status == errSecItemNotFound {
            throw AIKeychainError.noDataFound
        } else {
            throw AIKeychainError.operationFailed(status)
        }
    }
    
    /// Updates data in the keychain for a given key
    /// - Parameters:
    ///   - data: The new data to save
    ///   - key: The key to update
    /// - Throws: AIKeychainError if the operation fails
    private func updateInKeychain(_ data: Data, forKey key: String) throws {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Create an attributes dictionary with the new data
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Try to update the item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If the item doesn't exist, try to add it
        if status == errSecItemNotFound {
            try saveToKeychain(data, forKey: key)
        } else if status != errSecSuccess {
            throw AIKeychainError.operationFailed(status)
        }
    }
    
    /// Deletes data from the keychain for a given key
    /// - Parameter key: The key to delete data for
    /// - Throws: AIKeychainError if the operation fails
    private func deleteFromKeychain(forKey key: String) throws {
        // Create a query dictionary for the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Try to delete the item
        let status = SecItemDelete(query as CFDictionary)
        
        // Check for success (or that the item wasn't found)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIKeychainError.operationFailed(status)
        }
    }
    
    // MARK: - AI Service Configuration Operations
    
    /// Gets the keychain key for a provider
    /// - Parameter provider: The provider to get the key for
    /// - Returns: The keychain key
    private func keychainKey(for provider: AIProvider) -> String {
        return "ai_config_\(provider.rawValue)"
    }
    
    /// Saves a configuration to the keychain
    /// - Parameters:
    ///   - configuration: The configuration to save
    ///   - provider: The provider to save the configuration for
    /// - Throws: AIKeychainError if the operation fails
    public func saveConfiguration(_ configuration: AIServiceConfiguration, for provider: AIProvider) throws {
        // Encode the configuration
        guard let data = try? JSONEncoder().encode(configuration) else {
            throw AIKeychainError.encodingFailed
        }
        
        // Get the key for this provider
        let key = keychainKey(for: provider)
        
        // Try to update first, and if that fails, save
        do {
            try updateInKeychain(data, forKey: key)
        } catch {
            try saveToKeychain(data, forKey: key)
        }
    }
    
    /// Retrieves a configuration from the keychain
    /// - Parameter provider: The provider to retrieve the configuration for
    /// - Returns: The retrieved configuration
    /// - Throws: AIKeychainError if the operation fails
    public func retrieveConfiguration(for provider: AIProvider) throws -> AIServiceConfiguration {
        // Get the key for this provider
        let key = keychainKey(for: provider)
        
        // Retrieve the data
        let data = try retrieveFromKeychain(forKey: key)
        
        // Decode the configuration
        guard let configuration = try? JSONDecoder().decode(AIServiceConfiguration.self, from: data) else {
            throw AIKeychainError.decodingFailed
        }
        
        return configuration
    }
    
    /// Deletes a configuration from the keychain
    /// - Parameter provider: The provider to delete the configuration for
    /// - Throws: AIKeychainError if the operation fails
    public func deleteConfiguration(for provider: AIProvider) throws {
        // Get the key for this provider
        let key = keychainKey(for: provider)
        
        // Delete the data
        try deleteFromKeychain(forKey: key)
    }
    
    /// Checks if a configuration exists in the keychain
    /// - Parameter provider: The provider to check for
    /// - Returns: Whether a configuration exists
    public func configurationExists(for provider: AIProvider) -> Bool {
        // Get the key for this provider
        let key = keychainKey(for: provider)
        
        // Try to retrieve the data
        do {
            _ = try retrieveFromKeychain(forKey: key)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Backup and Restore
    
    /// Backup structure for configurations
    private struct ConfigurationsBackup: Codable {
        /// The configurations to backup
        let configurations: [String: AIServiceConfiguration]
        
        /// The timestamp of the backup
        let timestamp: Date
        
        /// The version of the backup
        let version: Int = 1
    }
    
    /// Creates a backup of all configurations
    /// - Returns: The backup data
    /// - Throws: AIKeychainError if the operation fails
    public func createBackup() throws -> Data {
        var configurations: [String: AIServiceConfiguration] = [:]
        
        // Retrieve configurations for all providers
        for provider in AIProvider.allCases {
            do {
                let configuration = try retrieveConfiguration(for: provider)
                configurations[provider.rawValue] = configuration
            } catch AIKeychainError.noDataFound {
                // Skip providers with no configuration
                continue
            } catch {
                // Re-throw the original error with more context
                print("Error retrieving configuration for \(provider): \(error)")
                throw error
            }
        }
        
        // Create the backup structure
        let backup = ConfigurationsBackup(
            configurations: configurations,
            timestamp: Date()
        )
        
        // Encode the backup with better error handling
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)
            return data
        } catch {
            print("Failed to encode backup: \(error)")
            throw AIKeychainError.backupCreationFailed
        }
    }
    
    /// Restores configurations from a backup
    /// - Parameter data: The backup data
    /// - Throws: AIKeychainError if the operation fails
    public func restoreFromBackup(_ data: Data) throws {
        // Decode the backup
        guard let backup = try? JSONDecoder().decode(ConfigurationsBackup.self, from: data) else {
            throw AIKeychainError.backupRestoreFailed
        }
        
        // Restore configurations for all providers in the backup
        for (providerRawValue, configuration) in backup.configurations {
            guard let provider = AIProvider(rawValue: providerRawValue) else {
                continue
            }
            
            try saveConfiguration(configuration, for: provider)
        }
    }
    
    /// Exports configurations to a file
    /// - Parameter url: The URL to export to
    /// - Throws: AIKeychainError if the operation fails
    public func exportConfigurationsToFile(at url: URL) throws {
        let data = try createBackup()
        
        do {
            try data.write(to: url)
        } catch {
            throw AIKeychainError.backupCreationFailed
        }
    }
    
    /// Imports configurations from a file
    /// - Parameter url: The URL to import from
    /// - Throws: AIKeychainError if the operation fails
    public func importConfigurationsFromFile(at url: URL) throws {
        do {
            let data = try Data(contentsOf: url)
            try restoreFromBackup(data)
        } catch {
            throw AIKeychainError.backupRestoreFailed
        }
    }
    
    /// Clears all configurations from the keychain
    /// - Throws: AIKeychainError if the operation fails
    public func clearAllConfigurations() throws {
        for provider in AIProvider.allCases {
            try? deleteConfiguration(for: provider)
        }
    }
    
    // MARK: - Integration with AIServiceManager
    
    /// Loads all configurations into the AIServiceManager
    public func loadConfigurationsIntoManager() {
        for provider in AIProvider.allCases {
            do {
                let configuration = try retrieveConfiguration(for: provider)
                AIServiceManager.shared.setConfiguration(configuration, for: provider)
            } catch {
                // Skip providers with no configuration
                continue
            }
        }
        
        // Load the current provider from UserDefaults
        if let providerRawValue = UserDefaults.standard.string(forKey: "AICurrentProvider"),
           let provider = AIProvider(rawValue: providerRawValue) {
            AIServiceManager.shared.setCurrentProvider(provider)
        }
        
        // Load enabled features from UserDefaults
        if let enabledFeatureRawValues = UserDefaults.standard.stringArray(forKey: "AIEnabledFeatures") {
            let enabledFeatures = enabledFeatureRawValues.compactMap { AIFeature(rawValue: $0) }
            AIServiceManager.shared.enabledFeatures = Set(enabledFeatures)
        }
    }
    
    /// Saves all configurations from the AIServiceManager
    public func saveConfigurationsFromManager() {
        for (provider, configuration) in AIServiceManager.shared.configurations {
            do {
                try saveConfiguration(configuration, for: provider)
            } catch {
                print("Failed to save configuration for \(provider): \(error.localizedDescription)")
            }
        }
    }
}
