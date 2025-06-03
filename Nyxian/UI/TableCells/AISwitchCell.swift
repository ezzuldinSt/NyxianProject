//
//  AISwitchCell.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation
import UIKit

class SwitchCell: UITableViewCell {
    /// The title of the cell
    let title: String
    
    /// The key for UserDefaults storage
    let key: String
    
    /// The default value for the switch
    let defaultValue: Bool
    
    /// The switch control
    var switchControl: UISwitch!
    
    /// Callback when the value changes
    var valueDidChange: ((Bool) -> Void)?
    
    /// The current value of the switch
    var value: Bool {
        get {
            if UserDefaults.standard.object(forKey: self.key) == nil {
                UserDefaults.standard.set(self.defaultValue, forKey: self.key)
            }
            
            return UserDefaults.standard.bool(forKey: self.key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
            valueDidChange?(newValue)
        }
    }
    
    /// Creates a new switch cell
    /// - Parameters:
    ///   - title: The title of the cell
    ///   - key: The key for UserDefaults storage
    ///   - defaultValue: The default value for the switch
    init(
        title: String,
        key: String,
        defaultValue: Bool
    ) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        super.init(style: .default, reuseIdentifier: nil)
        
        // Initialize value from UserDefaults
        _ = self.value
        
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the views for the cell
    private func setupViews() {
        // Disable selection
        self.selectionStyle = .none
        
        // Create the label
        let label = UILabel()
        label.text = self.title
        label.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(label)
        
        // Create the switch
        switchControl = UISwitch()
        switchControl.onTintColor = UIColor.systemBlue
        switchControl.setOn(self.value, animated: false)
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.addTarget(self, action: #selector(toggleValueChanged), for: .valueChanged)
        self.contentView.addSubview(switchControl)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            
            switchControl.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
            switchControl.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ])
    }
    
    /// Called when the switch value changes
    /// - Parameter sender: The switch that changed
    @objc private func toggleValueChanged(_ sender: UISwitch) {
        self.value = sender.isOn
    }
}
