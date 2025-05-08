import NaiveDate
import Sharing
import SharingSupabase
import SwiftUI

struct RemindersListDetailView: View {
  @State.SharedReader private var remindersState: [Reminders.Record]
  @Shared private var ordering: Ordering
  @Shared private var showCompleted: Bool
  private let remindersList: RemindersList

  @State var isNewReminderSheetPresented = false

  @Dependency(\.defaultSupabaseClient) private var supabase

  enum Ordering: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case title = "Title"
    var icon: Image {
      switch self {
      case .dueDate: Image(systemName: "calendar")
      case .priority: Image(systemName: "chart.bar.fill")
      case .title: Image(systemName: "textformat.characters")
      }
    }
    var queryString: String {
      switch self {
      case .dueDate: #""date""#
      case .priority: #""priority" DESC, "isFlagged" DESC"#
      case .title: #""title""#
      }
    }
  }

  init?(remindersList: RemindersList) {
    self.remindersList = remindersList
    _remindersState = State.SharedReader(value: [])
    if let listID = remindersList.id {
      _ordering = Shared(wrappedValue: .dueDate, .appStorage("ordering_list_\(listID)"))
      _showCompleted = Shared(wrappedValue: false, .appStorage("show_completed_list_\(listID)"))
      $remindersState = SharedReader(
        wrappedValue: [],
        .supabase(
          Reminders(
            listID: listID,
            ordering: ordering,
            showCompleted: showCompleted
          )
        )
      )
    } else {
      reportIssue("'list.id' required to be non-nil.")
      return nil
    }
  }

  var body: some View {
    List {
      ForEach(remindersState, id: \.reminder.id) { reminderState in
        ReminderRow(
          isPastDue: reminderState.isPastDue,
          reminder: reminderState.reminder,
          remindersList: remindersList,
          tags: reminderState.tags
        )
      }
    }
    .task(id: [ordering, showCompleted] as [AnyHashable]) {
      await withErrorReporting {
        try await updateQuery()
      }
    }
    .navigationTitle(Text(remindersList.name))
    .navigationBarTitleDisplayMode(.large)
    .sheet(isPresented: $isNewReminderSheetPresented) {
      NavigationStack {
        ReminderFormView(remindersList: remindersList)
      }
    }
    .toolbar {
      ToolbarItem(placement: .bottomBar) {
        HStack {
          Button {
            isNewReminderSheetPresented = true
          } label: {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("New reminder")
            }
            .bold()
            .font(.title3)
          }
          Spacer()
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Menu {
            ForEach(Ordering.allCases, id: \.self) { ordering in
              Button {
                $ordering.withLock { $0 = ordering }
              } label: {
                Text(ordering.rawValue)
                ordering.icon
              }
            }
          } label: {
            Text("Sort By")
            Text(ordering.rawValue)
            Image(systemName: "arrow.up.arrow.down")
          }
          Button {
            $showCompleted.withLock { $0.toggle() }
          } label: {
            Text(showCompleted ? "Hide Completed" : "Show Completed")
            Image(systemName: showCompleted ? "eye.slash.fill" : "eye")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
  }

  private func updateQuery() async throws {
    guard let listID = remindersList.id
    else { return }

    try await $remindersState.load(
      .supabase(
        Reminders(listID: listID, ordering: ordering, showCompleted: showCompleted)
      )
    )
  }

  private struct Reminders: SupabaseKeyRequest {
    let listID: Int64
    let ordering: Ordering
    let showCompleted: Bool

    var observeTables: [String] {
      ["reminders", "reminders_tags", "tags"]
    }

    func fetch(_ client: SupabaseClient) async throws -> [Record] {
      // Fetch reminders
      var remindersQuery =
        client
        .from("reminders")
        .select()
        .eq("list_id", value: listID)

      if !showCompleted {
        remindersQuery = remindersQuery.is("is_completed", value: false)
      }

      let reminders =
        try await remindersQuery
        .order("is_completed", ascending: true)
        //        .order(ordering)
        .execute().value as [Reminder]

      // Fetch tags for each reminder
      var records = [Record]()

      for reminder in reminders {
        // TODO: need to reach for reminders_tags for fetching tags.
        let tags =
          try await client
          .from("tags")
          .select("name")
          .eq("reminder_id", value: reminder.id)
          .execute().value as [Tag]

        let commaSeparatedTags = tags.map { $0.name }.joined(separator: ",")

        let isPastDue =
          !reminder.isCompleted
          && (reminder.date ?? Calendar.current.naiveDate(from: .now))
            < Calendar.current.naiveDate(from: .now)

        let record = Record(
          reminder: reminder,
          isPastDue: isPastDue,
          commaSeparatedTags: commaSeparatedTags
        )

        records.append(record)
      }

      return records
    }

    //    func fetch(_ db: Database) throws -> [Record] {
    //      try Record
    //        .fetchAll(
    //        db,
    //        sql: """
    //        SELECT
    //          "reminders".*,
    //          group_concat("tags"."name", ',') AS "commaSeparatedTags",
    //          NOT "isCompleted" AND coalesce("reminders"."date", date('now')) < date('now') as "isPastDue"
    //        FROM "reminders"
    //        LEFT JOIN "remindersTags" ON "reminders"."id" = "remindersTags"."reminderID"
    //        LEFT JOIN "tags" ON "remindersTags"."tagID" = "tags"."id"
    //        WHERE
    //          "reminders"."listID" = ?
    //          \(showCompleted ? "" : #"AND NOT "isCompleted""#)
    //        GROUP BY "reminders"."id"
    //        ORDER BY
    //          "reminders"."isCompleted" ASC,
    //          \(ordering.queryString)
    //        """,
    //        arguments: [listID]
    //      )
    //    }
    struct Record: Decodable {
      var reminder: Reminder
      var isPastDue: Bool
      var commaSeparatedTags: String?
      var tags: [String] {
        (commaSeparatedTags ?? "").split(separator: ",").map(String.init)
      }
    }
  }
}
//
//#Preview {
//  let remindersList = prepareDependencies {
//    $0.defaultDatabase = .appDatabase
//    return try! $0.defaultDatabase.read { db in
//      try RemindersList.fetchOne(db)!
//    }
//  }
//  NavigationStack {
//    RemindersListDetailView(remindersList: remindersList)
//  }
//}
