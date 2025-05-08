//
//  Scheduler.swift
//  SharingSupabase
//
//  Created by Guilherme Souza on 19/02/25.
//

import Foundation

public protocol Scheduler: Sendable {
  func schedule(action: @escaping @Sendable () -> Void)
}

public struct AsyncScheduler: Scheduler {
  let queue: DispatchQueue

  public func schedule(action: @escaping @Sendable () -> Void) {
    queue.async(execute: action)
  }
}

extension Scheduler where Self == AsyncScheduler {
  public static func async(on queue: DispatchQueue) -> Self {
    Self(queue: queue)
  }
}
