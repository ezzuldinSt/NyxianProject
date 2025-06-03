//
//  AIPickerCell.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import Foundation
import UIKit

/// A table view cell with a picker for selecting from a list of options
class PickerCell: UITableViewCell {
    /// The title of the cell
    let title: String
    
    /// The options to choose from
    let options: [String]
    
    /// The currently selected index
    var selectedIndex: Int = 0 {
        didSet {
            if selectedIndex >= 0 && selectedIndex < options.count {
                button?.setTitle(options[selectedIndex], for: .normal)
                onSelectionChange?(selectedIndex)
            }
        }
    }
    
    /// The button that shows the selected option
    private var button: UIButton?
    
    /// Callback when the selection changes
    var onSelectionChange: ((Int) -> Void)?
    
    /// Creates a new picker cell
    /// - Parameters:
    ///   - title: The title of the cell
    ///   - options: The options to choose from
    init(title: String, options: [String]) {
        self.title = title
        self.options = options
        super.init(style: .default, reuseIdentifier: nil)
        
        setupViews()
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
        label.text = title
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        // Create the chevron image
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: config)!
        
        // Create the button
        button = UIButton()
        button?.setTitle(options.isEmpty ? "" : options[selectedIndex], for: .normal)
        button?.setTitleColor(UIColor.systemBlue, for: .normal)
        button?.setImage(image, for: .normal)
        button?.titleLabel?.textAlignment = .right
        button?.semanticContentAttribute = .forceRightToLeft
        button?.translatesAutoresizingMaskIntoConstraints = false
        
        if let button = button {
            contentView.addSubview(button)
        }
        
        // Create the menu for the button
        var menuItems: [UIMenuElement] = []
        
        for (index, option) in options.enumerated() {
            menuItems.append(UIAction(title: option) { [weak self] _ in
                self?.selectedIndex = index
            })
        }
        
        button?.menu = UIMenu(children: menuItems)
        button?.showsMenuAsPrimaryAction = true
        
        // Set up constraints
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            button!.topAnchor.constraint(equalTo: contentView.topAnchor),
            button!.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            button!.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
            button!.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
}
