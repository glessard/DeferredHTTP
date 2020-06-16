//
//  DeferredURLTask.swift
//
//  Created by Guillaume Lessard on 6/4/20.
//  Copyright © 2016-2020 Guillaume Lessard. All rights reserved.
//

import Dispatch
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import deferred
import CurrentQoS

public class DeferredURLTask<Success>: Deferred<(Success, HTTPURLResponse), URLError>
{
  private weak var taskHolder: Deferred<URLSessionTask, Never>?

  public var urlSessionTask: URLSessionTask? {
    if case let .success(task)? = taskHolder?.peek()
    {
      return task
    }
    return nil
  }

  private let url: URL?

  init(request: URLRequest, queue: DispatchQueue,
       obtainTask: @escaping (Resolver<(Success, HTTPURLResponse), URLError>) -> URLSessionTask)
  {
    self.url = request.url
    if let error = validateURL(url)
    {
      super.init(queue: queue, result: .failure(error))
      return
    }

    let (taskResolver, taskHolder) = Deferred<URLSessionTask, Never>.CreatePair(queue: queue)
    self.taskHolder = taskHolder

    super.init(queue: queue) {
      resolver in
      let urlSessionTask = obtainTask(resolver)
      urlSessionTask.resume()
      taskResolver.resolve(value: urlSessionTask)
      resolver.retainSource(taskHolder)
    }
  }

  deinit {
    if let state = urlSessionTask?.state
    { // only signal the task if necessary
      if state == .running || state == .suspended { urlSessionTask?.cancel() }
    }
  }

  open override func convertCancellation<E: Error>(_ error: E) -> URLError?
  {
    if let urlError = error as? URLError
    {
      return urlError
    }

    guard let cancellation = error as? Cancellation else { return nil }

    return URLError(.init(cancellation), failingURL: url, reason: cancellation.description)
  }

  fileprivate func cancelURLSessionTask() -> Bool
  {
    if let task = urlSessionTask,
       task.state != .completed
    { // try to propagate the cancellation upstream
      task.cancel()
      return true
    }
    return false
  }

  open override func cancel<E: Error>(_ error: E)
  {
    if let error = convertCancellation(error),
       cancelURLSessionTask() == false
    {
      super.cancel(error)
    }
  }

  public func cancel(reason: String = "")
  {
    cancel(URLError(.cancelled, failingURL: url, reason: reason))
  }
}

private func validateURL(_ url: URL?) -> URLError?
{
  let scheme = url?.scheme ?? "invalid"
  if scheme == "http" || scheme == "https" || scheme == DeferredURLDownloadTask.resumeScheme
  {
    return nil
  }

#if !os(macOS) && !os(iOS) && !os(tvOS) && !os(watchOS)
  if scheme == DeferredURLDownloadTask.corelibsFoundationUnimplemented
  {
    let message = "Resumed downloads are not supported on this platform"
    return URLError(.unsupportedURL, userInfo: [NSLocalizedDescriptionKey: message])
  }
#endif

  let message = "DeferredURLTask does not support url scheme \"\(scheme)\""
  return URLError(.unsupportedURL, failingURL: url, reason: message)
}

public class DeferredURLDataTask: DeferredURLTask<Data>
{
  public init(with request: URLRequest, session: URLSession = .shared, queue: DispatchQueue)
  {
    super.init(request: request, queue: queue) {
      session.dataTask(with: request, completionHandler: dataCompletion($0))
    }
  }

  public convenience init(with request: URLRequest, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(with: request, session: session, queue: queue)
  }

  public convenience init(with url: URL, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    self.init(with: URLRequest(url: url), session: session, qos: qos)
  }
}

public class DeferredURLUploadTask: DeferredURLTask<Data>
{
  public init(with request: URLRequest, fromData data: Data, session: URLSession = .shared, queue: DispatchQueue)
  {
    super.init(request: request, queue: queue) {
      session.uploadTask(with: request, from: data, completionHandler: dataCompletion($0))
    }
  }

  public convenience init(with request: URLRequest, fromData data: Data, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(with: request, fromData: data, session: session, queue: queue)
  }

  public init(with request: URLRequest, fromFile file: URL, session: URLSession = .shared, queue: DispatchQueue)
  {
    super.init(request: request, queue: queue) {
      session.uploadTask(with: request, fromFile: file, completionHandler: dataCompletion($0))
    }
  }

  public convenience init(with request: URLRequest, fromFile file: URL, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(with: request, fromFile: file, session: session, queue: queue)
  }
}

public class DeferredURLDownloadTask: DeferredURLTask<FileHandle>
{
  static let resumeScheme = "url-session-resume"
  static let corelibsFoundationUnimplemented = "corelibs-foundation-unimplemented"

  public init(with request: URLRequest, session: URLSession = .shared, queue: DispatchQueue)
  {
    super.init(request: request, queue: queue) {
      session.downloadTask(with: request, completionHandler: downloadCompletion($0))
    }
  }

  public convenience init(with request: URLRequest, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(with: request, session: session, queue: queue)
  }

  public convenience init(with url: URL, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    self.init(with: URLRequest(url: url), session: session, qos: qos)
  }

  public init(withResumeData data: Data, session: URLSession = .shared, queue: DispatchQueue)
  {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    let request = URLRequest(url: URL(string: "\(DeferredURLDownloadTask.resumeScheme):")!)
#else
    // swift-corelibs-foundation calls NSUnimplemented() as the body of downloadTask(withResumeData:)
    // It should instead call the completion handler with URLError.unsupportedURL
    let request = URLRequest(url: URL(string: "\(DeferredURLDownloadTask.corelibsFoundationUnimplemented):")!)
#endif
    super.init(request: request, queue: queue) {
      session.downloadTask(withResumeData: data, completionHandler: downloadCompletion($0))
    }
  }

  public convenience init(withResumeData data: Data, session: URLSession = .shared, qos: DispatchQoS = .current)
  {
    let queue = DispatchQueue(label: #function, qos: qos)
    self.init(withResumeData: data, session: session, queue: queue)
  }

  fileprivate override func cancelURLSessionTask() -> Bool
  {
    if let task = urlSessionTask as? URLSessionDownloadTask,
       task.state != .completed
    { // try to propagate the cancellation upstream,
      // and let the other completion handler gather the resume data.
      task.cancel(byProducingResumeData: { _ in })
      return true
    }
    return false
  }
}

extension DeferredURLTask
{
  @discardableResult
  public func timeout(seconds: Double, reason: String = "") -> DeferredURLTask
  {
    return self.timeout(after: .now() + seconds, reason: reason)
  }

  @discardableResult
  public func timeout(after deadline: DispatchTime, reason: String = "") -> DeferredURLTask
  {
    if self.isResolved { return self }

    let timedOut = URLError(.timedOut, failingURL: url, reason: reason)
    if deadline < .now()
    {
      cancel(timedOut)
    }
    else if deadline != .distantFuture
    {
      let queue = DispatchQueue(label: "timeout", qos: qos)
      queue.asyncAfter(deadline: deadline) { [weak self] in self?.cancel(timedOut) }
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
