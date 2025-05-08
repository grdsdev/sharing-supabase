import Dependencies
import SharingSupabase
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpFormModel: Identifiable {
  var attendees: [AttendeeDraft] = []
  var focus: Field?
  var isDismissed = false
  var syncUp: SyncUp

  @ObservationIgnored @Dependency(\.defaultSupabaseClient) var supabase
  @ObservationIgnored @Dependency(\.uuid) var uuid

  struct AttendeeDraft: Identifiable {
    let id: UUID
    var name = ""
  }

  enum Field: Hashable {
    case attendee(AttendeeDraft.ID)
    case title
  }

  init(
    syncUp: SyncUp,
    attendees: [Attendee] = [],
    focus: Field? = .title
  ) {
    self.syncUp = syncUp
    self.attendees = attendees.map { AttendeeDraft(id: uuid(), name: $0.name) }
    if attendees.isEmpty {
      self.attendees.append(AttendeeDraft(id: uuid()))
    }
    self.focus = focus
  }

  func deleteAttendees(atOffsets indices: IndexSet) {
    attendees.remove(atOffsets: indices)
    if attendees.isEmpty {
      attendees.append(AttendeeDraft(id: uuid()))
    }
    guard let firstIndex = indices.first
    else { return }
    let index = min(firstIndex, attendees.count - 1)
    focus = .attendee(attendees[index].id)
  }

  func addAttendeeButtonTapped() {
    let attendee = AttendeeDraft(id: uuid())
    attendees.append(attendee)
    focus = .attendee(attendee.id)
  }

  func cancelButtonTapped() {
    isDismissed = true
  }

  func saveButtonTapped() async {
    attendees.removeAll { attendee in
      attendee.name.allSatisfy(\.isWhitespace)
    }
    if attendees.isEmpty {
      attendees.append(SyncUpFormModel.AttendeeDraft(id: uuid()))
    }
    await withErrorReporting {
      try await supabase.from(SyncUp.tableName)
        .upsert(syncUp)
        .eq("id", value: syncUp.id)
        .execute()

      try await withThrowingDiscardingTaskGroup { [supabase, syncUp, attendees] group in
        group.addTask {
          try await supabase.from(Attendee.tableName)
            .delete()
            .eq("syncup_id", value: syncUp.id)
            .execute()
        }

        group.addTask {
          try await supabase.from(Attendee.tableName)
            .insert(attendees.map {
              AnyJSON.object([
                "id": .string($0.id.uuidString),
                "name": .string($0.name),
                "syncup_id": .string(syncUp.id.uuidString)
              ])
            })
            .execute()
        }
      }
    }
    isDismissed = true
  }
}

struct SyncUpFormView: View {
  @Environment(\.dismiss) var dismiss
  @FocusState var focus: SyncUpFormModel.Field?
  @Bindable var model: SyncUpFormModel

  var body: some View {
    Form {
      Section {
        TextField("Title", text: $model.syncUp.title)
          .focused($focus, equals: .title)
        HStack {
          Slider(value: $model.syncUp.duration.seconds, in: 5...30, step: 1) {
            Text("Length")
          }
          Spacer()
          Text(model.syncUp.duration.formatted(.units()))
        }
        ThemePicker(selection: $model.syncUp.theme)
      } header: {
        Text("Sync-up Info")
      }
      Section {
        ForEach($model.attendees) { $attendee in
          TextField("Name", text: $attendee.name)
            .focused($focus, equals: .attendee(attendee.id))
        }
        .onDelete { indices in
          model.deleteAttendees(atOffsets: indices)
        }

        Button("New attendee") {
          model.addAttendeeButtonTapped()
        }
      } header: {
        Text("Attendees")
      }
    }
    .bind($model.focus, to: $focus)
    .onChange(of: model.isDismissed) {
      dismiss()
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          model.cancelButtonTapped()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          Task {
            await model.saveButtonTapped()
          }
        }
      }
    }
  }
}

struct ThemePicker: View {
  @Binding var selection: Theme

  var body: some View {
    Picker("Theme", selection: $selection) {
      ForEach(Theme.allCases) { theme in
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(theme.mainColor)
          Label(theme.name, systemImage: "paintpalette")
            .padding(4)
        }
        .foregroundColor(theme.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .tag(theme)
      }
    }
  }
}

extension Duration {
  fileprivate var seconds: Double {
    get { Double(components.seconds / 60) }
    set { self = .seconds(newValue * 60) }
  }
}

#Preview {
  NavigationStack {
    SyncUpFormView(
      model: SyncUpFormModel(
        syncUp: SyncUp(id: UUID())
      )
    )
  }
}
