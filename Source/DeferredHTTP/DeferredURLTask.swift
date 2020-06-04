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

private struct Weak<T: AnyObject>
{
  weak var reference: T?
}

public class DeferredURLTask<Success>: Deferred<(Success, HTTPURLResponse), URLError>
{
  private let taskHolder: Deferred<Weak<URLSessionTask>, Cancellation>

  public var urlSessionTask: URLSessionTask? {
    if case let .success(weak)? = taskHolder.peek()
    {
      return weak.reference
    }
    return nil
  }

  init(request: URLRequest, queue: DispatchQueue,
       task: @escaping (Resolver<(Success, HTTPURLResponse), URLError>) -> URLSessionTask)
  {
    if let error = validateURL(request)
    {
      taskHolder = Deferred(queue: queue, result: .failure(.canceled("")))
      super.init(queue: queue, result: .failure(error))
      return
    }

    let (taskResolver, taskHolder) = Deferred<Weak<URLSessionTask>, Cancellation>.CreatePair(queue: queue)
    self.taskHolder = taskHolder

    super.init(queue: queue) {
      resolver in
      let urlSessionTask = task(resolver)
      resolver.retainSource(urlSessionTask)
      if taskResolver.needsResolution
      {
        taskResolver.resolve(value: Weak(reference: urlSessionTask))
        urlSessionTask.resume()
      }
      else
      {
        urlSessionTask.cancel()
      }
    }
  }

  deinit {
    if let state = urlSessionTask?.state
    { // only signal the task if necessary
      if state == .running || state == .suspended { urlSessionTask?.cancel() }
    }
  }

  open override var isCancellable: Bool { return true }

  @discardableResult
  open override func cancel(_ error: Cancellation = .canceled("")) -> Bool
  {
    let canceled = cancelTaskHolder()
    if !canceled,
       let task = urlSessionTask,
       task.state != .completed
    { // try to propagate the cancellation upstream
      task.cancel()
      return true
    }
    return canceled
  }

  fileprivate func cancelTaskHolder() -> Bool
  {
    taskHolder.cancel(.notSelected)
    switch taskHolder.peek()
    {
    case .failure?: return true
    default:        return false
    }
  }
}

private func validateURL(_ request: URLRequest) -> URLError?
{
  let scheme = request.url?.scheme ?? "invalid"
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

  var info = [String: Any]()
  info[NSLocalizedDescriptionKey] = "DeferredURLTask does not support url scheme \"\(scheme)\""
  info[NSURLErrorKey] = request.url
  return URLError(.unsupportedURL, userInfo: info)
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

  @discardableResult
  open override func cancel(_ error: Cancellation = .canceled("")) -> Bool
  {
    let canceled = cancelTaskHolder()
    if !canceled,
       let task = urlSessionTask as? URLSessionDownloadTask,
       task.state != .completed
    { // try to propagate the cancellation upstream,
      // and let the other completion handler gather the resume data.
      task.cancel(byProducingResumeData: { _ in })
      return true
    }
    return canceled
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
