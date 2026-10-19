import SwiftUI
import UIKit

// The system alert owns its text field and reads that field when confirming.
// This avoids depending on SwiftUI alert-action snapshots while editing text.
struct CustomMoodPrompt: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var initialText: String
    var completion: (String) -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.initialText = initialText
        controller.onFinish = { value in
            isPresented = false
            if let value { completion(value) }
        }
        controller.wantsPresentation = isPresented
        controller.updatePresentation()
    }

    final class Controller: UIViewController, UITextFieldDelegate {
        var initialText = ""
        var wantsPresentation = false
        var onFinish: ((String?) -> Void)?
        private var prompt: UIAlertController?
        private var saveAction: UIAlertAction?

        override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .clear }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updatePresentation() }
        func updatePresentation() {
            guard wantsPresentation else {
                if let prompt { self.prompt = nil; prompt.dismiss(animated: true) }
                return
            }
            guard viewIfLoaded?.window != nil, prompt == nil, presentedViewController == nil else { return }
            let alert = UIAlertController(title: "自定义心情", message: "写下此刻的心情，最多 30 字。", preferredStyle: .alert)
            alert.view.tintColor = UIColor(named: "AccentColor")
            alert.addTextField { field in
                field.placeholder = "最多 30 字"
                field.text = String(self.initialText.prefix(30))
                field.accessibilityIdentifier = "moodInput"
                field.delegate = self
                field.returnKeyType = .done
                field.adjustsFontForContentSizeCategory = true
                field.addTarget(self, action: #selector(self.textChanged(_:)), for: .editingChanged)
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in self?.finish(nil) })
            let save = UIAlertAction(title: "确定", style: .default) { [weak self, weak alert] _ in
                let value = String((alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
                self?.finish(value.isEmpty ? nil : value)
            }
            save.isEnabled = !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            alert.addAction(save); saveAction = save; prompt = alert
            present(alert, animated: true)
        }
        private func finish(_ value: String?) {
            prompt = nil; saveAction = nil; wantsPresentation = false; onFinish?(value)
        }
        @objc private func textChanged(_ field: UITextField) {
            if field.markedTextRange == nil, let text = field.text, text.count > 30 {
                field.text = String(text.prefix(30)); UISelectionFeedbackGenerator().selectionChanged()
            }
            saveAction?.isEnabled = !(field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard saveAction?.isEnabled == true else { return false }
            let value = String((textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
            let alert = prompt
            finish(value); alert?.dismiss(animated: true)
            return true
        }
    }
}
