import SwiftUI

struct WelcomeView: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "refrigerator.fill")
                .font(.system(size: 80))
                .foregroundColor(BrandColors.primary)

            VStack(spacing: 10) {
                Text("欢迎使用智能冰箱")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("拍张照片，让AI来帮你整理库存、规划菜单，开启智能厨房生活。")
                    .font(.body)
                    .foregroundColor(BrandColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: onStart) {
                Text("让我们开始吧")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
        }
    }
}
