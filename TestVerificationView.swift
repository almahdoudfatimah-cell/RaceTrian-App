import SwiftUI

struct TestVerificationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🔥🔥🔥 TEST VIEW 🔥🔥🔥")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.red)
            
            Text("If you see this, Xcode IS compiling new code!")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("The problem is somewhere else")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yellow)
    }
}

#Preview {
    TestVerificationView()
}
