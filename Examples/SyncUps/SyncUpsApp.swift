import SharingSupabase
import SwiftUI

@main
struct SyncUpsApp: App {
  static let model = AppModel()

  init() {
    prepareDependencies {
      $0.defaultSupabaseClient = .shared
    }
  }

  var body: some Scene {
    WindowGroup {
      AppView(model: Self.model)
    }
  }
}
