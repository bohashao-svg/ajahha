import SwiftUI

// MARK: - Login View — Full-screen immersive, centered card, large brand
struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focus: Field?
    enum Field { case username, password }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                AnimatedMeshBackground()

                VStack(spacing: 0) {
                    Spacer()

                    // ── Brand block ──────────────────────────────────────
                    VStack(spacing: 10) {
                        // Logo mark
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                                .shadow(color: Color(hex: "#6C8EFF").opacity(0.5), radius: 20, y: 8)
                            Image(systemName: "sparkles")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Text("人民万岁")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("RunningHub AI 创作平台")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))
                            .tracking(1)
                    }
                    .padding(.bottom, 40)

                    // ── Form card ────────────────────────────────────────
                    VStack(spacing: 14) {
                        // Username
                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .font(.system(size: 16))
                                .foregroundColor(focus == .username ? Color(hex: "#6C8EFF") : Color.white.opacity(0.35))
                                .frame(width: 22)
                            TextField("用户名", text: $vm.username)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .tint(Color(hex: "#6C8EFF"))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focus, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 16)
                        .background(Color.white.opacity(focus == .username ? 0.12 : 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(focus == .username ? Color(hex: "#6C8EFF") : Color.clear, lineWidth: 1.5)
                        )
                        .animation(.easeOut(duration: 0.18), value: focus)

                        // Password
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(.system(size: 16))
                                .foregroundColor(focus == .password ? Color(hex: "#6C8EFF") : Color.white.opacity(0.35))
                                .frame(width: 22)
                            SecureField("密码", text: $vm.password)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .tint(Color(hex: "#6C8EFF"))
                                .focused($focus, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { if !vm.isBlank { Task { await vm.login() } } }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 16)
                        .background(Color.white.opacity(focus == .password ? 0.12 : 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(focus == .password ? Color(hex: "#6C8EFF") : Color.clear, lineWidth: 1.5)
                        )
                        .animation(.easeOut(duration: 0.18), value: focus)

                        // Error
                        if let err = vm.errorMessage {
                            Label(err, systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Login button
                        Button {
                            focus = nil
                            Task { await vm.login() }
                        } label: {
                            ZStack {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("登 录")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                        .tracking(6)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(
                                vm.isBlank
                                ? AnyShapeStyle(Color.white.opacity(0.1))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: vm.isBlank ? .clear : Color(hex: "#6C8EFF").opacity(0.5), radius: 14, y: 6)
                        }
                        .disabled(vm.isLoading || vm.isBlank)
                        .buttonStyle(LiquidButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
                    .padding(.horizontal, 24)

                    Spacer()

                    Text("登录即代表同意服务条款与隐私政策")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.25))
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
                }
            }
        }
        .ignoresSafeArea()
        .onTapGesture { focus = nil }
    }
}
