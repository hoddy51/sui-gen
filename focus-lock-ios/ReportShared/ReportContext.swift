import DeviceActivity
import SwiftUI

// アプリ本体とレポート拡張で同じ名前を使う必要がある
extension DeviceActivityReport.Context {
    static let totalActivity = Self("TotalActivity")
}
