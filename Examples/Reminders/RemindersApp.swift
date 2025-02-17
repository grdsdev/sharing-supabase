import Dependencies
import Supabase
import SwiftUI

@main
struct RemindersApp: App {
  init() {
    prepareDependencies {
      $0.defaultSupabaseClient = .shared
    }
  }
  
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        RemindersListsView()
      }
    }
  }
}
