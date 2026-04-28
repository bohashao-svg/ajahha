import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    var body: some View {
        ZStack {
            Color.rhBackground.ignoresSafeArea()

            // Background doodles
            Canvas { ctx, size in
                let s = size
                var c1 = Path(); c1.addEllipse(in: CGRect(x: s.width*0.05, y: s.height*0.04, width: 70, height: 70))
                ctx.stroke(c1, with: .color(Color.rhInk.opacity(0.04)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                var c2 = Path(); c2.addEllipse(in: CGRect(x: s.width*0.78, y: s.height*0.08, width: 50, height: 50))
                ctx.stroke(c2, with: .color(Color.rhAccent.opacity(0.05)), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                var c3 = Path(); c3.addEllipse(in: CGRect(x: s.width*0.82, y: s.height*0.72, width: 80, height: 80))
                ctx.stroke(c3, with: .color(Color.rhInk.opacity(0.04)), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.rhRedMuted)
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Color.rhAccent, lineWidth: 2))
                            .shadow(color: Color.rhInk.opacity(0.15), radius: 0, x: 3, y: 3)
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                    }
                    Text("人民万岁")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.rhPrimary)
                    Text("RunningHub AI 创作平台")
                        .font(.system(size: 13))
                        .foregroundColor(.rhSecondary)
                }

                Spacer().frame(height: 40)

                // Form card
                VStack(spacing: 16) {
                    // Username
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
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 12))
                    .overlay(SketchRoundedRect(radius: 12).stroke(
                        focusedField == .username ? Color.rhAccent : Color.rhInk.opacity(0.2),
                        lineWidth: focusedField == .username ? 2 : 1.5
                    ))

                    // Password
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
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 12))
                    .overlay(SketchRoundedRect(radius: 12).stroke(
                        focusedField == .password ? Color.rhAccent : Color.rhInk.opacity(0.2),
                        lineWidth: focusedField == .password ? 2 : 1.5
                    ))

                    if let err = vm.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
                            Text(err).font(.system(size: 12))
                        }
                        .foregroundColor(.rhError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -4)
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
                                Text("登 录")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .tracking(4)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(vm.isBlank ? Color.rhBorder : Color.rhAccent)
                        .clipShape(SketchRoundedRect(radius: 12))
                        .overlay(SketchRoundedRect(radius: 12).stroke(
                            vm.isBlank ? Color.rhBorder : Color.rhInk.opacity(0.3), lineWidth: 1.5
                        ))
                        .shadow(color: Color.rhInk.opacity(vm.isBlank ? 0 : 0.18), radius: 0, x: 2, y: 3)
                    }
                    .disabled(vm.isLoading || vm.isBlank)
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color.rhCard)
                .clipShape(SketchRoundedRect(radius: 18))
                .overlay(SketchRoundedRect(radius: 18).stroke(Color.rhInk.opacity(0.2), lineWidth: 1.8))
                .shadow(color: Color.rhInk.opacity(0.14), radius: 0, x: 3, y: 4)
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
