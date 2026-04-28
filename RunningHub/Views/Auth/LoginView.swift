import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.rhBackground, Color.rhCard],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo 区域
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.rhAccent.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(.rhAccent)
                    }
                    Text("人民万岁")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.rhPrimary)
                    Text("RunningHub AI 创作平台")
                        .font(.system(size: 13))
                        .foregroundColor(.rhSecondary)
                }

                Spacer().frame(height: 44)

                // 表单卡片
                VStack(spacing: 16) {
                    // 用户名
                    HStack(spacing: 10) {
                        Image(systemName: "person")
                            .font(.system(size: 15))
                            .foregroundColor(focusedField == .username ? .rhAccent : .rhSecondary)
                            .frame(width: 20)
                        TextField("用户名", text: $vm.username)
                            .font(.system(size: 15))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.rhBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .username ? Color.rhAccent : Color.rhBorder, lineWidth: 1.5)
                    )

                    // 密码
                    HStack(spacing: 10) {
                        Image(systemName: "lock")
                            .font(.system(size: 15))
                            .foregroundColor(focusedField == .password ? .rhAccent : .rhSecondary)
                            .frame(width: 20)
                        SecureField("密码", text: $vm.password)
                            .font(.system(size: 15))
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if !vm.isBlank { Task { await vm.login() } } }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.rhBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .password ? Color.rhAccent : Color.rhBorder, lineWidth: 1.5)
                    )

                    // 错误提示
                    if let err = vm.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(err).font(.system(size: 12))
                        }
                        .foregroundColor(.rhError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -4)
                    }

                    // 登录按钮
                    Button {
                        focusedField = nil
                        Task { await vm.login() }
                    } label: {
                        ZStack {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("登录")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            vm.isBlank
                                ? Color.rhBorder
                                : Color.rhAccent
                        )
                        .cornerRadius(14)
                    }
                    .disabled(vm.isLoading || vm.isBlank)
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color.rhCard)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
                .padding(.horizontal, 24)

                Spacer()

                Text("登录即代表同意服务条款与隐私政策")
                    .font(.system(size: 11))
                    .foregroundColor(.rhSecondary.opacity(0.6))
                    .padding(.bottom, 32)
            }
        }
        .onTapGesture { focusedField = nil }
    }
}
