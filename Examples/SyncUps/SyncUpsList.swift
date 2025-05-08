import SharingSupabase
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpsListModel {
  var addSyncUp: SyncUpFormModel?
  @ObservationIgnored @SharedReader var syncUps: [SyncUps.Record]
  @ObservationIgnored @Dependency(\.uuid) var uuid
  @ObservationIgnored @Dependency(\.defaultSupabaseClient) var supabase

  init(
    addSyncUp: SyncUpFormModel? = nil
  ) {
    self.addSyncUp = addSyncUp
    _syncUps = SharedReader(wrappedValue: [], .supabase(SyncUps()))
  }

  func addSyncUpButtonTapped() {
    addSyncUp = withDependencies(from: self) {
      SyncUpFormModel(syncUp: SyncUp(id: uuid()))
    }
  }

  struct SyncUps: SupabaseKeyRequest {
    struct Record {
      let syncUp: SyncUp
      let attendeeCount: Int
    }
    var observeTables: [String] {
      [
        SyncUp.tableName,
        Attendee.tableName,
      ]
    }

    func fetch(_ client: SupabaseClient) async throws -> [Record] {
      struct Payload: Decodable {
        let id: UUID
        let seconds: Int
        let theme: Theme
        let title: String
        let attendees: [Count]

        struct Count: Decodable {
          let count: Int
        }
      }
      let payloads: [Payload] =
        try await client
        .from(SyncUp.tableName)
        .select("*,attendees(count)")
        .execute()
        .value

      return payloads.map { payload in
        let syncUp = SyncUp(
          id: payload.id,
          seconds: payload.seconds,
          theme: payload.theme,
          title: payload.title
        )

        return Record(syncUp: syncUp, attendeeCount: payload.attendees[0].count)
      }
    }
  }
}

struct SyncUpsList: View {
  @State var model = SyncUpsListModel()

  var body: some View {
    List {
      ForEach(model.syncUps, id: \.syncUp.id) { state in
        NavigationLink(value: AppModel.Path.detail(SyncUpDetailModel(syncUp: state.syncUp))) {
          CardView(syncUp: state.syncUp, attendeeCount: state.attendeeCount)
        }
        .listRowBackground(state.syncUp.theme.mainColor)
      }
    }
    .toolbar {
      Button {
        model.addSyncUpButtonTapped()
      } label: {
        Image(systemName: "plus")
      }
    }
    .navigationTitle("Daily Sync-ups")
    .sheet(item: $model.addSyncUp) { syncUpFormModel in
      NavigationStack {
        SyncUpFormView(model: syncUpFormModel)
          .navigationTitle("New sync-up")
      }
    }
  }
}

struct CardView: View {
  let syncUp: SyncUp
  let attendeeCount: Int

  var body: some View {
    VStack(alignment: .leading) {
      Text(syncUp.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(attendeeCount)", systemImage: "person.3")
        Spacer()
        Label(syncUp.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(syncUp.theme.accentColor)
  }
}

struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: LabelStyleConfiguration) -> some View {
    HStack {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: Self { Self() }
}
//
//#Preview {
//  let _ = prepareDependencies { $0.defaultDatabase = .appDatabase }
//  NavigationStack {
//    SyncUpsList(model: SyncUpsListModel())
//  }
//}
