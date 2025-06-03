//
//  AIButtonCell.swift
//  Nyxian
//
//  Created by fridakitten on 03.06.25.
//

import UIKit

class ButtonCell: UITableViewCell {
    /// The title of the button
    let title: String
    
    /// The button for user interaction
    var button: UIButton?
    
    /// Creates a new button cell
    /// - Parameter title: The title of the button
    init(title: String) {
        self.title = title
        super.init(style: .default, reuseIdentifier: nil)
        
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Sets up the views for the cell
    private func setupViews() {
        // Setting up the button
        button = UIButton()
        button?.titleLabel?.textAlignment = .left
        button?.contentHorizontalAlignment = .left
        button?.setTitle(self.title, for: .normal)
        button?.setTitleColor(UIColor.systemBlue, for: .normal)
        button?.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(button!)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            button!.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            button!.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
            button!.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            button!.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16)
        ])
    }
}
