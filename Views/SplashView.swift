import SwiftUI

struct SplashView: View {
    @State private var showLibrary = false

    var body: some View {
        Group {
            if showLibrary {
                LibraryView()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.09, blue: 0.16),
                            Color(red: 0.12, green: 0.16, blue: 0.29)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 18) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 68, weight: .bold))
                            .foregroundStyle(.white)
                        Text("RPG Player")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 4)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLibrary = true
                }
            }
        }
    }
}
