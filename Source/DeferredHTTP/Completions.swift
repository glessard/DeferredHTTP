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

    if let error = error
    { // note that response isn't necessarily `nil` here,
      // but does it ever contain any data that's not in the Error?
      let error = (error as? URLError) ?? URLError(.unknown, failingURL: response?.url, (NSUnderlyingErrorKey, error))
      resolver.resolve(error: error)
      return
    }

    if let r = response as? HTTPURLResponse
    { resolver.resolve(value: (data ?? Data(), r)) }
    else // Probably an impossible situation
    { resolver.resolve(error: URLError(.unknown, failingURL: response?.url, ("PartialData", data))) }
  }
}

typealias DownloadCompletion = (URL?, URLResponse?, Error?) -> Void

internal func downloadCompletion(_ resolver: Resolver<(FileHandle, HTTPURLResponse), URLError>) -> DownloadCompletion
{
  return {
    (location: URL?, response: URLResponse?, error: Error?) in

    if let error = error
    { // note that response isn't necessarily `nil` here,
      // but does it ever contain any data that's not in the Error?
      let error = (error as? URLError) ?? URLError(.unknown, failingURL: response?.url, (NSUnderlyingErrorKey, error))
      resolver.resolve(error: error)
      return
    }

#if os(Linux) && false
    print(location ?? "no file location given")
    print(response.map(String.init(describing:)) ?? "no response")
#endif

    if let response = response as? HTTPURLResponse
    { // send an open `FileHandle` or the `nullDevice` if there is an error
      let handle = location.flatMap({ try? FileHandle(forReadingFrom: $0) }) ?? .nullDevice
      resolver.resolve(value: (handle, response))
    }
    else // can happen if resume data is corrupted; otherwise probably an impossible situation
    { resolver.resolve(error: URLError(.unknown, failingURL: response?.url, ("FileURL", location))) }
  }
}
