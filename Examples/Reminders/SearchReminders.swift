import IssueReporting
import SharingSupabase
import SwiftUI

struct SearchRemindersView: View {
  @State.SharedReader(value: SearchReminders.Value()) var searchReminders

  let searchText: String
  @State var showCompletedInSearchResults = false

  @Dependency(\.defaultSupabaseClient) private var supabase

  init(searchText: String) {
    self.searchText = searchText
    $searchReminders = SharedReader(
      wrappedValue: searchReminders,
      .supabase(
        SearchReminders(
          showCompletedInSearchResults: showCompletedInSearchResults,
          searchText: searchText
        )
      )
    )
  }

  var body: some View {
    HStack {
      Text("\(searchReminders.completedCount) Completed")
        .monospacedDigit()
        .contentTransition(.numericText())
      if searchReminders.completedCount > 0 {
        Text("•")
        Menu {
          Text("Clear Completed Reminders")
          Button("Older Than 1 Month") { deleteCompletedReminders(monthsAgo: 1) }
          Button("Older Than 6 Months") { deleteCompletedReminders(monthsAgo: 6) }
          Button("Older Than 1 year") { deleteCompletedReminders(monthsAgo: 12) }
          Button("All Completed") { deleteCompletedReminders() }
        } label: {
          Text("Clear")
        }
        Spacer()
        if showCompletedInSearchResults {
          Button("Hide") {
            showCompletedInSearchResults = false
          }
        } else {
          Button("Show") {
            showCompletedInSearchResults = true
          }
        }
      }
    }
    .buttonStyle(.borderless)
    .task(id: [searchText, showCompletedInSearchResults] as [AnyHashable]) {
      await withErrorReporting {
        try await updateSearchQuery()
      }
    }

    ForEach(searchReminders.reminders, id: \.reminder.id) { reminder in
      ReminderRow(
        isPastDue: reminder.isPastDue,
        reminder: reminder.reminder,
        remindersList: reminder.remindersList,
        tags: (reminder.commaSeparatedTags ?? "").split(separator: ",").map(String.init)
      )
    }
  }

  private func updateSearchQuery() async throws {
    if searchText.isEmpty {
      showCompletedInSearchResults = false
    }
    try await $searchReminders.load(
      .supabase(
        SearchReminders(
          showCompletedInSearchResults: showCompletedInSearchResults,
          searchText: searchText
        )
      )
    )
  }

  private func deleteCompletedReminders(monthsAgo: Int? = nil) {
    Task {
      await withErrorReporting {
        let baseQuery = searchQueryBase(searchText: searchText)

        let query = baseQuery(supabase.from("reminders").delete())
          .is("is_completed", value: true)

        if let monthsAgo {
          // TODO: check how to do this date filter.
          try await query.lte("date", value: "date('now', '-\(monthsAgo) months')")
            .execute()
        } else {
          try await query.execute()
        }
      }
    }
  }

  struct SearchReminders: SupabaseKeyRequest {
    let showCompletedInSearchResults: Bool
    let searchText: String

    var observeTables: [String] { ["reminders", "reminders_lists", "tags"] }

    func fetch(_ client: SupabaseClient) async throws -> Value {
      Value()
    }
    //    func fetch(_ db: Database) throws -> Value {
    //      struct LocalRequest: Decodable, FetchableRecord {
    //        var isPastDue: Bool
    //        let reminder: Reminder
    //        let remindersListID: Int64
    //        let commaSeparatedTags: String?
    //      }
    //      let reminders = try LocalRequest.fetchAll(
    //        db,
    //        SQLRequest(literal: """
    //          SELECT
    //            "reminders".*,
    //            "remindersLists"."id" AS "remindersListID",
    //            group_concat("tags"."name", ',') AS "commaSeparatedTags",
    //            NOT "isCompleted" AND coalesce("reminders"."date", date('now')) < date('now') AS "isPastDue"
    //          FROM "reminders"
    //          LEFT JOIN "remindersLists" ON "reminders"."listID" = "remindersLists"."id"
    //          LEFT JOIN "remindersTags" ON "reminders"."id" = "remindersTags"."reminderID"
    //          LEFT JOIN "tags" ON "remindersTags"."tagID" = "tags"."id"
    //          WHERE
    //            (
    //              "reminders"."title" COLLATE NOCASE LIKE \("%\(searchText)%")
    //                OR "reminders"."notes" COLLATE NOCASE LIKE \("%\(searchText)%")
    //            )
    //            \(sql: showCompletedInSearchResults ? "" : #"AND NOT "reminders"."isCompleted""#)
    //          GROUP BY "reminders"."id"
    //          ORDER BY
    //            "reminders"."isCompleted", "reminders"."date"
    //          """)
    //      )

    // NB: We are loading lists as a separate query because we are not sure how to join
    //     "remindersLists" into the above query and decode it into 'State'. Ideally this
    //     could all be done with a single query.
    //      let remindersLists = try RemindersList.fetchAll(
    //        db,
    //        keys: Set(reminders.map(\.remindersListID))
    //      )
    //
    //      let completedCount = try searchQueryBase(searchText: searchText)
    //        .filter(Column("isCompleted"))
    //        .fetchCount(db)
    //
    //      return Value(
    //        completedCount: completedCount,
    //        reminders: reminders.map { reminder in
    //          Value.Reminder(
    //            isPastDue: reminder.isPastDue,
    //            reminder: reminder.reminder,
    //            remindersList: remindersLists.first(where: { $0.id == reminder.reminder.listID} )!,
    //            commaSeparatedTags: reminder.commaSeparatedTags
    //          )
    //        }
    //      )
    //    }
    struct Value {
      var completedCount = 0
      var reminders: [Reminder] = []
      struct Reminder: Decodable {
        var isPastDue: Bool
        let reminder: Reminders.Reminder
        let remindersList: RemindersList
        let commaSeparatedTags: String?
      }
    }
  }
}

private func searchQueryBase(searchText: String) -> (PostgrestFilterBuilder) ->
  PostgrestFilterBuilder
{
  // TODO: implement correct filter
  {
    $0
      .ilike("title", pattern: "%\(searchText.lowercased())%")
  }
  //  Reminder
  //    .filter(
  //      Column("title").collating(.nocase).like("%\(searchText.lowercased())%")
  //        || Column("notes").collating(.nocase).like("%\(searchText.lowercased())%")
  //    )
}

//#Preview {
//  @Previewable @State var searchText = "take"
//  let _ = prepareDependencies {
//    $0.defaultDatabase = .appDatabase
//  }
//
//  NavigationStack {
//    List {
//      if !searchText.isEmpty {
//        SearchRemindersView(searchText: searchText)
//      } else {
//        Text(#"Tap "Search"..."#)
//      }
//    }
//    .searchable(text: $searchText)
//  }
//}
