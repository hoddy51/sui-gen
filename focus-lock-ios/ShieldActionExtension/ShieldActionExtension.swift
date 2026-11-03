import Foundation
import ManagedSettings

/// ロック画面のボタンが押されたときの処理。
/// iOS の制約でここから直接アプリを開けないため、「解除をリクエスト」は通知を出して
/// そこからアプリを開いてもらう（アプリ側で待ち時間・理由入力などのハードルを課す）。
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        let store = SharedStore.shared
        switch action {
        case .primaryButtonPressed:
            store.updateStats { $0.resisted += 1 }
            return .close
        case .secondaryButtonPressed:
            store.updateStats { $0.unlockRequests += 1 }
            store.pendingUnlockRequestAt = .now
            Notifier.send(
                id: "unlock-request",
                title: "解除の手続き",
                body: "タップして FocusLock を開いてください。本当に今必要か、もう一度考えてみましょう。"
            )
            return .defer
        @unknown default:
            return .close
        }
    }
}
