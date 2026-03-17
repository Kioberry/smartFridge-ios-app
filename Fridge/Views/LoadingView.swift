import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 15) {
                ProgressView().tint(.white)
                Text("AI 思考中...").foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}
