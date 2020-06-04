//
//  nsurlsession.swift
//
//  Created by Guillaume Lessard on 10/02/2016.
//  Copyright © 2016-2020 Guillaume Lessard. All rights reserved.
//

import Dispatch
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import deferred
import CurrentQoS

extension URLSession
{
  public func deferredDataTask(queue: DispatchQueue,
                               with request: URLRequest) -> DeferredURLTask<Data>
  {
    return DeferredURLTask(request: request, queue: queue) {
      self.dataTask(with: request, completionHandler: dataCompletion($0))
    }
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with request: URLRequest) -> DeferredURLTask<Data>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDataTask(queue: queue, with: request)
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with url: URL) -> DeferredURLTask<Data>
  {
    return deferredDataTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLTask<Data>
  {
    return DeferredURLTask(request: request, queue: queue) {
      self.uploadTask(with: request, from: bodyData, completionHandler: dataCompletion($0))
    }
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLTask<Data>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredUploadTask(queue: queue, with: request, fromData: bodyData)
  }

  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLTask<Data>
  {
    return DeferredURLTask(request: request, queue: queue) {
      self.uploadTask(with: request, fromFile: fileURL, completionHandler: dataCompletion($0))
    }
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLTask<Data>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredUploadTask(queue: queue, with: request, fromFile: fileURL)
  }
}

extension URLSession
{
  public func deferredDownloadTask(queue: DispatchQueue,
                                   with request: URLRequest) -> DeferredURLTask<FileHandle>
  {
    return DeferredDownloadTask(request: request, queue: queue) {
      self.downloadTask(with: request, completionHandler: downloadCompletion($0))
    }
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with request: URLRequest) -> DeferredURLTask<FileHandle>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDownloadTask(queue: queue, with: request)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with url: URL) -> DeferredURLTask<FileHandle>
  {
    return deferredDownloadTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredDownloadTask(queue: DispatchQueue,
                                   withResumeData data: Data) -> DeferredURLTask<FileHandle>
  {
    let request = URLRequest(url: URL(string: "url-session-resume:")!)
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    return DeferredDownloadTask(request: request, queue: queue) {
      self.downloadTask(withResumeData: data, completionHandler: downloadCompletion($0))
    }
#else
    // swift-corelibs-foundation calls NSUnimplemented() as the body of downloadTask(withResumeData:)
    // It should instead call the completion handler with URLError.unsupportedURL
    // let task = downloadTask(withResumeData: data, completionHandler: downloadCompletion(tbd))
    let message = "The operation \'\(#function)\' is not supported on this platform"
    let error = URLError(.unsupportedURL, userInfo: [NSLocalizedDescriptionKey: message])
    return DeferredURLTask(queue: queue, error: error)
#endif
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   withResumeData data: Data) -> DeferredURLTask<FileHandle>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDownloadTask(queue: queue, withResumeData: data)
  }
}

extension DeferredURLTask
{
  @discardableResult
  public func timeout(seconds: Double) -> DeferredURLTask
  {
    return self.timeout(after: .now() + seconds)
  }

  @discardableResult
  public func timeout(after deadline: DispatchTime) -> DeferredURLTask
  {
    if self.isResolved { return self }

    if deadline < .now()
    {
      cancel()
    }
    else if deadline != .distantFuture
    {
      let queue = DispatchQueue(label: "timeout", qos: qos)
      queue.asyncAfter(deadline: deadline) { [weak self] in self?.cancel() }
    }
    return self
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
