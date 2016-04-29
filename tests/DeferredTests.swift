//
//  DeferredTests.swift
//  async-deferred-tests
//
//  Created by Guillaume Lessard on 2015-07-10.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import XCTest

import deferred


class DeferredTests: XCTestCase
{
  func testExample()
  {
    syncprint("Starting")

    let result1 = Deferred(qos: QOS_CLASS_BACKGROUND) {
      _ -> Double in
      defer { syncprint("Computing result1") }
      return 10.5
    }.delay(ms: 50)

    let result2 = result1.map {
      (d: Double) -> Int in
      syncprint("Computing result2")
      return Int(floor(2*d))
    }.delay(ms: 500)

    let result3 = result1.map {
      (d: Double) -> String in
      syncprint("Computing result3")
      return (3*d).description
    }

    result3.notify { syncprint($0) }

    let result4 = combine(result2, result1.map { Int($0*4) })

    let result5 = result2.timeout(ms: 50)

    syncprint("Waiting")
    syncprint("Result 1: \(result1.result)")
    syncprint("Result 2: \(result2.result)")
    syncprint("Result 3: \(result3.result)")
    syncprint("Result 4: \(result4.result)")
    syncprint("Result 5: \(result5.result)")
    syncprint("Done")
    syncprintwait()
  }

  func testExample2()
  {
    let d = Deferred {
      _ -> Double in
      usleep(50000)
      return 1.0
    }
    print(d.value)
  }

  func testExample3()
  {
    let transform = Deferred { i throws in Double(7*i) }         // Deferred<Int throws -> Double>
    let operand = Deferred(value: 6)                             // Deferred<Int>
    let result = operand.apply(transform: transform).map { $0.description } // Deferred<String>
    print(result.value)                                          // 42.0
  }

  func testDelay()
  {
    let interval = 0.1
    let d1 = Deferred(value: NSDate())
    let d2 = d1.delay(seconds: interval).map { NSDate().timeIntervalSinceDate($0) }

    XCTAssert(d2.value >= interval)
    XCTAssert(d2.value < 2.0*interval)

    // a negative delay returns the same reference
    let d3 = d1.delay(ms: -1)
    XCTAssert(d3 === d1)

    let d4 = d1.delay(µs: -1).map { $0 }
    XCTAssert(d4.value == d3.value)

    // a longer calculation is not delayed (significantly)
    let d5 = Deferred {
      _ -> NSDate in
      NSThread.sleepForTimeInterval(interval)
      return NSDate()
    }
    let d6 = d5.delay(seconds: interval/10).map { NSDate().timeIntervalSinceDate($0) }
    let actualDelay = d6.delay(ns: 100).value
    XCTAssert(actualDelay < interval/10)
  }

  func testValue()
  {
    let value = 1
    let d = Deferred(value: value)
    XCTAssert(d.value == value)
    XCTAssert(d.isDetermined)
  }

  func testPeek()
  {
    let value = 1
    let d1 = Deferred(value: value)
    XCTAssert(d1.peek()! == Result.Value(value))

    let d2 = Deferred(value: value).delay(µs: 10_000)
    XCTAssert(d2.peek() == nil)
    XCTAssert(d2.isDetermined == false)

    _ = d2.value // Wait for delay

    XCTAssert(d2.peek() != nil)
    XCTAssert(d2.peek()! == Result.Value(value))
    XCTAssert(d2.isDetermined)
  }

  func testValueBlocks()
  {
    let waitns = 100_000_000

    let value = arc4random() & 0x3fff_ffff

    let s = dispatch_semaphore_create(0)
    let busy = Deferred { _ -> UInt32 in
      dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER)
      return value
    }

    let expectation = expectationWithDescription("Timing out on Deferred")
    let fulfillTime = dispatch_time(DISPATCH_TIME_NOW, numericCast(waitns))

    dispatch_async(dispatch_get_global_queue(qos_class_self(), 0)) {
      let v = busy.value
      XCTAssert(v == value)

      let now = dispatch_time(DISPATCH_TIME_NOW, 0)
      if now < fulfillTime { XCTFail("delayed.value unblocked too soon") }
    }

    dispatch_after(fulfillTime, dispatch_get_global_queue(qos_class_self(), 0)) {
      expectation.fulfill()
    }

