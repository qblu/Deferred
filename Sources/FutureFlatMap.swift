//
//  FutureFlatMap.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/2/16.
//  Copyright © 2014-2016 Big Nerd Ranch. Licensed under MIT.
//

import Dispatch

extension FutureType {
    /// Begins another asynchronous operation with the deferred value once it
    /// becomes determined.
    ///
    /// `flatMap` is similar to `map`, but `transform` returns a `Deferred`
    /// instead of an immediate value. Use `flatMap` when you want this future
    /// to feed into another asynchronous operation. You might hear this
    /// referred to as "chaining" or "binding".
    ///
    /// - parameter queue: Optional dispatch queue for starting the new
    ///   operation from. Defaults to a global queue matching the current QoS.
    /// - parameter transform: Start a new operation using the deferred value.
    /// - returns: The new deferred value returned by the `transform`.
    /// - seealso: Deferred
    public func flatMap<NewFuture: FutureType>(upon queue: dispatch_queue_t = Self.genericQueue, _ transform: Value -> NewFuture) -> Future<NewFuture.Value> {
        let d = Deferred<NewFuture.Value>()
        upon(queue) {
            transform($0).upon(queue) {
                d.fill($0)
            }
        }
        return Future(d)
    }
}
