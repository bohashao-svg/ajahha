import SwiftUI

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        ZStack {
            Color.rhBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("人民万岁")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.rhPrimary)

                VStack(spacing: 12) {
                    TextField("用户名", text: $vm.username)
                        .font(.system(size: 14)).padding(12)
                        .background(Color.rhCard).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))
                        .autocapitalization(.none).disableAutocorrection(true)

                    SecureField("密码", text: $vm.password)
                        .font(.system(size: 14)).padding(12)
                        .background(Color.rhCard).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))

                    if let err = vm.errorMessage {
                        Text(err).font(.system(size: 12)).foregroundColor(.rhError)
                    }

                    Button { Task { await vm.login() } } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("登录").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(vm.isBlank ? Color.rhBorder : Color.rhAccent)
                        .cornerRadius(12)
                    }
                    .disabled(vm.isLoading || vm.isBlank)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
