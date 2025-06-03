//
//  AITextFieldCell.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import UIKit

class TextFieldCell: UITableViewCell, UITextFieldDelegate {
    /// The text field for user input
    var textField: UITextField!
    
    /// The title of the cell
    let title: String
    
    /// The key for UserDefaults storage
    let key: String
    
    /// The default value for the text field
    let defaultValue: String
    
    /// Callback when the value changes
    var valueDidChange: ((String) -> Void)?

    /// The current value of the text field
    var value: String {
        get {
            if UserDefaults.standard.string(forKey: self.key) == nil {
                UserDefaults.standard.set(self.defaultValue, forKey: self.key)
            }
            return UserDefaults.standard.string(forKey: self.key) ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
            valueDidChange?(newValue)
        }
    }

    /// Creates a new text field cell
    /// - Parameters:
    ///   - title: The title of the cell
    ///   - key: The key for UserDefaults storage
    ///   - defaultValue: The default value for the text field
    init(title: String, key: String, defaultValue: String) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        super.init(style: .default, reuseIdentifier: nil)
        
        // Initialize value from UserDefaults
        _ = self.value
        
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets up the views for the cell
    private func setupViews() {
        // Disable selection
        selectionStyle = .none

        // Create the label
        let label = UILabel()
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        // Create the text field
        textField = UITextField()
        textField.placeholder = "Value"
        textField.text = value
        textField.textAlignment = .right
        textField.delegate = self
        textField.borderStyle = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)

        // Set up constraints
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.value = textField.text ?? ""
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
