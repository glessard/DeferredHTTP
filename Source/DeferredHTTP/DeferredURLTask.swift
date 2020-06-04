//
//  DeferredURLTask.swift
//
//  Created by Guillaume Lessard on 6/4/20.
//  Copyright © 2016-2020 Guillaume Lessard. All rights reserved.
//

import Foundation

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

private func validateURL(_ request: URLRequest) -> URLError?
{
  let scheme = request.url?.scheme ?? "invalid"
  if scheme == "http" || scheme == "https" || scheme == DeferredDownloadTask.resumeScheme
  {
    return nil
  }

  var info = [String: Any]()
  info["unsupportedURL"] = "DeferredURLTask does not support url scheme \"\(scheme)\""
  info[NSURLErrorKey] = request.url
  return URLError(.unsupportedURL, userInfo: info)
}

class DeferredDownloadTask: DeferredURLTask<FileHandle>
{
  static let resumeScheme = "url-session-resume"

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
