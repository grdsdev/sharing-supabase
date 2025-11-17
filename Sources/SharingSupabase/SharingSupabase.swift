import CryptoKit
import Dependencies
import Foundation
import Sharing
import Supabase

public struct FetchAll<Value: Decodable>: SupabaseKeyRequest {
  public var configuration: SupabaseKeyRequestConfiguration {
    SupabaseKeyRequestConfiguration(observeTables: [table])
  }
  public let table: String
  public var filter: (@Sendable (PostgrestFilterBuilder) -> PostgrestBuilder)?

  public func hash(into hasher: inout Hasher) {
    hasher.combine(configuration)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.configuration == rhs.configuration
  }

  public init(
    _ table: String,
    filter: (@Sendable (PostgrestFilterBuilder) -> PostgrestBuilder)? = nil
  ) {
    self.table = table
    self.filter = filter
  }

  public func fetch(_ client: SupabaseClient) async throws -> Value {
    if let filter {
      return try await filter(client.from(table).select()).execute().value
    }

    return try await client.from(table).select().execute().value
  }
}

public struct SupabaseFetchKey<Value>: SharedReaderKey {
  public typealias ID = FetchKeyID

  public var id: ID {
    FetchKeyID(rawValue: request)
  }

  let client: SupabaseClient
  let request: any SupabaseKeyRequest<Value>

  private var topic: String {
    let id = "\(id.hashValue)"
    let hash = Insecure.MD5.hash(data: Data(id.utf8)).map { String(format: "%02hhx", $0) }.joined()
    return "sharing:supabase:\(hash)"
  }

  public init(
    request: some SupabaseKeyRequest<Value>,
    client: SupabaseClient? = nil
  ) {
    @Dependency(\.defaultSupabaseClient) var defaultClient
    self.request = request
    self.client = client ?? defaultClient
  }

  public func load(
    context: Sharing.LoadContext<Value>,
    continuation: Sharing.LoadContinuation<Value>
  ) {
    guard case .userInitiated = context else {
      continuation.resumeReturningInitialValue()
      return
    }

    Task {
      do {
        let response = try await request.fetch(client)
        continuation.resume(returning: response)
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  public func subscribe(
    context: Sharing.LoadContext<Value>,
    subscriber: Sharing.SharedSubscriber<Value>
  ) -> Sharing.SharedSubscription {
    var tasks: [Task<Void, Never>] = []

    let channel = client.channel(topic)

    for table in request.configuration.observeTables {
      let stream = channel.postgresChange(AnyAction.self, table: table)

      tasks.append(
        Task {
          for await _ in stream {
            if Task.isCancelled {
              break
            }

            do {
              let response = try await request.fetch(client)
              subscriber.yield(response)
            } catch {
              subscriber.yield(throwing: error)
            }
          }
        }
      )
    }

    Task {
      try? await channel.subscribeWithError()
    }

    return SharedSubscription { [tasks] in
      for task in tasks {
        task.cancel()
      }

      Task {
        await channel.unsubscribe()
      }
    }
  }

}

extension SharedReaderKey {

  /// Creates a new `SupabaseFetchKey` with the provided table and query.
  /// - Parameters:
  ///   - table: The table to fetch data from.
  ///   - query: A closure that takes a `PostgrestQueryBuilder` and returns a `PostgrestFilterBuilder`.
  ///   - client: The Supabase client to use. If `nil`, the default client will be used.
  ///
  /// - Returns: A new `SupabaseFetchKey`.
  public static func supabase<Value>(
    _ request: some SupabaseKeyRequest<Value>,
    client: SupabaseClient? = nil
  ) -> SupabaseFetchKey<Value> where Self == SupabaseFetchKey<Value> {
    SupabaseFetchKey(request: request, client: client)
  }

  public static func supabase<Record: Decodable>(
    _ table: String,
    filter: (@Sendable (PostgrestFilterBuilder) -> PostgrestBuilder)? = nil,
    client: SupabaseClient? = nil
  ) -> Self where Self == SupabaseFetchKey<[Record]> {
    .supabase(FetchAll(table, filter: filter), client: client)
  }
}

public struct FetchKeyID: Hashable {
  fileprivate let rawValue: AnyHashableSendable
  fileprivate let typeID: ObjectIdentifier

  fileprivate init(rawValue: some SupabaseKeyRequest) {
    self.rawValue = AnyHashableSendable(rawValue)
    self.typeID = ObjectIdentifier(type(of: rawValue))
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue)
    hasher.combine(typeID)
  }
}
