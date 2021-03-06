#if !canImport(ObjectiveC)
import XCTest

extension URLSessionResumeTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__URLSessionResumeTests = [
        ("testResumeAfterCancellation", testResumeAfterCancellation),
        ("testResumeWithEmptyData", testResumeWithEmptyData),
        ("testResumeWithMangledData", testResumeWithMangledData),
        ("testResumeWithNonsenseData", testResumeWithNonsenseData),
        ("testURLRequestTimeout1", testURLRequestTimeout1),
        ("testURLRequestTimeout2", testURLRequestTimeout2),
    ]
}

extension URLSessionTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__URLSessionTests = [
        ("testData_CancelDeferred", testData_CancelDeferred),
        ("testData_CancelTask", testData_CancelTask),
        ("testData_Incomplete", testData_Incomplete),
        ("testData_NotFound", testData_NotFound),
        ("testData_OK", testData_OK),
        ("testData_Partial", testData_Partial),
        ("testData_Post", testData_Post),
        ("testData_SuspendCancel", testData_SuspendCancel),
        ("testDownload_CancelDeferred", testDownload_CancelDeferred),
        ("testDownload_CancelTask", testDownload_CancelTask),
        ("testDownload_NotFound", testDownload_NotFound),
        ("testDownload_OK", testDownload_OK),
        ("testDownload_SuspendCancel", testDownload_SuspendCancel),
        ("testInvalidDataTaskURL1", testInvalidDataTaskURL1),
        ("testInvalidDataTaskURL2", testInvalidDataTaskURL2),
        ("testInvalidDownloadTaskURL", testInvalidDownloadTaskURL),
        ("testInvalidUploadTaskURL1", testInvalidUploadTaskURL1),
        ("testInvalidUploadTaskURL2", testInvalidUploadTaskURL2),
        ("testUploadData_CancelTask", testUploadData_CancelTask),
        ("testUploadData_OK", testUploadData_OK),
        ("testUploadFile_OK", testUploadFile_OK),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(URLSessionResumeTests.__allTests__URLSessionResumeTests),
        testCase(URLSessionTests.__allTests__URLSessionTests),
    ]
}
#endif
