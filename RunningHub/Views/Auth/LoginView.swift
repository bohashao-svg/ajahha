import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            // Floating glass orbs decoration
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Circle()
                    .fill(Color(hex: "#6C8EFF").opacity(0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .offset(x: w * 0.6, y: h * 0.1)
                Circle()
                    .fill(Color(hex: "#A78BFA").opacity(0.06))
                    .frame(width: 160, height: 160)
                    .blur(radius: 25)
                    .offset(x: w * 0.05, y: h * 0.65)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo section
                VStack(spacing: 14) {
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(Color(hex: "#6C8EFF").opacity(0.15))
                            .frame(width: 100, height: 100)
                            .blur(radius: 16)

                        // Glass container
                        LiquidGlassShape(radius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                LiquidGlassShape(radius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.3), radius: 20, x: 0, y: 0)

                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("人民万岁")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )

                    Text("RunningHub AI 创作平台")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#8B9CC8"))
                        .tracking(0.5)
                }

                Spacer().frame(height: 44)

                // Form glass card
                VStack(spacing: 16) {
                    // Username field
                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(focusedField == .username ? Color(hex: "#6C8EFF") : Color(hex: "#8B9CC8"))
                            .frame(width: 20)
                            .animation(.easeInOut(duration: 0.2), value: focusedField)

                        TextField("用户名", text: $vm.username)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#F0F4FF"))
                            .tint(Color(hex: "#6C8EFF"))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(
                        LiquidGlassShape(radius: 14)
                            .fill(Color.white.opacity(focusedField == .username ? 0.1 : 0.05))
                    )
                    .overlay(
                        LiquidGlassShape(radius: 14)
                            .stroke(
                                focusedField == .username
                                    ? Color(hex: "#6C8EFF").opacity(0.7)
                                    : Color.white.opacity(0.1),
                                lineWidth: focusedField == .username ? 1.5 : 0.8
                            )
                    )
                    .shadow(
                        color: focusedField == .username ? Color(hex: "#6C8EFF").opacity(0.2) : .clear,
                        radius: 12, x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField)

                    // Password field
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(focusedField == .password ? Color(hex: "#6C8EFF") : Color(hex: "#8B9CC8"))
                            .frame(width: 20)
                            .animation(.easeInOut(duration: 0.2), value: focusedField)

                        SecureField("密码", text: $vm.password)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#F0F4FF"))
                            .tint(Color(hex: "#6C8EFF"))
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if !vm.isBlank { Task { await vm.login() } } }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(
                        LiquidGlassShape(radius: 14)
                            .fill(Color.white.opacity(focusedField == .password ? 0.1 : 0.05))
                    )
                    .overlay(
                        LiquidGlassShape(radius: 14)
                            .stroke(
                                focusedField == .password
                                    ? Color(hex: "#6C8EFF").opacity(0.7)
                                    : Color.white.opacity(0.1),
                                lineWidth: focusedField == .password ? 1.5 : 0.8
                            )
                    )
                    .shadow(
                        color: focusedField == .password ? Color(hex: "#6C8EFF").opacity(0.2) : .clear,
                        radius: 12, x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField)

                    // Error message
                    if let err = vm.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(err).font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Login button
                    Button {
                        focusedField = nil
                        Task { await vm.login() }
                    } label: {
                        ZStack {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 16))
                                    Text("登 录")
                                        .font(.system(size: 16, weight: .semibold))
                                        .tracking(4)
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(
                            Group {
                                if vm.isBlank {
                                    LiquidGlassShape(radius: 14)
                                        .fill(Color.white.opacity(0.06))
                                } else {
                                    LiquidGlassShape(radius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        )
                        .overlay(
                            LiquidGlassShape(radius: 14)
                                .stroke(
                                    vm.isBlank
                                        ? Color.white.opacity(0.08)
                                        : Color.white.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: vm.isBlank ? .clear : Color(hex: "#6C8EFF").opacity(0.5),
                            radius: 16, x: 0, y: 4
                        )
                    }
                    .disabled(vm.isLoading || vm.isBlank)
                    .buttonStyle(LiquidButtonStyle())
                    .padding(.top, 4)
                }
                .padding(24)
                .background(
                    ZStack {
                        LiquidGlassShape(radius: 24)
                            .fill(Color(hex: "#111827").opacity(0.7))
                        LiquidGlassShape(radius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    LiquidGlassShape(radius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 12)
                .shadow(color: Color(hex: "#6C8EFF").opacity(0.06), radius: 50, x: 0, y: 0)
                .padding(.horizontal, 24)

                Spacer()

                Text("登录即代表同意服务条款与隐私政策")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8B9CC8").opacity(0.5))
                    .padding(.bottom, 36)
            }
        }
        .onTapGesture { focusedField = nil }
    }
}
