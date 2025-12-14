import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CollapsibleSearchBox: View {
    @Binding var searchText: String
    @Binding var showThaiPrimary: Bool // true = Thai primary, false = Burmese primary
    @Binding var activateNow: Bool // when set to true, expand and focus the search box
    @Binding var isActive: Bool // report expanded state to parent
    // Notify parent when user explicitly closes the search box via the X button
    var onClose: (() -> Void)? = nil
    @State private var expanded = true
    @FocusState private var isFocused: Bool
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false

    // Google-style pill search bar
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                if expanded {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue.opacity(0.9))
                            .padding(.trailing, 6)
                        #if canImport(UIKit)
                        // UIKit-backed field so we can read keyboard input language
                        KeyboardAwareTextField(text: $searchText, onKeyboardLanguage: { lang in
                            guard let lang = lang else { return }
                            // Map keyboard language to toggle
                            if lang.hasPrefix("th") { showThaiPrimary = true }
                            else if lang.hasPrefix("my") || lang.hasPrefix("bur") { showThaiPrimary = false }
                        })
                        .padding(.vertical, 8)
                        .focused($isFocused)
                        
                        #else
                        // Fallback pure SwiftUI TextField on platforms without UIKit
                        TextField("Search Thai or Burmese...", text: $searchText)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                            .foregroundColor(.white)
                            .tint(.blue)
                            
                        #endif
                        

                        Button(action: {
                            searchText = ""
                            withAnimation { expanded = false }
                            isFocused = false
                            isActive = false
                            // Inform parent to hide the entire search box container
                            DispatchQueue.main.async {
                                onClose?()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.leading, 4)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    // Collapsed pill only magnifying glass
                    Button(action: {
                        withAnimation { expanded = true }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 19.5))  // Approximately 30% larger than default
                            .foregroundColor(.blue)
                    }
                }
                // (Removed) Test buttons outside capsule
                if false { EmptyView() }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.22), Color.cyan.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.blue.opacity(0.55), lineWidth: 1.25)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            
        }
        .onTapGesture {
            if !expanded {
                withAnimation(.spring()) { expanded = true }
                isFocused = true
            }
        }
        // Programmatic activation from parent (e.g., IntroView -> ContentView)
        .onChange(of: activateNow) { _, newValue in
            if newValue {
                withAnimation { expanded = true }
                DispatchQueue.main.async { isFocused = true }
                // reset the trigger so future taps can re-activate
                DispatchQueue.main.async { activateNow = false }
            }
        }
        // Keep parent in sync with focus state (search 'using' state)
        .onChange(of: isFocused) { _, focused in
            isActive = focused
        }
        // Heuristic fallback: if last typed char is Thai or Burmese script, auto-toggle
        .onChange(of: searchText) { _, newValue in
            guard let last = newValue.unicodeScalars.last else { return }
            switch last.value {
            case 0x0E00...0x0E7F:
                showThaiPrimary = true
            case 0x1000...0x109F, 0xAA60...0xAA7F, 0xA9E0...0xA9FF:
                showThaiPrimary = false
            default:
                break
            }
        }
        .onChange(of: expanded) { _, newValue in
            if newValue {
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .animation(.easeInOut, value: expanded)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - UIKit bridge to detect keyboard input language
#if canImport(UIKit)
struct KeyboardAwareTextField: UIViewRepresentable {
    @Binding var text: String
    var onKeyboardLanguage: (String?) -> Void
    var onReturn: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.placeholder = "Search Thai or Burmese..."
        tf.borderStyle = .none
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.returnKeyType = .search
        // Improve visibility on dark background
        tf.textColor = .white
        tf.tintColor = .white // cursor
        tf.backgroundColor = .clear
        tf.attributedPlaceholder = NSAttributedString(
            string: "Search Thai or Burmese...",
            attributes: [
                .foregroundColor: UIColor(white: 1.0, alpha: 0.68)
            ]
        )
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: KeyboardAwareTextField
        init(_ parent: KeyboardAwareTextField) { self.parent = parent }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
            parent.onKeyboardLanguage(sender.textInputMode?.primaryLanguage)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onKeyboardLanguage(textField.textInputMode?.primaryLanguage)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.onKeyboardLanguage(textField.textInputMode?.primaryLanguage)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onReturn()
            return true
        }
    }
}
#endif

// History helpers removed per request
