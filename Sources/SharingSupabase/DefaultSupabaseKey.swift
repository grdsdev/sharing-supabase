import Dependencies
import Foundation
import Supabase

extension DependencyValues {
  public var defaultSupabaseClient: SupabaseClient {
    get { self[DefaultSupabaseKey.self] }
    set { self[DefaultSupabaseKey.self] = newValue }
  }
}

private enum DefaultSupabaseKey: DependencyKey {
  static var liveValue: SupabaseClient {
    testValue
  }

  static var testValue: SupabaseClient {
    reportIssue(
      """
      A local SupabaseClient is being used. To set the default Supabase client that is used by SharingSupabase,
      use the 'prepareDependencies' tool as early as possible in the lifetime of your app,
      such as your app or scene delegate in UIKit, or the app entry point in SwiftUI:

      @main
      struct MyApp {
        init() {
          prepareDependencies {
            $0.defaultSupabaseClient = SupabaseClient(
              supabaseURL: URL(string: "https://yourapp.supabase.co")!,
              supabaseKey: "your-supabase-key"
            )
          }
        }
      }
      """)
    return SupabaseClient(
      supabaseURL: URL(string: "http://127.0.0.1:54321")!,
      supabaseKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    )
  }
}