    waitForExpectationsWithTimeout(1.0) { _ in dispatch_semaphore_signal(s) }
  }

  func testValueUnblocks()
  {
    let waitns = 100_000_000

    let value = arc4random() & 0x3fff_ffff

    let s = dispatch_semaphore_create(0)
    let busy = Deferred { _ -> UInt32 in
      dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER)
      return value
    }

    let expectation = expectationWithDescription("Unblocking a Deferred")
    let fulfillTime = dispatch_time(DISPATCH_TIME_NOW, numericCast(waitns))

    dispatch_async(dispatch_get_global_queue(qos_class_self(), 0)) {
      let v = busy.value
      XCTAssert(v == value)

      let now = dispatch_time(DISPATCH_TIME_NOW, 0)
      if now < fulfillTime { XCTFail("delayed.value unblocked too soon") }
      else                 { expectation.fulfill() }
    }

    dispatch_after(fulfillTime, dispatch_get_global_queue(qos_class_self(), 0)) {
      dispatch_semaphore_signal(s)
    }

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testNotify1()
  {
    let value = arc4random() & 0x3fff_ffff
    let e1 = expectationWithDescription("Pre-set Deferred")
    let d1 = Deferred(value: value)
    d1.notify {
      XCTAssert( $0 == Result.Value(value) )
      e1.fulfill()
    }
    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testNotify2()
  {
    let value = arc4random() & 0x3fff_ffff
    let e2 = expectationWithDescription("Properly Deferred")
    let d2 = Deferred(value: value).delay(ms: 100)
    let a2 = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, 0)
    let q2 = dispatch_queue_create("Test", a2)
    d2.notifying(on: q2).notify(qos: QOS_CLASS_UTILITY) {
      XCTAssert( $0 == Result.Value(value) )
      e2.fulfill()
    }
    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testNotify3()
  {
    let e3 = expectationWithDescription("Deferred forever")
    let d3 = Deferred { _ -> Int in
      let s3 = dispatch_semaphore_create(0)
      dispatch_semaphore_wait(s3, DISPATCH_TIME_FOREVER)
      return 42
    }
    d3.notify {
      result in
      guard case let .Error(e) = result,
            let deferredErr = e as? DeferredError,
            case .canceled = deferredErr
      else
      {
        XCTFail()
        return
      }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200_000_000), dispatch_get_global_queue(qos_class_self(), 0)) {
      e3.fulfill()
    }

    waitForExpectationsWithTimeout(1.0) { _ in d3.cancel() }
  }

  func testNotify4()
  {
    let d4 = Deferred(value: arc4random() & 0x3fff_ffff).delay(ms: 50)
    let e4val = expectationWithDescription("Test onValue()")
    d4.onValue { _ in e4val.fulfill() }
    d4.onError { _ in XCTFail() }

    let d5 = Deferred<Int>(error: NSError(domain: "", code: 0, userInfo: nil)).delay(ms: 50)
    let e5err = expectationWithDescription("Test onError()")
    d5.onValue { _ in XCTFail() }
    d5.onError { _ in e5err.fulfill() }

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testMap()
  {
    let value = arc4random() & 0x3fff_ffff
    let error = arc4random() & 0x3fff_ffff
    let goodOperand = Deferred(value: value)
    let badOperand  = Deferred<Double>(error: TestError(error))

    // good operand, good transform
    let d1 = goodOperand.map { Int($0)*2 }
    XCTAssert(d1.value == Int(value)*2)
    XCTAssert(d1.error == nil)

    // good operand, transform throws
    let d2 = goodOperand.map { throw TestError($0) }
    XCTAssert(d2.value == nil)
    XCTAssert(d2.error as? TestError == TestError(value))

    // bad operand, transform short-circuited
    let d3 = badOperand.map { _ in XCTFail() }
    XCTAssert(d3.value == nil)
    XCTAssert(d3.error as? TestError == TestError(error))
  }

  func testMap2()
  {
    let value = arc4random() & 0x3fff_ffff
    let error = arc4random() & 0x3fff_ffff
    let goodOperand = Deferred(value: value)
    let badOperand  = Deferred<Double>(error: TestError(error))

    // good operand, good transform
    let d1 = goodOperand.map { Result.Value(Int($0)*2) }
    XCTAssert(d1.value == Int(value)*2)
    XCTAssert(d1.error == nil)

    // good operand, transform errors
    let d2 = goodOperand.map { Result<Void>.Error(TestError($0)) }
    XCTAssert(d2.value == nil)
    XCTAssert(d2.error as? TestError == TestError(value))

    // bad operand, transform short-circuited
    let d3 = badOperand.map { _ in Result<Void> { XCTFail() } }
    XCTAssert(d3.value == nil)
    XCTAssert(d3.error as? TestError == TestError(error))
  }

  func testRecover()
  {
    let value = arc4random() & 0x3fff_ffff
    let error = arc4random() & 0x3fff_ffff
    let goodOperand = Deferred(value: value)
    let badOperand  = Deferred<Double>(error: TestError(error))

    // good operand, transform short-circuited
    let d1 = goodOperand.recover(qos: QOS_CLASS_DEFAULT) { e in XCTFail(); return Deferred(error: TestError(error)) }
    XCTAssert(d1.value == value)
    XCTAssert(d1.error == nil)

    // bad operand, transform throws
    let d2 = badOperand.recover { error in Deferred { throw TestError(value) } }
    XCTAssert(d2.value == nil)
    XCTAssert(d2.error as? TestError == TestError(value))

    // bad operand, transform executes
    let d3 = badOperand.recover { error in Deferred(value: Double(value)) }
    XCTAssert(d3.value == Double(value))
    XCTAssert(d3.error == nil)

    // test early return from notification block
    let reason = "reason"
    let d4 = goodOperand.delay(ms: 50)
    let r4 = d4.recover { e in Deferred(value: value) }
    XCTAssert(r4.cancel(reason))
    do {
      try r4.result.getValue()
      XCTFail()
    }
    catch DeferredError.canceled(let message) { XCTAssert(message == reason) }
    catch { XCTFail() }
  }

  func testFlatMap()
  {
    let value = arc4random() & 0x3fff_ffff
    let error = arc4random() & 0x3fff_ffff
    let goodOperand = Deferred(value: value)
    let badOperand  = Deferred<Double>(error: TestError(error))

    // good operand, good transform
    let d1 = goodOperand.flatMap { Deferred(value: Int($0)*2) }
    XCTAssert(d1.value == Int(value)*2)
    XCTAssert(d1.error == nil)

    // good operand, transform errors
    let d2 = goodOperand.flatMap { Deferred<Double>(error: TestError($0)) }
    XCTAssert(d2.value == nil)
    XCTAssert(d2.error as? TestError == TestError(value))

    // bad operand, transform short-circuited
    let d3 = badOperand.flatMap { _ in Deferred<Void> { XCTFail() } }
    XCTAssert(d3.value == nil)
    XCTAssert(d3.error as? TestError == TestError(error))
  }

  func testApply()
  {
    // a simple curried function.
    let curriedSum: (Int) -> (Int) -> Int = { a in { b in (a+b) } }

    let value1 = Int(arc4random() & 0x3fff_ffff)
    let value2 = Int(arc4random() & 0x3fff_ffff)
    let deferred = Deferred(value: value1).apply(transform: Deferred(value: curriedSum(value2)))
    XCTAssert(deferred.value == value1+value2)

    // a 2-tuple is the same as two parameters
    let transform = Deferred(value: powf)
    let v1 = Deferred(value: 3.0 as Float)
    let v2 = Deferred(value: 4.1 as Float)

    let args = combine(v1, v2)
    let result = args.apply(transform: transform)

    XCTAssert(result.value == pow(3.0, 4.1))
  }

  func testApply1()
  {
    let transform = TBD<(Int) -> Double>()
    let operand = TBD<Int>()
    let result = operand.apply(transform: transform)
    let expect = expectationWithDescription("Applying a deferred transform to a deferred operand")

    var v1 = 0
    var v2 = 0
    result.notify {
      result in
      print("\(v1), \(v2), \(result)")
      XCTAssert(result == Result.Value(Double(v1*v2)))
      expect.fulfill()
    }

    let g = TBD<Void>()

    g.delay(ms: 100).notify { _ in
      v1 = Int(arc4random() & 0x7fff + 10000)
      try! transform.determine { i in Double(v1*i) }
    }

    g.delay(ms: 200).notify { _ in
      v2 = Int(arc4random() & 0x7fff + 10000)
      try! operand.determine(v2)
    }

    XCTAssert(operand.peek() == nil)
    XCTAssert(operand.state == .waiting)
    XCTAssert(transform.peek() == nil)
    XCTAssert(transform.state == .waiting)

    try! g.determine()
    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testApply2()
  {
    let value = Int(arc4random() & 0x7fff + 10000)
    let error = arc4random() & 0x3fff_ffff

    // good operand, good transform
    let o1 = Deferred(value: value)
    let t1 = Deferred { i throws in Double(value*i) }
    let r1 = o1.apply(transform: t1)
    XCTAssert(r1.value == Double(value*value))
    XCTAssert(r1.error == nil)

    // bad operand, transform not applied
    let o2 = Deferred<Int> { throw TestError(error) }
    let t2 = Deferred { (i:Int) throws -> Float in XCTFail(); return Float(i) }
    let r2 = o2.apply(transform: t2)
    XCTAssert(r2.value == nil)
    XCTAssert(r2.error as? TestError == TestError(error))
  }

  func testApply3()
  {
    let value = Int(arc4random() & 0x7fff + 10000)
    let error = arc4random() & 0x3fff_ffff

    // good operand, good transform
    let o1 = Deferred(value: value)
    let t1 = Deferred { i in Result.Value(Double(value*i)) }
    let r1 = o1.apply(transform: t1)
    XCTAssert(r1.value == Double(value*value))
    XCTAssert(r1.error == nil)

    // bad operand, transform not applied
    let o2 = Deferred<Int> { throw TestError(error) }
    let t2 = Deferred { (i:Int) in Result<Float> { XCTFail(); return Float(i) } }
    let r2 = o2.apply(transform: t2)
    XCTAssert(r2.value == nil)
    XCTAssert(r2.error as? TestError == TestError(error))
  }

  func testQOS()
  {
    let qb = Deferred(qos: QOS_CLASS_UTILITY) { qos_class_self() }
    XCTAssert(qb.qos == qb.value)

    let e1 = expectationWithDescription("Waiting")
    Deferred(qos: QOS_CLASS_BACKGROUND, result: Result.Value(qos_class_self())).onValue {
      qosv in
      // Verify that the QOS has been adjusted
      XCTAssert(qosv != qos_class_self())
      XCTAssert(qos_class_self() == QOS_CLASS_BACKGROUND)
      e1.fulfill()
    }

    let q2 = qb.notifying(at: QOS_CLASS_BACKGROUND, serially: true).map(qos: QOS_CLASS_USER_INITIATED) {
      qosv -> qos_class_t in
      XCTAssert(qosv == QOS_CLASS_UTILITY)
      // Verify that the QOS has changed
      XCTAssert(qosv != qos_class_self())
      // This block is running at the requested QOS
      XCTAssert(qos_class_self() == QOS_CLASS_USER_INITIATED)
      return qos_class_self()
    }

    let e2 = expectationWithDescription("Waiting")
    q2.notifying(at: QOS_CLASS_USER_INTERACTIVE).onValue {
      qosv in
      // Last block was in fact executing at QOS_CLASS_USER_INITIATED
      XCTAssert(qosv == QOS_CLASS_USER_INITIATED)
      // Last block wasn't executing at the queue's QOS
      XCTAssert(qosv != QOS_CLASS_BACKGROUND)
      // This block is executing at the queue's QOS.
      XCTAssert(qos_class_self() == QOS_CLASS_USER_INTERACTIVE)
      e2.fulfill()
    }

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testCancel()
  {
    let d1 = Deferred(qos: QOS_CLASS_UTILITY) {
      () -> UInt32 in
      usleep(100_000)
      return arc4random() & 0x3fff_ffff
    }

    XCTAssert(d1.cancel() == true)
    XCTAssert(d1.value == nil)

    // Set before canceling -- cancellation failure
    let d2 = Deferred(value: arc4random() & 0x3fff_ffff)
    XCTAssert(d2.cancel("message") == false)
  }

  func testCancelAndNotify()
  {
    let tbd = TBD<Int>()

    let d1 = tbd.map { $0 * 2 }
    let e1 = expectationWithDescription("first deferred")
    d1.onValue { _ in XCTFail() }
    d1.notify  { r in XCTAssert(r == Result.Error(DeferredError.canceled(""))) }
    d1.onError {
      e in
      guard let _ = e as? DeferredError else { fatalError() }
      e1.fulfill()
    }

    let d2 = d1.map  { $0 + 100 }
    let e2 = expectationWithDescription("second deferred")
    d2.onValue { _ in XCTFail() }
    d2.notify  { r in XCTAssert(r == Result.Error(DeferredError.canceled(""))) }
    d2.onError { _ in e2.fulfill() }

    d1.cancel()

    waitForExpectationsWithTimeout(1.0) { _ in tbd.cancel() }
  }

  func testCancelMap()
  {
    let tbd = TBD<Int>()

    let e1 = expectationWithDescription("cancellation of Deferred.map(_: U throws -> T)")
    let d1 = tbd.map { u throws in XCTFail(String(u)) }
    d1.onError { e in e1.fulfill() }
    XCTAssert(d1.cancel() == true)

    let e2 = expectationWithDescription("cancellation of Deferred.map(_: U -> Result<T>)")
    let d2 = tbd.map { u in Result.Value(XCTFail(String(u))) }
    d2.onError { e in e2.fulfill() }
    XCTAssert(d2.cancel() == true)

    try! tbd.determine(numericCast(arc4random() & 0x3fff_ffff))

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testCancelDelay()
  {
    let tbd = TBD<Int>()

    let e1 = expectationWithDescription("cancellation of Deferred.delay")
    let d1 = tbd.delay(ms: 100)
    d1.onError { e in e1.fulfill() }
    XCTAssert(d1.cancel() == true)

    try! tbd.determine(numericCast(arc4random() & 0x3fff_ffff))

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testCancelBind()
  {
    let tbd = TBD<Int>()

    let e1 = expectationWithDescription("cancellation of Deferred.flatMap")
    let d1 = tbd.flatMap { Deferred(value: $0) }
    d1.onError { e in e1.fulfill() }
    XCTAssert(d1.cancel() == true)

    let e2 = expectationWithDescription("cancellation of Deferred.recover")
    let d2 = tbd.recover { i in Deferred(value: Int.max) }
    d2.onError { e in e2.fulfill() }
    XCTAssert(d2.cancel() == true)

    try! tbd.determine(numericCast(arc4random() & 0x3fff_ffff))

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testCancelApply()
  {
    let tbd = TBD<Int>()

    let e1 = expectationWithDescription("cancellation of Deferred.apply, part 1")
    let t1 = Deferred { (i: Int) throws in Double(i) }
    let d1 = tbd.apply(transform: t1)
    d1.onError { e in e1.fulfill() }
    XCTAssert(d1.cancel() == true)

    let e2 = expectationWithDescription("cancellation of Deferred.apply, part 2")
    let t2 = t1.delay(ms: 100)
    let d2 = Deferred(value: 1).apply(transform: t2)
    d2.onError { e in e2.fulfill() }
    usleep(1000)
    XCTAssert(d2.cancel() == true)

    let e3 = expectationWithDescription("cancellation of Deferred.apply, part 3")
    let t3 = Deferred { (i: Int) in Result.Value(Double(i)) }
    let d3 = tbd.apply(transform: t3)
    d3.onError { e in e3.fulfill() }
    XCTAssert(d3.cancel() == true)

    let e4 = expectationWithDescription("cancellation of Deferred.apply, part 2")
    let t4 = t3.delay(ms: 100)
    let d4 = Deferred(value: 1).apply(transform: t4)
    d4.onError { e in e4.fulfill() }
    usleep(1000)
    XCTAssert(d4.cancel() == true)

    try! tbd.determine(numericCast(arc4random() & 0x3fff_ffff))

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testTimeout()
  {
    let value = arc4random() & 0x3fff_ffff
    let d = Deferred(value: value)

    let d1 = d.timeout(µs: 5000)
    XCTAssert(d1.value == value)

    let d2 = d.delay(ms: 5000).timeout(ns: 2_000_000)
    let e2 = expectationWithDescription("Timeout test")
    d2.onValue { _ in XCTFail() }
    d2.onError { _ in e2.fulfill() }

    let d3 = d.delay(ms: 100).timeout(seconds: -1)
    let e3 = expectationWithDescription("Unreasonable timeout test")
    d3.onValue { _ in XCTFail() }
    d3.onError { _ in e3.fulfill() }

    let d4 = d.delay(ms: 50).timeout(ms: 100)
    let e4 = expectationWithDescription("Timeout test 4")
    d4.onValue { _ in e4.fulfill() }
    d4.onError { _ in XCTFail() }

    waitForExpectationsWithTimeout(1.0, handler: nil)
  }

  func testRace()
  {
    let count = 1000
    let queue = dispatch_get_global_queue(qos_class_self(), 0)

    let tbd = TBD<Void>(queue: queue)

    let lucky = Int(arc4random_uniform(UInt32(count/4))) + count/4
    let e = (0..<count).map { i in expectationWithDescription(i.description) }

    var first: Int32 = -1
    dispatch_async(queue) {
      for i in 0..<count
      {
        dispatch_async(queue) {
          tbd.notify {
            [expectation = e[i]] _ in
            expectation.fulfill()
            if OSAtomicCompareAndSwap32Barrier(-1, Int32(i), &first) { syncprint(first) }
          }
          if i == lucky { dispatch_async(queue) { try! tbd.determine() } }
        }
      }
    }

    waitForExpectationsWithTimeout(5.0, handler: nil)
    syncprintwait()
  }

  func testCombine2()
  {
    let v1 = Int(arc4random() & 0x3fff_ffff)
    let v2 = UInt64(arc4random())

    let d1 = Deferred(value: v1).delay(ms: 100)
    let d2 = Deferred(value: v2).delay(ms: 200)

    let c = combine(d1,d2).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
  }

  func testCombine3()
  {
    let v1 = Int(arc4random() & 0x3fff_ffff)
    let v2 = UInt64(arc4random())
    let v3 = arc4random().description

    let d1 = Deferred(value: v1).delay(ms: 100)
    let d2 = Deferred(value: v2).delay(ms: 200)
    let d3 = Deferred(value: v3)
    // let d4 = Deferred { v3 }                        // infers Deferred<()->String> rather than Deferred<String>
    // let d5 = Deferred { () -> String in v3 }        // infers Deferred<()->String> rather than Deferred<String>
    // let d6 = Deferred { _ in v3 }                   // infers Deferred<String> as expected
    // let d7 = Deferred { () throws -> String in v3 } // infers Deferred<String> as expected

    let c = combine(d1,d2,d3).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
    XCTAssert(c?.2 == v3)
  }

  func testCombine4()
  {
    let v1 = Int(arc4random() & 0x3fff_ffff)
    let v2 = UInt64(arc4random())
    let v3 = arc4random().description
    let v4 = sin(Double(v2))

    let d1 = Deferred(value: v1).delay(ms: 100)
    let d2 = Deferred(value: v2).delay(ms: 200)
    let d3 = Deferred(value: v3)
    let d4 = Deferred(value: v4).delay(µs: 999)

    let c = combine(d1,d2,d3,d4).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
    XCTAssert(c?.2 == v3)
    XCTAssert(c?.3 == v4)
  }

  func testCombineArray1()
  {
    let count = 10

    let inputs = (0..<count).map { i in Deferred(value: arc4random() & 0x3fff_ffff) }
    let combined = combine(AnySequence(inputs))
    if let values = combined.value
    {
      XCTAssert(values.count == count)
      for (a,b) in zip(inputs, values)
      {
        XCTAssert(a.value == b)
      }
    }
    XCTAssert(combined.error == nil)

    let combined1 = combine([Deferred<Int>]())
    XCTAssert(combined1.value?.count == 0)
  }

  func testCombineArray2()
  {
    let count = 10

    let d = Deferred.inParallel(count: count) {
      i -> Int in
      usleep(numericCast((i+1)*10_000))
      return i
    }

    // If any one is in error, the combined whole will be in error.
    // The first error encountered will be passed on.

    let cancel1 = Int(arc4random_uniform(numericCast(count)))
    let cancel2 = Int(arc4random_uniform(numericCast(count)))

    d[cancel1].cancel(String(cancel1))
    d[cancel2].cancel(String(cancel2))

    let c = combine(d)

    XCTAssert(c.value == nil)
    XCTAssert(c.error as? DeferredError == DeferredError.canceled(String(min(cancel1,cancel2))))
  }

  func testPropagationTime()
  {
    let iterations = 10_000

    let ref = NSDate.distantPast()
    var dt = Deferred(value: (0, ref, ref))
    for _ in 0...iterations
    {
      dt = dt.map {
        (i, tic, toc) in
        tic == ref ? (0, NSDate(), ref) : (i+1, tic, NSDate())
      }
    }

    if let (iterations, tic, toc) = dt.value
    {
      print("\(round(Double(toc.timeIntervalSinceDate(tic)*1e9)/Double(iterations))/1000) µs per message")
    }
  }

  func testNotificationTime()
  {
    let iterations = 100_000

    let attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0)
    let dt = Deferred(value: 1).notifying(on: dispatch_queue_create("", attr))
    let start = NSDate()
    for _ in 0..<iterations
    {
      dt.notify { _ in }
    }

    switch dt.map(transform: { _ in NSDate() }).result
    {
    case .Value(let end):
      print("\(round(Double(end.timeIntervalSinceDate(start)*1e9)/Double(iterations))/1000) µs per notification")

    default: XCTFail()
    }
  }
}
