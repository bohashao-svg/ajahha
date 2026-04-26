import SwiftUI

// MARK: - Parameter Form View
struct ParameterFormView: View {
    @Binding var fields: [FormField]

    var body: some View {
        if !fields.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("参数配置")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhSecondary)

                ForEach($fields) { $field in
                    FieldRow(field: $field)
                }
            }
            .rhCard()
        }
    }
}

// MARK: - Field Row
private struct FieldRow: View {
    @Binding var field: FormField

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                fieldIcon
                Text(field.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhPrimary)
            }

            fieldInput
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var fieldIcon: some View {
        switch field.type {
        case .multilineText:
            RHIcon(name: .workflow, size: 14, color: .rhSecondary)
        case .password:
            RHIcon(name: .lock, size: 14, color: .rhWarning)
        case .imageInput:
            RHIcon(name: .image, size: 14, color: .rhSecondary)
        case .text:
            RHIcon(name: .workflow, size: 14, color: .rhSecondary)
        }
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch field.type {
        case .multilineText:
            ZStack(alignment: .topLeading) {
                if field.value.isEmpty {
                    Text(field.placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(.rhSecondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $field.value)
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .frame(minHeight: 80, maxHeight: 160)
                    .onAppear { UITextView.appearance().backgroundColor = .clear }
            }
            .padding(10)
            .background(Color.rhBackground)
            .cornerRadius(10)

        case .password:
            SecureField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(10)

        case .imageInput, .text:
            TextField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(10)
        }
    }
}
