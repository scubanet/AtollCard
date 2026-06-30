#if os(iOS)
import SwiftUI
import PassKit

struct AddPassView: UIViewControllerRepresentable {
    let passData: Data
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let pass = try? PKPass(data: passData),
              let vc = PKAddPassesViewController(pass: pass) else {
            return UIViewController()
        }
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func addPassesViewControllerDidFinish(_ c: PKAddPassesViewController) { onFinish() }
    }
}
#endif
