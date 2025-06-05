//
//  TextFieldCell.swift
//  Nyxian
//
//  Created by SeanIsTethered on 28.05.25.
//

import UIKit

class TextFieldTableCell: UITableViewCell, UITextFieldDelegate {
    var textField: UITextField!
    let title: String
    let key: String
    let defaultValue: String

    var value: String {
        get {
            if UserDefaults.standard.string(forKey: self.key) == nil {
                UserDefaults.standard.set(self.defaultValue, forKey: self.key)
            }
            return UserDefaults.standard.string(forKey: self.key) ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
        }
    }

    init(title: String, key: String, defaultValue: String) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        super.init(style: .default, reuseIdentifier: nil)
        _ = self.value  // Ensures the default is set if needed
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none

        let label = UILabel()
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        textField = UITextField()
        textField.placeholder = "Value"
        textField.text = value
        textField.textAlignment = .right
        textField.delegate = self
        textField.borderStyle = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 11),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -11),

            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 30),
            textField.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 7),
            textField.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -7),
            
            // Ensure minimum content view height
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
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
