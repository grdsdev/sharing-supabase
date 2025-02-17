import Dependencies
import SharingSupabase
import IssueReporting
import SwiftUI

struct RemindersListForm: View {
  @Dependency(\.defaultSupabaseClient) private var supabase

  @State var remindersList: RemindersList
  @Environment(\.dismiss) var dismiss

  init(existingList: RemindersList? = nil) {
    if let existingList {
      _remindersList = State(wrappedValue: existingList)
    } else {
      _remindersList = State(wrappedValue: RemindersList())
    }
  }

  var body: some View {
    Form {
      TextField("Name", text: $remindersList.name)
      ColorPicker("Color", selection: $remindersList.color.cgColor)
    }
    .toolbar {
      ToolbarItem {
        Button("Save") {
          Task {
            await withErrorReporting {
              do {
                try await supabase.from("reminders_lists").insert(remindersList).execute()
              }
            }
            dismiss()
          }
        }
      }
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
    }
  }
}

extension Int {
  fileprivate var cgColor: CGColor {
    get {
      CGColor(
        red: Double((self >> 16) & 0xFF) / 255.0,
        green: Double((self >> 8) & 0xFF) / 255.0,
        blue: Double(self & 0xFF) / 255.0,
        alpha: 1
      )
    }
    set {
      guard let components = newValue.components
      else { return }
      self = (Int(components[0] * 255) << 16)
        | (Int(components[1] * 255) << 8)
        | Int(components[2] * 255)
    }
  }
}

#Preview {
  let _ = prepareDependencies { $0.defaultSupabaseClient = .shared }
  NavigationStack {
    RemindersListForm()
  }
}
