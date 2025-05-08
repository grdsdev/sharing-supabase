import Foundation
import Supabase
import IssueReporting
import SharingSupabase
import NaiveDate

extension Int64: @retroactive URLQueryRepresentable {
  public var queryValue: String {
    self.description
  }
}

struct RemindersList: Codable, Hashable, Identifiable {
  static let databaseTableName = "reminders_lists"

  var id: Int64?
  var color = 0x4a99ef
  var name = ""
}

struct Reminder: Codable, Equatable, Identifiable {
  static let databaseTableName = "reminders"

  var id: Int64?
  var date: NaiveDate?
  var isCompleted = false
  var isFlagged = false
  var listID: Int64
  var notes = ""
  var priority: Int?
  var title = ""

  enum CodingKeys: String, CodingKey {
    case id
    case date = "due_date"
    case isCompleted = "is_completed"
    case isFlagged = "is_flagged"
    case listID = "list_id"
    case notes
    case priority
    case title
  }
}

struct Tag: Codable {
  static let databaseTableName = "tags"

  var id: Int64?
  var name = ""
}

struct ReminderTag: Codable {
  static let databaseTableName = "remindersTags"

  var reminderID: Int64?
  var tagID: Int64?

  enum CodingKeys: String, CodingKey {
    case reminderID = "reminder_id"
    case tagID = "tag_id"
  }
}

extension SupabaseClient {
  static var shared: SupabaseClient {
    SupabaseClient(
      supabaseURL: URL(string: "http://proxyman.debug:54321")!,
      supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
      options: SupabaseClientOptions(global: .init(logger: ConsoleLog()))
    )
  }
}

struct ConsoleLog: SupabaseLogger {
  func log(message: SupabaseLogMessage) {
    print(message.description)
  }
}

//extension DatabaseReader where Self == DatabaseQueue {
//  static var appDatabase: Self {
//    let databaseQueue: DatabaseQueue
//    var configuration = Configuration()
//    configuration.foreignKeysEnabled = true
//    configuration.prepareDatabase { db in
//      #if DEBUG
//        db.trace(options: .profile) {
//          print($0.expandedDescription)
//        }
//      #endif
//    }
//    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil && !isTesting {
//      let path = URL.documentsDirectory.appending(component: "db.sqlite").path()
//      print("open", path)
//      databaseQueue = try! DatabaseQueue(path: path, configuration: configuration)
//    } else {
//      databaseQueue = try! DatabaseQueue(configuration: configuration)
//    }
//    var migrator = DatabaseMigrator()
//    #if DEBUG
//      migrator.eraseDatabaseOnSchemaChange = true
//    #endif
//    defer {
//      #if DEBUG
//      migrator.registerMigration("Add mock data") { db in
//        try db.createMockData()
//      }
//      #endif
//      try! migrator.migrate(databaseQueue)
//    }
//    migrator.registerMigration("Add reminders lists table") { db in
//      try db.create(table: RemindersList.databaseTableName) { table in
//        table.autoIncrementedPrimaryKey("id")
//        table.column("color", .integer).defaults(to: 0x4a99ef).notNull()
//        table.column("name", .text).notNull()
//      }
//    }
//    migrator.registerMigration("Add reminders table") { db in
//      try db.create(table: Reminder.databaseTableName) { table in
//        table.autoIncrementedPrimaryKey("id")
//        table.column("date", .date)
//        table.column("isCompleted", .boolean).defaults(to: false).notNull()
//        table.column("isFlagged", .boolean).defaults(to: false).notNull()
//        table.column("listID", .integer)
//          .references(RemindersList.databaseTableName, column: "id", onDelete: .cascade)
//          .notNull()
//        table.column("notes", .text).notNull()
//        table.column("priority", .integer)
//        table.column("title", .text).notNull()
//      }
//    }
//    migrator.registerMigration("Add tags table") { db in
//      try db.create(table: Tag.databaseTableName) { table in
//        table.autoIncrementedPrimaryKey("id")
//        table.column("name", .text).notNull().collate(.nocase).unique()
//      }
//      try db.create(table: ReminderTag.databaseTableName) { table in
//        table.column("reminderID", .integer).notNull()
//          .references(Reminder.databaseTableName, column: "id", onDelete: .cascade)
//        table.column("tagID", .integer).notNull()
//          .references(Tag.databaseTableName, column: "id", onDelete: .cascade)
//      }
//    }
//
//    return databaseQueue
//  }
//}
//
//#if DEBUG
//  extension Database {
//    func createMockData() throws {
//      try createDebugRemindersLists()
//      try createDebugReminders()
//      try createDebugTags()
//    }
//
//    func createDebugRemindersLists() throws {
//      _ = try RemindersList(color: 0x4a99ef, name: "Personal").inserted(self)
//      _ = try RemindersList(color: 0xed8935, name: "Family").inserted(self)
//      _ = try RemindersList(color: 0xb25dd3, name: "Business").inserted(self)
//    }
//
//    func createDebugReminders() throws {
//      _ = try Reminder(
//        date: Date(),
//        listID: 1,
//        notes: "Milk\nEggs\nApples\nOatmeal\nSpinach",
//        title: "Groceries"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(-60 * 60 * 24 * 2),
//        isFlagged: true,
//        listID: 1,
//        title: "Haircut"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date(),
//        listID: 1,
//        notes: "Ask about diet",
//        priority: 3,
//        title: "Doctor appointment"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(-60 * 60 * 24 * 190),
//        isCompleted: true,
//        listID: 1,
//        title: "Take a walk"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date(),
//        listID: 1,
//        title: "Buy concert tickets"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(60 * 60 * 24 * 2),
//        isFlagged: true,
//        listID: 2,
//        priority: 3,
//        title: "Pick up kids from school"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(-60 * 60 * 24 * 2),
//        isCompleted: true,
//        listID: 2,
//        priority: 1,
//        title: "Get laundry"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(60 * 60 * 24 * 4),
//        isCompleted: false,
//        listID: 2,
//        priority: 3,
//        title: "Take out trash"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(60 * 60 * 24 * 2),
//        listID: 3,
//        notes: """
//          Status of tax return
//          Expenses for next year
//          Changing payroll company
//          """,
//        title: "Call accountant"
//      )
//      .inserted(self)
//      _ = try Reminder(
//        date: Date().addingTimeInterval(-60 * 60 * 24 * 2),
//        isCompleted: true,
//        listID: 3,
//        priority: 2,
//        title: "Send weekly emails"
//      )
//      .inserted(self)
//    }
//
//    func createDebugTags() throws {
//      _ = try Tag(name: "car").inserted(self)
//      _ = try Tag(name: "kids").inserted(self)
//      _ = try Tag(name: "someday").inserted(self)
//      _ = try Tag(name: "optional").inserted(self)
//      _ = try ReminderTag(reminderID: 1, tagID: 3).inserted(self)
//      _ = try ReminderTag(reminderID: 1, tagID: 4).inserted(self)
//      _ = try ReminderTag(reminderID: 2, tagID: 3).inserted(self)
//      _ = try ReminderTag(reminderID: 2, tagID: 4).inserted(self)
//      _ = try ReminderTag(reminderID: 4, tagID: 1).inserted(self)
//      _ = try ReminderTag(reminderID: 4, tagID: 2).inserted(self)
//    }
//  }
//#endif
