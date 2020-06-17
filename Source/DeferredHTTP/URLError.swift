//
//  URLError.swift
//

import Foundation

#if canImport(FoundationNetworking)
import let FoundationNetworking.URLSessionDownloadTaskResumeData
#endif

extension URLError
{
  init(_ code: URLError.Code, failingURL url: URL? = nil, reason: String = "", function: String = #function)
  {
    let description: String? = reason.isEmpty ? "" : reason
    self = URLError(code, failingURL: url, (NSLocalizedDescriptionKey, description))
  }

  init<T>(_ code: URLError.Code, failingURL url: URL? = nil, _ pair: (String, T?), function: String = #function)
  {
    var info = ["Origin": function as Any]
    info[pair.0] = pair.1
    if let url = url
    {
      info[NSURLErrorFailingURLErrorKey] = url
      info[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
    }
    self = URLError(code, userInfo: info)
  }
}

extension URLError
{
  public func getPartialDownloadResumeData() -> Data?
  {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    // rdar://29623544 and https://bugs.swift.org/browse/SR-3403
    let URLSessionDownloadTaskResumeData = NSURLSessionDownloadTaskResumeData
#endif
    return userInfo[URLSessionDownloadTaskResumeData] as? Data
  }
}

import enum deferred.Cancellation

extension URLError.Code
{
  init(_ c: Cancellation)
  {
    switch c
    {
    case .canceled: self = .cancelled
    case .timedOut: self = .timedOut
    }
  }
}
