import SwiftUI

// MARK: - Prompt Selector View
struct PromptSelectorView: View {
    let fields: [FormField]
    let onConfirm: ([PromptFieldSelection]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selections: [PromptFieldSelection] = []

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("检测到多个提示词输入框\n请选择需要显示的输入框")
                        .font(.system(size: 14))
                        .foregroundColor(.rhSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(selections) { selection in
                                promptFieldRow(selection)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        Button("取消") {
                            dismiss()
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.rhSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.rhCard)
                        .cornerRadius(12)

                        Button("确认") {
                            let selected = selections.filter { $0.role != .none }
                            if !selected.isEmpty {
                                onConfirm(selected)
                                dismiss()
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            selections.contains(where: { $0.role != .none })
                                ? Color.rhAccent
                                : Color.rhBorder
                        )
                        .cornerRadius(12)
                        .disabled(!selections.contains(where: { $0.role != .none }))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("选择提示词输入框")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            selections = fields.map { field in
                PromptFieldSelection(
                    nodeId: field.nodeId,
                    fieldName: field.fieldName,
                    label: field.label,
                    role: .none
                )
            }
        }
    }

    private func promptFieldRow(_ selection: PromptFieldSelection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selection.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.rhPrimary)

            HStack(spacing: 8) {
                roleButton(selection: selection, role: .none, label: "不显示")
                roleButton(selection: selection, role: .positive, label: "正向")
                roleButton(selection: selection, role: .negative, label: "负向")
            }
        }
        .padding(14)
        .background(Color.rhCard)
        .cornerRadius(14)
        .shadow(color: Color(hex: "#C8392B").opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func roleButton(selection: PromptFieldSelection, role: PromptRole, label: String) -> some View {
        Button {
            if let index = selections.firstIndex(where: { $0.id == selection.id }) {
                selections[index].role = role
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selection.role == role ? .semibold : .regular))
                .foregroundColor(selection.role == role ? .white : .rhSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection.role == role
                        ? (role == .positive ? Color.rhAccent : (role == .negative ? Color.rhWarning : Color.rhBorder))
                        : Color.rhBackground
                )
                .cornerRadius(8)
        }
    }
}
