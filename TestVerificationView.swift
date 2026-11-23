import SwiftUI

struct TestVerificationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🔥🔥🔥 TEST VIEW 🔥🔥🔥")
                .font(.system(size: Theme.fontSize(40), weight: .black))
                .foregroundStyle(.red)
            
            Text("If you see this, Xcode IS compiling new code!")
                .font(.system(size: Theme.fontSize(20)))
                .multilineTextAlignment(.center)
                .padding()
            
            Text("The problem is somewhere else")
                .font(.system(size: Theme.fontSize(16)))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yellow)
    }
}

#Preview {
    TestVerificationView()
}
