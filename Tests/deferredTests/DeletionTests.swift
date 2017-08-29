//
//  DeletionTests.swift
//  deferred
//
//  Created by Guillaume Lessard on 31/01/2017.
//  Copyright © 2017 Guillaume Lessard. All rights reserved.
//

import XCTest
import Foundation
import Dispatch

@testable import deferred

class DeletionTests: XCTestCase
{
  static var allTests = [
    ("testDeallocDeferred1", testDeallocDeferred1),
    ("testDeallocDeferred2", testDeallocDeferred2),
    ("testDeallocDeferred3", testDeallocDeferred3),
    ("testDeallocDeferred4", testDeallocDeferred4),
    ("testDelayedDeallocDeferred", testDelayedDeallocDeferred),
    ("testDeallocTBD1", testDeallocTBD1),
    ("testDeallocTBD2", testDeallocTBD2),
    ("testDeallocTBD3", testDeallocTBD3),
  ]

  class Dealloc: Deferred<Void>
  {
    let e: XCTestExpectation
    init(expectation: XCTestExpectation)
    {
      e = expectation
      super.init(queue: DispatchQueue.global())
    }
    deinit
    {
      e.fulfill()
    }
  }

  func testDeallocDeferred1()
  {
    do {
      _ = Dealloc(expectation: expectation(description: "will dealloc deferred 1"))
    }

    waitForExpectations(timeout: 0.1)
  }

  func testDeallocDeferred2()
  {
    do {
      let deferred = Dealloc(expectation: expectation(description: "will dealloc deferred 2"))
      do { _ = deferred.map { _ in XCTFail("Unexpected notification") } }
      deferred.cancel()
    }

    waitForExpectations(timeout: 0.1)
  }

  func testDeallocDeferred3()
  {
    do {
      Dealloc(expectation: expectation(description: "will dealloc deferred 3")).cancel()
    }

    waitForExpectations(timeout: 0.1)
  }

  func testDeallocDeferred4()
  {
    let mapped: Deferred<Void> = {
      let deferred = Dealloc(expectation: expectation(description: "will dealloc deferred 4"))
      return deferred.map { _ in XCTFail("Unexpected notification") }
    }()
    mapped.cancel()

    waitForExpectations(timeout: 0.1)
  }

  func testDelayedDeallocDeferred()
  {
    let witness: Deferred<Void>
    let e = expectation(description: "deallocation delay")
    do {
      let queue = DispatchQueue(label: "\(#function)")
      let delayed = Deferred(queue: queue, value: ()).delay(.milliseconds(50))
      _ = delayed.map { XCTFail("a value no one waits for should not be computed") }
      witness = delayed.map { e.fulfill() }
    }

    waitForExpectations(timeout: 0.5)
    _ = witness.value
  }

  class DeallocTBD: TBD<Void>
  {
    let e: XCTestExpectation
    init(expectation: XCTestExpectation)
    {
      e = expectation
      super.init(queue: DispatchQueue.global())
    }
    deinit
    {
      e.fulfill()
    }
  }

  func testDeallocTBD1()
  {
    do {
      _ = DeallocTBD(expectation: expectation(description: "will dealloc tbd 1"))
    }

    waitForExpectations(timeout: 0.1)
  }

  func testDeallocTBD2()
  {
    do {
      let tbd = DeallocTBD(expectation: expectation(description: "will dealloc tbd 2"))
      do { _ = tbd.map { _ in XCTFail("Unexpected notification") } }
      tbd.cancel()
    }

    waitForExpectations(timeout: 0.1)
  }

  func testDeallocTBD3()
  {
    do {
      DeallocTBD(expectation: expectation(description: "will dealloc tbd 3")).cancel()
    }

    waitForExpectations(timeout: 0.1)
  }
}
