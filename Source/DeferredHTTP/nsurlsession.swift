//
//  nsurlsession.swift
//  deferred
//
//  Created by Guillaume Lessard on 10/02/2016.
//  Copyright © 2016 Guillaume Lessard. All rights reserved.
//

import Dispatch
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import deferred
import CurrentQoS

public enum URLSessionError: Error, Equatable
{
  case interruptedDownload(URLError, Data)
  case invalidState
}

private struct Weak<T: AnyObject>
{
  weak var reference: T?
}

public class DeferredURLSessionTask<Success>: Deferred<Success, Error>
{
  private let taskHolder: Deferred<Weak<URLSessionTask>, Cancellation>

  public var urlSessionTask: URLSessionTask? {
    if case let .success(weak)? = taskHolder.peek()
    {
      return weak.reference
    }
    return nil
  }

  fileprivate init(queue: DispatchQueue, error: Error)
  {
    taskHolder = Deferred(queue: queue, error: .notSelected)
    super.init(queue: queue) { $0.resolve(.failure(error)) }
  }

  init(queue: DispatchQueue, task: @escaping (Resolver<Success, Error>) -> URLSessionTask)
  {
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
  open override func cancel(_ error: Cancellation) -> Bool
  {
    cancelTaskHolder()

    if let task = urlSessionTask,
       task.state != .completed
    { // try to propagate the cancellation upstream
      task.cancel()
      return true
    }
    return false
  }

  fileprivate func cancelTaskHolder()
  {
    taskHolder.cancel(.notSelected)
  }
}

private func validateURL(_ request: URLRequest) -> Invalidation?
{
  let scheme = request.url?.scheme ?? "invalid"
  if scheme != "http" && scheme != "https"
  {
    let message = "deferred does not support url scheme \"\(scheme)\""
    return Invalidation.invalid(message)
  }
  return nil
}

private func dataCompletion(_ resolver: Resolver<(Data, HTTPURLResponse), Error>)
  -> (Data?, URLResponse?, Error?) -> Void
{
  return {
    (data: Data?, response: URLResponse?, error: Error?) in

    if let error = error
    {
      // note that response isn't necessarily `nil` here,
      // but does it ever contain anything that's not in the Error?
      resolver.resolve(error: error)
      return
    }

    if let r = response as? HTTPURLResponse
    {
      if let d = data
      { resolver.resolve(value: (d,r)) }
      else
      { resolver.resolve(error: URLSessionError.invalidState) }
    }
    else // Probably an impossible situation
    { resolver.resolve(error: URLSessionError.invalidState) }
  }
}

extension URLSession
{
  public func deferredDataTask(queue: DispatchQueue,
                               with request: URLRequest) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    if let error = validateURL(request)
    {
      return DeferredURLSessionTask(queue: queue, error: error)
    }

    return DeferredURLSessionTask(queue: queue) {
      self.dataTask(with: request, completionHandler: dataCompletion($0))
    }
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with request: URLRequest) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDataTask(queue: queue, with: request)
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with url: URL) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    return deferredDataTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    if let error = validateURL(request)
    {
      return DeferredURLSessionTask(queue: queue, error: error)
    }

    return DeferredURLSessionTask(queue: queue) {
      self.uploadTask(with: request, from: bodyData, completionHandler: dataCompletion($0))
    }
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredUploadTask(queue: queue, with: request, fromData: bodyData)
  }

  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    if let error = validateURL(request)
    {
      return DeferredURLSessionTask(queue: queue, error: error)
    }

    return DeferredURLSessionTask(queue: queue) {
      self.uploadTask(with: request, fromFile: fileURL, completionHandler: dataCompletion($0))
    }
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLSessionTask<(Data, HTTPURLResponse)>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredUploadTask(queue: queue, with: request, fromFile: fileURL)
  }
}

private class DeferredDownloadTask<Success>: DeferredURLSessionTask<Success>
{
  open override func cancel(_ error: Cancellation) -> Bool
  {
    cancelTaskHolder()

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

// FIXME: should we resolve to a FileHandle here?
// on Mojave (perhaps?) tests are inconsistently failing with invalid URLs

private func downloadCompletion(_ resolver: Resolver<(FileHandle, HTTPURLResponse), Error>)
  -> (URL?, URLResponse?, Error?) -> Void
{
  return {
    (location: URL?, response: URLResponse?, error: Error?) in

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    // rdar://29623544 and https://bugs.swift.org/browse/SR-3403
    let URLSessionDownloadTaskResumeData = NSURLSessionDownloadTaskResumeData
#endif
    if let error = error as? URLError,
       let data = error.userInfo[URLSessionDownloadTaskResumeData] as? Data
    {
      resolver.resolve(error: URLSessionError.interruptedDownload(error, data))
      return
    }
    else if let error = error
    {
      // note that response isn't necessarily `nil` here,
      // but does it ever contain anything that's not in the Error?
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
          resolver.resolve(error: error)
        }
      }
      else // should not happen
      { resolver.resolve(error: URLSessionError.invalidState) }
    }
    else // can happen if resume data is corrupted; otherwise probably an impossible situation
    { resolver.resolve(error: URLSessionError.invalidState) }
  }
}

extension URLSession
{
  public func deferredDownloadTask(queue: DispatchQueue,
                                   with request: URLRequest) -> DeferredURLSessionTask<(FileHandle, HTTPURLResponse)>
  {
    if let error = validateURL(request)
    {
      return DeferredURLSessionTask(queue: queue, error: error)
    }

    return DeferredDownloadTask(queue: queue) {
      self.downloadTask(with: request, completionHandler: downloadCompletion($0))
    }
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with request: URLRequest) -> DeferredURLSessionTask<(FileHandle, HTTPURLResponse)>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDownloadTask(queue: queue, with: request)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with url: URL) -> DeferredURLSessionTask<(FileHandle, HTTPURLResponse)>
  {
    return deferredDownloadTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredDownloadTask(queue: DispatchQueue,
                                   withResumeData data: Data) -> DeferredURLSessionTask<(FileHandle, HTTPURLResponse)>
  {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    return DeferredDownloadTask(queue: queue) {
      self.downloadTask(withResumeData: data, completionHandler: downloadCompletion($0))
    }
#else
    // swift-corelibs-foundation calls NSUnimplemented() as the body of downloadTask(withResumeData:)
    // It should instead call the completion handler with URLError.unsupportedURL
    // let task = downloadTask(withResumeData: data, completionHandler: downloadCompletion(tbd))
    let message = "The operation \'\(#function)\' is not supported on this platform"
    let error = URLError(.unsupportedURL, userInfo: [NSLocalizedDescriptionKey: message])
    return DeferredURLSessionTask(queue: queue, error: error)
#endif
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   withResumeData data: Data) -> DeferredURLSessionTask<(FileHandle, HTTPURLResponse)>
  {
    let queue = DispatchQueue(label: "deferred-urlsessiontask", qos: .utility)
    return deferredDownloadTask(queue: queue, withResumeData: data)
  }
}

extension DeferredURLSessionTask
{
  public func cancel()
  {
    _ = cancel(.notSelected)
  }

  @discardableResult
  public func timeout(seconds: Double) -> DeferredURLSessionTask
  {
    return self.timeout(after: .now() + seconds)
  }

  @discardableResult
  public func timeout(after deadline: DispatchTime) -> DeferredURLSessionTask
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
