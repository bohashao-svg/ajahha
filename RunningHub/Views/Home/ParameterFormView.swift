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
                    if field.id != fields.last?.id {
                        Divider().background(Color.rhBorder)
                    }
                }
            }
            .rhCard()
        }
    }
}

// MARK: - Field Row
private struct FieldRow: View {
    @Binding var field: FormField
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                fieldIcon
                Text(field.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rhPrimary)
            }
            fieldInput
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var fieldIcon: some View {
        ZStack {
            Circle()
                .fill(iconBgColor)
                .frame(width: 22, height: 22)
            RHIcon(name: iconName, size: 11, color: iconColor)
        }
    }

    private var iconName: RHIcon.IconName {
        switch field.type {
        case .imageInput: return .image
        case .password:   return .lock
        default:          return .workflow
        }
    }

    private var iconColor: Color {
        switch field.type {
        case .password: return .rhGold
        default:        return .rhAccent
        }
    }

    private var iconBgColor: Color {
        switch field.type {
        case .password: return Color.rhGold.opacity(0.12)
        default:        return Color.rhAccentSoft
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
                        .foregroundColor(.rhSecondary.opacity(0.5))
                        .padding(.top, 9)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $field.value)
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .frame(minHeight: 80, maxHeight: 160)
                    .focused($isFocused)
            }
            .padding(10)
            .background(Color.rhBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.rhAccent.opacity(0.5) : Color.rhBorder, lineWidth: 1)
            )
            .onTapGesture { isFocused = true }

        case .password:
            SecureField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.rhGold.opacity(0.5) : Color.rhBorder, lineWidth: 1)
                )
                .focused($isFocused)

        case .imageInput, .text:
            TextField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.rhAccent.opacity(0.5) : Color.rhBorder, lineWidth: 1)
                )
                .focused($isFocused)
        }
    }
}
