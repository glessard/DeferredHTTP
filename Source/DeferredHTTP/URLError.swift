//
//  URLError.swift
//

import Foundation

extension URLError
{
  init(_ code: URLError.Code, failingURL url: URL? = nil, description: String? = nil, function: String = #function)
  {
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
