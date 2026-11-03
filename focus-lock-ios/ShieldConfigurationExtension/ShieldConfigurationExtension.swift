import ManagedSettings
import ManagedSettingsUI
import UIKit

/// ロックされたアプリを開いたときに出る画面の見た目
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(target: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(target: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(target: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(target: webDomain.domain ?? category.localizedDisplayName)
    }

    private func makeConfiguration(target: String?) -> ShieldConfiguration {
        let store = SharedStore.shared
        // iOS がこの画面を作るたびに呼ばれるので「開こうとした回数」の目安になる
        store.updateStats { $0.shieldShown += 1 }
        let today = store.stats(for: .now)
        let evaluation = ShieldController.evaluate()

        let subtitle = """
        \(evaluation.reasonText)

        今日ここに来た回数：\(today.shieldShown)回
        我慢できた回数：\(today.resisted)回
        """

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "\(target ?? "このアプリ")はロック中", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(white: 0.85, alpha: 1)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "閉じる（我慢する）", color: .black),
            primaryButtonBackgroundColor: UIColor(red: 0.55, green: 0.86, blue: 0.66, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "解除をリクエスト", color: UIColor(white: 0.75, alpha: 1))
        )
    }
}
