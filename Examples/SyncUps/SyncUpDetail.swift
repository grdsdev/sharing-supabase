import SharingSupabase
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpDetailModel: HashableObject {
  var destination: Destination?
  var isDismissed = false
  @ObservationIgnored @SharedReader var details: Details.Value

  var onMeetingStarted: (SyncUp, [Attendee]) -> Void = unimplemented("onMeetingStarted")

  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.defaultSupabaseClient) var supabase
  @ObservationIgnored @Dependency(\.openSettings) var openSettings
  @ObservationIgnored @Dependency(\.speechClient.authorizationStatus) var authorizationStatus
  @ObservationIgnored @Dependency(\.uuid) var uuid

  @CasePathable
  enum Destination {
    case alert(AlertState<AlertAction>)
    case edit(SyncUpFormModel)
  }
  enum AlertAction {
    case confirmDeletion
    case continueWithoutRecording
    case openSettings
  }

  init(
    destination: Destination? = nil,
    syncUp: SyncUp
  ) {
    self.destination = destination
    _details = SharedReader(
      wrappedValue: Details.Value(syncUp: syncUp),
      .supabase(Details(syncUp: syncUp))
    )
  }

  func deleteMeetings(atOffsets indices: IndexSet) async {
    _ = await withErrorReporting {
      try await supabase.from(Meeting.tableName)
        .delete()
        .in("id", values: indices.compactMap { details.meetings[$0].id })
        .execute()
    }
  }

  func deleteButtonTapped() {
    destination = .alert(.deleteSyncUp)
  }

  func alertButtonTapped(_ action: AlertAction?) async {
    switch action {
    case .confirmDeletion:
      isDismissed = true
      try? await clock.sleep(for: .seconds(0.4))
      _ = await withErrorReporting {
        try await supabase.from(SyncUp.tableName).delete()
          .eq("id", value: details.syncUp.id)
          .execute()
      }

    case .continueWithoutRecording:
      onMeetingStarted(details.syncUp, details.attendees)

    case .openSettings:
      await openSettings()

    case nil:
      break
    }
  }

  func editButtonTapped() {
    destination = .edit(
      withDependencies(from: self) {
        SyncUpFormModel(syncUp: details.syncUp, attendees: details.attendees)
      }
    )
  }

  func startMeetingButtonTapped() {
    switch authorizationStatus() {
    case .notDetermined, .authorized:
      onMeetingStarted(details.syncUp, details.attendees)

    case .denied:
      destination = .alert(.speechRecognitionDenied)

    case .restricted:
      destination = .alert(.speechRecognitionRestricted)

    @unknown default:
      break
    }
  }

  struct Details: SupabaseKeyRequest {
    struct Value {
      var attendees: [Attendee] = []
      var meetings: [Meeting] = []
      var syncUp: SyncUp
    }

    let syncUp: SyncUp

    var observeTables: [String] {
      [
        Attendee.tableName, Meeting.tableName, SyncUp.tableName,
      ]
    }

    func fetch(_ client: SupabaseClient) async throws -> Value {
      async let attendees =
        client.from(Attendee.tableName)
        .select()
        .eq("syncup_id", value: syncUp.id)
        .execute().value as [Attendee]

      async let meetings =
        client.from(Meeting.tableName)
        .select()
        .eq("syncup_id", value: syncUp.id)
        .order("date", ascending: false)
        .execute().value as [Meeting]

      async let syncUp =
        client.from(SyncUp.tableName)
        .select()
        .eq("id", value: syncUp.id)
        .single()
        .execute()
        .value as SyncUp

      return try await Value(
        attendees: attendees,
        meetings: meetings,
        syncUp: syncUp
      )
    }
  }
}

struct SyncUpDetailView: View {
  @Environment(\.dismiss) var dismiss
  @State var model: SyncUpDetailModel

  var body: some View {
    List {
      Section {
        Button {
          model.startMeetingButtonTapped()
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        HStack {
          Label("Length", systemImage: "clock")
          Spacer()
          Text(model.details.syncUp.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(model.details.syncUp.theme.name)
            .padding(4)
            .foregroundColor(model.details.syncUp.theme.accentColor)
            .background(model.details.syncUp.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Sync-up Info")
      }

      if !model.details.meetings.isEmpty {
        Section {
          ForEach(model.details.meetings, id: \.id) { meeting in
            NavigationLink(
              value: AppModel.Path.meeting(meeting, attendees: model.details.attendees)
            ) {
              HStack {
                Image(systemName: "calendar")
                Text(meeting.date, style: .date)
                Text(meeting.date, style: .time)
              }
            }
          }
          .onDelete { indices in
            Task {
              await model.deleteMeetings(atOffsets: indices)
            }
          }
        } header: {
          Text("Past meetings")
        }
      }

      Section {
        ForEach(model.details.attendees, id: \.id) { attendee in
          Label(attendee.name, systemImage: "person")
        }
      } header: {
        Text("Attendees")
      }

      Section {
        Button("Delete") {
          model.deleteButtonTapped()
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(model.details.syncUp.title)
    .toolbar {
      Button("Edit") {
        model.editButtonTapped()
      }
    }
    .alert($model.destination.alert) { action in
      await model.alertButtonTapped(action)
    }
    .sheet(item: $model.destination.edit) { editModel in
      NavigationStack {
        SyncUpFormView(model: editModel)
          .navigationTitle(model.details.syncUp.title)
      }
    }
    .onChange(of: model.isDismissed) {
      dismiss()
    }
  }
}

extension AlertState where Action == SyncUpDetailModel.AlertAction {
  static let deleteSyncUp = Self {
    TextState("Delete?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmDeletion) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("Nevermind")
    }
  } message: {
    TextState("Are you sure you want to delete this sync-up?")
  }

  static let speechRecognitionDenied = Self {
    TextState("Speech recognition denied")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(action: .openSettings) {
      TextState("Open settings")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState(
      """
      You previously denied speech recognition and so your meeting meeting will not be \
      recorded. You can enable speech recognition in settings, or you can continue without \
      recording.
      """
    )
  }

  static let speechRecognitionRestricted = Self {
    TextState("Speech recognition restricted")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState(
      """
      Your device does not support speech recognition and so your meeting will not be recorded.
      """
    )
  }
}

struct MeetingView: View {
  let meeting: Meeting
  let attendees: [Attendee]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Divider()
          .padding(.bottom)
        Text("Attendees")
          .font(.headline)
        ForEach(attendees, id: \.id) { attendee in
          Text(attendee.name)
        }
        Text("Transcript")
          .font(.headline)
          .padding(.top)
        Text(meeting.transcript)
      }
    }
    .navigationTitle(Text(meeting.date, style: .date))
    .padding()
  }
}

//#Preview {
//  let _ = prepareDependencies {
//    $0.defaultDatabase = .appDatabase
//  }
//  @Dependency(\.defaultDatabase) var database
//  let syncUp = try! database.read { db in
//    try SyncUp.fetchOne(db)!
//  }
//  NavigationStack {
//    SyncUpDetailView(
//      model: SyncUpDetailModel(
//        syncUp: syncUp
//      )
//    )
//  }
//}
