import SharingSupabase
import SwiftUI

struct RemindersListRow: View {
  let reminderCount: Int
  let remindersList: RemindersList

  @State var editList: RemindersList?

  @Dependency(\.defaultSupabaseClient) private var supabase

  var body: some View {
    HStack {
      Image(systemName: "list.bullet.circle.fill")
        .font(.title)
        .foregroundStyle(Color.hex(remindersList.color))
      Text(remindersList.name)
      Spacer()
      Text("\(reminderCount)")
    }
    .swipeActions {
      Button {
        Task {
          await withErrorReporting {
            try await supabase.from("reminders_lists")
              .delete()
              .eq("id", value: remindersList.id?.description)
              .execute()
          }
        }
      } label: {
        Image(systemName: "trash")
      }
      .tint(.red)
      Button {
        editList = remindersList
      } label: {
        Image(systemName: "info.circle")
      }
    }
    .sheet(item: $editList) { list in
      NavigationStack {
        RemindersListForm(existingList: list)
          .navigationTitle("Edit list")
      }
      .presentationDetents([.medium])
    }
  }
}

#Preview {
  NavigationStack {
    List {
      RemindersListRow(
        reminderCount: 10,
        remindersList: RemindersList(
          name: "Personal"
        )
      )
    }
  }
}
