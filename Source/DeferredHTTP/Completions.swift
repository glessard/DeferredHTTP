//
//  Completions.swift
//
//  Created by Guillaume Lessard on 6/4/20.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import struct deferred.Resolver

typealias DataCompletion = (Data?, URLResponse?, Error?) -> Void

internal func dataCompletion(_ resolver: Resolver<(Data, HTTPURLResponse), URLError>) -> DataCompletion
{
  return {
    (data: Data?, response: URLResponse?, error: Error?) in

    if error != nil
    { // note that response isn't necessarily `nil` here,
      // but does it ever contain any data that's not in the Error?
      let error = (error as? URLError) ?? URLError(.unknown)
      resolver.resolve(error: error)
      return
    }

    if let r = response as? HTTPURLResponse
    {
      if let d = data
      { resolver.resolve(value: (d,r)) }
      else
      { resolver.resolve(error: URLError(.unknown, userInfo: ["unknown": "invalid state at line \(#line)"])) }
    }
    else // Probably an impossible situation
    { resolver.resolve(error: URLError(.unknown, userInfo: ["unknown": "invalid state at line \(#line)"])) }
  }
}

typealias DownloadCompletion = (URL?, URLResponse?, Error?) -> Void

internal func downloadCompletion(_ resolver: Resolver<(FileHandle, HTTPURLResponse), URLError>) -> DownloadCompletion
{
  return {
    (location: URL?, response: URLResponse?, error: Error?) in

    if error != nil
    { // note that response isn't necessarily `nil` here,
      // but does it ever contain any data that's not in the Error?
      let error = (error as? URLError) ?? URLError(.unknown)
      resolver.resolve(error: error)
      return
    }

#if os(Linux) && false
    print(location ?? "no file location given")
    print(response.map(String.init(describing:)) ?? "no response")
#endif

    if let response = response as? HTTPURLResponse
    {
      if let url = location
      {
        do {
          let handle = try FileHandle(forReadingFrom: url)
          resolver.resolve(value: (handle, response))
        }
        catch {
          let urlError = URLError(.cannotOpenFile, userInfo: [NSUnderlyingErrorKey: error])
          resolver.resolve(error: urlError)
        }
      }
      else // should not happen
      { resolver.resolve(error: URLError(.unknown, userInfo: ["unknown": "invalid state at line \(#line)"])) }
    }
    else // can happen if resume data is corrupted; otherwise probably an impossible situation
    { resolver.resolve(error: URLError(.unknown, userInfo: ["unknown": "invalid state at line \(#line)"])) }
  }
}
