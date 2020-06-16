//
//  URLError.swift
//

import Foundation

extension URLError
{
  init(_ code: URLError.Code, failingURL url: URL? = nil, reason: String = "", function: String = #function)
  {
    let description: String? = reason.isEmpty ? "" : reason
    self = URLError(code, failingURL: url, (NSLocalizedDescriptionKey, description))
  }

  init<T>(_ code: URLError.Code, failingURL url: URL? = nil, _ pair: (String, T?), function: String = #function)
  {
    var info = [String: Any]()
    info[pair.0] = pair.1
    info["ErrorOrigin"] = function
    info[NSURLErrorFailingURLErrorKey] = url
    info[NSURLErrorFailingURLStringErrorKey] = url?.absoluteString
    self = URLError(code, userInfo: info)
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
