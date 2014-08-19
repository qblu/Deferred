//
//  Deferred.swift
//  AsyncNetworkServer
//
//  Created by John Gallagher on 7/19/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

// TODO: Replace this with a class var
private var DeferredDefaultQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

public class Deferred<T> {
    typealias UponBlock = (dispatch_queue_t, T -> ())
    typealias Protected = (value: T?, uponBlocks: [UponBlock])

    private var protected: LockProtected<Protected>

    // Initialize an unfilled Deferred
    public init() {
        protected = LockProtected(item: (nil, []))
    }

    // Initialize a filled Deferred with the given value
    public init(value: T) {
        protected = LockProtected(item: (value, []))
    }

    // Check whether or not the receiver is filled
    public var isFilled: Bool {
        return protected.withReadLock { $0.value != nil }
    }

    private func _fill(value: T, assertIfFilled: Bool) {
        let (filledValue, blocks) = protected.withWriteLock { data -> (T, [UponBlock]) in
            if assertIfFilled {
                assert(data.value == nil, "Cannot fill an already-filled Deferred")
                data.value = value
            } else if data.value == nil {
                data.value = value
            }
            let blocks = data.uponBlocks
            data.uponBlocks.removeAll(keepCapacity: false)
            return (data.value!, blocks)
        }
        for (queue, block) in blocks {
            dispatch_async(queue) { block(filledValue) }
        }
    }

    public func fill(value: T) {
        _fill(value, assertIfFilled: true)
    }

    public func fillIfUnfilled(value: T) {
        _fill(value, assertIfFilled: false)
    }

    public func peek() -> T? {
        return protected.withReadLock { $0.value }
    }

    public func uponQueue(queue: dispatch_queue_t, block: T -> ()) {
        let maybeValue: T? = protected.withWriteLock{ data in
            if data.value == nil {
                data.uponBlocks.append( (queue, block) )
            }
            return data.value
        }
        if let value = maybeValue {
            dispatch_async(queue) { block(value) }
        }
    }
}

extension Deferred {
    public var value: T {
        // fast path - return if already filled
        if let v = peek() {
            return v
        }

        // slow path - block until filled
        let group = dispatch_group_create()
        var result: T!
        dispatch_group_enter(group)
        self.upon { result = $0; dispatch_group_leave(group) }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        return result
    }
}

extension Deferred {
    public func bindQueue<U>(queue: dispatch_queue_t, f: T -> Deferred<U>) -> Deferred<U> {
        let d = Deferred<U>()
        self.uponQueue(queue) {
            f($0).uponQueue(queue) {
                d.fill($0)
            }
        }
        return d
    }

    public func mapQueue<U>(queue: dispatch_queue_t, f: T -> U) -> Deferred<U> {
        return bindQueue(queue) { t in Deferred<U>(value: f(t)) }
    }
}

extension Deferred {
    public func upon(block: T ->()) {
        uponQueue(DeferredDefaultQueue, block: block)
    }

    public func bind<U>(f: T -> Deferred<U>) -> Deferred<U> {
        return bindQueue(DeferredDefaultQueue, f: f)
    }

    public func map<U>(f: T -> U) -> Deferred<U> {
        return mapQueue(DeferredDefaultQueue, f: f)
    }
}

extension Deferred {
    public func both<U>(other: Deferred<U>) -> Deferred<(T,U)> {
        return self.bind { t in other.map { u in (t, u) } }
    }
}

public func all<T>(deferreds: [Deferred<T>]) -> Deferred<[T]> {
    if deferreds.count == 0 {
        return Deferred(value: [])
    }

    let combined = Deferred<[T]>()
    var results: [T] = []
    results.reserveCapacity(deferreds.count)

    var block: (T -> ())!
    block = { t in
        results.append(t)
        if results.count == deferreds.count {
            combined.fill(results)
        } else {
            deferreds[results.count].upon(block)
        }
    }
    deferreds[0].upon(block)

    return combined
}

public func any<T>(deferreds: [Deferred<T>]) -> Deferred<Deferred<T>> {
    let combined = Deferred<Deferred<T>>()
    for d in deferreds {
        d.upon { _ in combined.fillIfUnfilled(d) }
    }
    return combined
}