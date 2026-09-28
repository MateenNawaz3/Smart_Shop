//
//  KeyboardDoneBar.swift
//  SmartShop
//

import SwiftUI
import UIKit

/// Puts a Done button above every keyboard the app raises.
///
/// Done in UIKit rather than with SwiftUI's `.toolbar(placement: .keyboard)`:
/// that placement only shows inside a navigation container, so sheets and
/// covers without one would miss out, and every field on a screen adds its
/// own copy of the button. Watching for any text input to begin editing
/// covers every field in one place — number pads included, which have no
/// return key to close them.
final class KeyboardDoneBar: NSObject {
    private static var installed: KeyboardDoneBar?

    private let title: () -> String

    private init(title: @escaping () -> String) {
        self.title = title
    }

    /// `title` is read each time a keyboard appears, so a language change
    /// applies from the next field tapped.
    static func install(title: @escaping () -> String) {
        guard installed == nil else { return }
        let bar = KeyboardDoneBar(title: title)
        for name in [UITextField.textDidBeginEditingNotification, UITextView.textDidBeginEditingNotification] {
            NotificationCenter.default.addObserver(bar, selector: #selector(didBeginEditing), name: name, object: nil)
        }
        installed = bar
    }

    @objc private func didBeginEditing(_ note: Notification) {
        let title = title()
        switch note.object {
        case let field as UITextField:
            guard !Self.hasBar(field.inputAccessoryView, titled: title) else { return }
            field.inputAccessoryView = Self.toolbar(title: title) { [weak field] in field?.resignFirstResponder() }
            field.reloadInputViews()
        case let view as UITextView where view.isEditable:
            guard !Self.hasBar(view.inputAccessoryView, titled: title) else { return }
            view.inputAccessoryView = Self.toolbar(title: title) { [weak view] in view?.resignFirstResponder() }
            view.reloadInputViews()
        default:
            break
        }
    }

    /// Already showing our bar in the current language — reloading would only
    /// make the keyboard flicker.
    private static func hasBar(_ accessory: UIView?, titled title: String) -> Bool {
        guard let toolbar = accessory as? DoneToolbar else { return false }
        return toolbar.title == title
    }

    private static func toolbar(title: String, onDone: @escaping () -> Void) -> DoneToolbar {
        let toolbar = DoneToolbar(title: title)

        // A compact pill of our own. A plain bar item on iOS 26 is a full-size
        // Liquid Glass capsule, far louder than a keyboard's Done should be.
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(Theme.Colors.green)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        var text = AttributedString(title)
        text.font = UIFont(name: Theme.Inter.semibold, size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = text
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in onDone() })

        let done = UIBarButtonItem(customView: button)
        done.hidesSharedBackground = true
        toolbar.items = [.flexibleSpace(), done]
        toolbar.sizeToFit()
        return toolbar
    }
}

/// Tagged with its title so a field can tell our bar from any other
/// accessory and spot one left over from a previous language.
private final class DoneToolbar: UIToolbar {
    let title: String

    init(title: String) {
        self.title = title
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
