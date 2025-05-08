import Dependencies
import Sharing
import SharingSupabase
import Supabase
import SwiftUI

struct RemindersListsView: View {
  @SharedReader(.supabase(RemindersLists())) private var lists = []
  @SharedReader(.supabase(Stats())) private var stats = Stats.Value()

  @State private var isAddListPresented = false
  @State private var searchText = ""

  @Dependency(\.defaultSupabaseClient) private var supabase

  var body: some View {
    List {
      if searchText.isEmpty {
        Section {
          Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
              ReminderGridCell(
                color: .blue,
                count: stats.todayCount,
                iconName: "calendar.circle.fill",
                title: "Today"
              ) {}
              ReminderGridCell(
                color: .red,
                count: stats.scheduledCount,
                iconName: "calendar.circle.fill",
                title: "Scheduled"
              ) {}
            }
            GridRow {
              ReminderGridCell(
                color: .gray,
                count: stats.allCount,
                iconName: "tray.circle.fill",
                title: "All"
              ) {}
              ReminderGridCell(
                color: .orange,
                count: stats.flaggedCount,
                iconName: "flag.circle.fill",
                title: "Flagged"
              ) {}
            }
            GridRow {
              ReminderGridCell(
                color: .gray,
                count: stats.completedCount,
                iconName: "checkmark.circle.fill",
                title: "Completed"
              ) {}
            }
          }
        }
        .buttonStyle(.plain)

        Section {
          ForEach(lists, id: \.remindersList.id) { state in
            NavigationLink {
              RemindersListDetailView(remindersList: state.remindersList)
            } label: {
              RemindersListRow(
                reminderCount: state.reminderCount,
                remindersList: state.remindersList
              )
            }
          }
        } header: {
          Text("My lists")
            .font(.largeTitle)
            .bold()
            .foregroundStyle(.black)
        }
      } else {
        SearchRemindersView(searchText: searchText)
      }
    }
    // NB: This explicit view identity works around a bug with 'List' view state not getting reset.
    .id(searchText)
    .listStyle(.plain)
    .toolbar {
      Button("Add list") {
        isAddListPresented = true
      }
    }
    .sheet(isPresented: $isAddListPresented) {
      NavigationStack {
        RemindersListForm()
          .navigationTitle("New list")
      }
      .presentationDetents([.medium])
    }
    .sheet(isPresented: $isAddListPresented) {
      NavigationStack {
        RemindersListForm()
          .navigationTitle("New list")
      }
      .presentationDetents([.medium])
    }
    .searchable(text: $searchText)
  }

  private struct RemindersLists: SupabaseKeyRequest {
    var observeTables: [String] {
      [
        Reminders.RemindersList.databaseTableName,
        Reminders.Reminder.databaseTableName,
      ]
    }

    func fetch(_ client: SupabaseClient) async throws -> [Record] {
      let remindersLists =
        try await client.from(Reminders.RemindersList.databaseTableName).select().execute().value
        as [Reminders.RemindersList]

      var records: [Record] = []
      for list in remindersLists {
        let count =
          try await client.from(Reminder.databaseTableName).select(head: true, count: .exact)
          .execute().count ?? 0

        records.append(Record(reminderCount: count, remindersList: list))
      }

      return records
    }
    struct Record: Decodable {
      var reminderCount: Int
      var remindersList: RemindersList
    }
  }
  private struct Stats: SupabaseKeyRequest {
    var observeTables: [String] { ["reminders"] }

    func fetch(_ client: SupabaseClient) async throws -> Value {
      let now = Date()

      async let todayCount =
        client.from(Reminder.databaseTableName)
        .select(head: true, count: .exact)
        .gte("date", value: now)
        .lte("date", value: now)
        .execute().count ?? 0

      async let allCount =
        client.from(Reminder.databaseTableName)
        .select(head: true, count: .exact).execute().count ?? 0

      async let scheduledCount =
        client.from(Reminder.databaseTableName)
        .select(head: true, count: .exact)
        .gt("date", value: now)
        .execute().count ?? 0

      async let flaggedCount =
        client.from(Reminder.databaseTableName)
        .select(head: true, count: .exact)
        .is("is_flagged", value: true)
        .execute().count ?? 0

      async let completedCount =
        client.from(Reminder.databaseTableName)
        .select(head: true, count: .exact)
        .is("is_completed", value: true)
        .execute().count ?? 0

      return try await Value(
        allCount: allCount,
        completedCount: completedCount,
        flaggedCount: flaggedCount,
        scheduledCount: scheduledCount,
        todayCount: todayCount
      )
    }

    struct Value {
      var allCount = 0
      var completedCount = 0
      var flaggedCount = 0
      var scheduledCount = 0
      var todayCount = 0
    }
  }
}

private struct ReminderGridCell: View {
  let color: Color
  let count: Int
  let iconName: String
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top) {
        VStack(alignment: .leading) {
          Image(systemName: iconName)
            .font(.largeTitle)
            .bold()
            .foregroundStyle(color)
          Text(title)
            .bold()
        }
        Spacer()
        Text("\(count)")
          .font(.largeTitle)
          .fontDesign(.rounded)
          .bold()
      }
      .padding()
      .background(.black.opacity(0.05))
      .cornerRadius(10)
    }
  }
}

#Preview {
  let _ = prepareDependencies {
    $0.defaultSupabaseClient = .shared
  }
  NavigationStack {
    RemindersListsView()
  }
}
