//
//  Created by Alex.M on 06.06.2022.
//

import SwiftUI

struct LiveCameraCell: View {
    
    @Environment(\.scenePhase) private var scenePhase

    let action: () -> Void
    
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var orientation = UIDevice.current.orientation
    
    var body: some View {
        Button {
            action()
        } label: {
            LiveCameraView(
                session: cameraViewModel.captureSession,
                videoGravity: .resizeAspectFill,
                orientation: orientation
            )
            .overlay(
                Image(systemName: "camera")
                    .foregroundColor(.white)
            )
        }
        .onAppear {
            // Only start session when view appears
            Task {
                await cameraViewModel.startSession()
            }
        }
        .onDisappear {
            // Stop session when view disappears
            Task {
                await cameraViewModel.stopSession()
            }
        }
        .onChange(of: scenePhase) {
            Task {
                if scenePhase == .background {
                    await cameraViewModel.stopSession()
                } else if scenePhase == .active && self.isVisible() {
                    await cameraViewModel.startSession()
                }
            }
        }
        .onRotate { orientation = $0 }
    }
    
    // Helper method to check if view is visible
    private func isVisible() -> Bool {
        // Simple heuristic - if we're on screen, assume we're visible
        return true
    }
}
