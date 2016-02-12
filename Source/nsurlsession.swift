//
//  nsurlsession.swift
//  deferred
//
//  Created by Guillaume Lessard on 10/02/2016.
//  Copyright © 2016 Guillaume Lessard. All rights reserved.
//

import Foundation

public enum URLSessionError: ErrorType
{
  case ServerStatus(Int)
  case InterruptedDownload(NSData)
  case InvalidState
}

public class DeferredURLSessionTask<T>: TBD<T>
{
  private weak var sessionTask: NSURLSessionTask? = nil

  init() { super.init(queue: dispatch_get_global_queue(qos_class_self(), 0)) }

  override public func cancel(reason: String = "") -> Bool
  {
    guard !self.isDetermined, let task = sessionTask else { return super.cancel(reason) }

    // try to propagate the cancellation upstream
    task.cancel()
    return task.state == .Canceling
  }

  public private(set) var task: NSURLSessionTask? {
    get {
      // Does this do more than `return sessionTask`?
      if let task = sessionTask
      { return task }
      else
      { return nil }
    }
    set {
      sessionTask = newValue
    }
  }
}

public extension NSURLSession
{
  public func deferredDataTask(request: NSURLRequest) -> DeferredURLSessionTask<(NSData, NSHTTPURLResponse)>
  {
    let tbd = DeferredURLSessionTask<(NSData, NSHTTPURLResponse)>()

    let task = self.dataTaskWithRequest(request) {
      (data: NSData?, response: NSURLResponse?, error: NSError?) in
      if let error = error
      { _ = try? tbd.determine(error) }
      else if let d = data, r = response as? NSHTTPURLResponse
      { _ = try? tbd.determine( (d,r) ) }
      else
      { _ = try? tbd.determine(URLSessionError.InvalidState) }
    }

    tbd.task = task
    task.resume()
    tbd.beginExecution()
    return tbd
  }

  public func deferredDataTask(url: NSURL) -> DeferredURLSessionTask<(NSData, NSHTTPURLResponse)>
  {
    return deferredDataTask(NSURLRequest(URL: url))
  }
}

private class DeferredDownloadTask<T>: DeferredURLSessionTask<T>
{
  override func cancel(reason: String = "") -> Bool
  {
    guard !self.isDetermined,
          let task = sessionTask as? NSURLSessionDownloadTask
    else { return super.cancel(reason) }

    // try to propagate the cancellation upstream
    task.cancelByProducingResumeData {
      data in
      if let data = data
      { _ = try? self.determine(URLSessionError.InterruptedDownload(data)) }
    }
    // task.state == .Canceling (checking would be nice, but that would require sleeping the thread)
    return true
  }
}

extension NSURLSession
{
  public func deferredDownloadTask(request: NSURLRequest) -> DeferredURLSessionTask<(NSURL, NSFileHandle, NSHTTPURLResponse)>
  {
    let tbd = DeferredDownloadTask<(NSURL, NSFileHandle, NSHTTPURLResponse)>()

    let task = self.downloadTaskWithRequest(request) {
      (url: NSURL?, response: NSURLResponse?, error: NSError?) in
      if let error = error
      { _ = try? tbd.determine(error) }
      else if let u = url, r = response as? NSHTTPURLResponse
      {
        let f = (try? NSFileHandle(forReadingFromURL: u)) ?? NSFileHandle.fileHandleWithNullDevice()
        _ = try? tbd.determine( (u,f,r) )
      }
      else
      { _ = try? tbd.determine(URLSessionError.InvalidState) }
    }

    tbd.task = task
    task.resume()
    tbd.beginExecution()
    return tbd
  }

  public func deferredDownloadTask(url: NSURL) -> DeferredURLSessionTask<(NSURL, NSFileHandle, NSHTTPURLResponse)>
  {
    return deferredDownloadTask(NSURLRequest(URL: url))
  }

  public func deferredDownloadTask(data: NSData) -> DeferredURLSessionTask<(NSURL, NSFileHandle, NSHTTPURLResponse)>
  {
    let tbd = DeferredDownloadTask<(NSURL, NSFileHandle, NSHTTPURLResponse)>()

    let task = self.downloadTaskWithResumeData(data) {
      (url: NSURL?, response: NSURLResponse?, error: NSError?) in
      if let error = error
      { _ = try? tbd.determine(error) }
      else if let u = url, r = response as? NSHTTPURLResponse
      {
        let f = (try? NSFileHandle(forReadingFromURL: u)) ?? NSFileHandle.fileHandleWithNullDevice()
        _ = try? tbd.determine( (u,f,r) )
      }
      else
      { _ = try? tbd.determine(URLSessionError.InvalidState) }
    }

    tbd.task = task
    task.resume()
    tbd.beginExecution()
    return tbd
  }
}
