import XCTest

import DeferredHTTPTests

var tests = [XCTestCaseEntry]()
tests += DeferredHTTPTests.__allTests()

XCTMain(tests)
