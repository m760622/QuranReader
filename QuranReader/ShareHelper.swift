import SwiftUI
import UIKit

@MainActor
class ShareHelper {
    
    /// Converts the `ShareableView` into a high-quality `UIImage`
    static func generateShareableImage(
        ayahText: String,
        surahName: String,
        ayahNumber: Int,
        translationText: String? = nil,
        isDarkMode: Bool
    ) -> UIImage? {
        let view = ShareableView(
            ayahText: ayahText,
            surahName: surahName,
            ayahNumber: ayahNumber,
            translationText: translationText,
            isDarkMode: isDarkMode
        )
        
        let renderer = ImageRenderer(content: view)
        
        // Ensure standard 1080x1080 resolution. Scale 1.0 means points = pixels.
        renderer.scale = 1.0
        
        return renderer.uiImage
    }
    
    /// Presents the native iOS share sheet (UIActivityViewController)
    static func shareImage(_ image: UIImage, sourceView: UIView? = nil) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        // Handle iPad popover to prevent crashes
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the share sheet
        rootViewController.present(activityVC, animated: true, completion: nil)
    }
}
