//
//  SupabaseKeyRequest.swift
//  SharingSupabase
//
//  Created by Guilherme Souza on 12/05/25.
//

public struct SupabaseKeyRequestConfiguration {

  public var observeTables: [String]

  public init(observeTables: [String]) {
    self.observeTables = observeTables
  }
}

public protocol SupabaseKeyRequest<Value>: Hashable, Sendable {
  associatedtype Value

  var configuration: SupabaseKeyRequestConfiguration { get }

  func fetch(_ client: SupabaseClient) async throws -> Value
}
