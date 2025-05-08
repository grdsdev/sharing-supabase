import CryptoKit
import Dependencies
import Foundation
import Sharing
import Supabase

public protocol SupabaseKeyRequest<Value>: Hashable, Sendable {
  associatedtype Value

  var observeTables: [String] { get }

  func fetch(_ client: SupabaseClient) async throws -> Value
}

public struct FetchAll<Value: Decodable & Sendable>: SupabaseKeyRequest {
  public var observeTables: [String]
  public var filter: (@Sendable (PostgrestFilterBuilder) -> PostgrestBuilder)?

  public func hash(into hasher: inout Hasher) {
    hasher.combine(FetchKeyID(rawValue: self))
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    FetchKeyID(rawValue: lhs) == FetchKeyID(rawValue: rhs)
  }

  public init(
    _ table: String,
    filter: (@Sendable (PostgrestFilterBuilder) -> PostgrestBuilder)? = nil
  ) {
    self.observeTables = [table]
    self.filter = filter
  }

  public func fetch(_ client: SupabaseClient) async throws -> Value {
    if let filter {
      return try await filter(client.from(observeTables[0]).select()).execute().value
    }

    return try await client.from(observeTables[0]).select().execute().value
  }
}

public struct SupabaseFetchKey<Value: Sendable>: SharedReaderKey {
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

    for table in request.observeTables {
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
      await channel.subscribe()
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
  public static func supabase<Value: Sendable>(
    _ request: some SupabaseKeyRequest<Value>,
    client: SupabaseClient? = nil
  ) -> SupabaseFetchKey<Value> where Self == SupabaseFetchKey<Value> {
    SupabaseFetchKey(request: request, client: client)
  }

  public static func supabase<Record: Decodable & Sendable>(
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
