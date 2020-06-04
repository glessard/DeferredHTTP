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
                               with request: URLRequest) -> DeferredURLDataTask
  {
    return DeferredURLDataTask(with: request, session: self, queue: queue)
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with request: URLRequest) -> DeferredURLDataTask
  {
    return DeferredURLDataTask(with: request, session: self, qos: qos)
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with url: URL) -> DeferredURLDataTask
  {
    return DeferredURLDataTask(with: url, session: self, qos: qos)
  }
}

extension URLSession
{
  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLUploadTask
  {
    return DeferredURLUploadTask(with: request, fromData: bodyData, session: self, queue: queue)
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromData bodyData: Data) -> DeferredURLUploadTask
  {
    return DeferredURLUploadTask(with: request, fromData: bodyData, session: self, qos: qos)
  }

  public func deferredUploadTask(queue: DispatchQueue,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLUploadTask
  {
    return DeferredURLUploadTask(with: request, fromFile: fileURL, session: self, queue: queue)
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromFile fileURL: URL) -> DeferredURLUploadTask
  {
    return DeferredURLUploadTask(with: request, fromFile: fileURL, session: self, qos: qos)
  }
}

extension URLSession
{
  public func deferredDownloadTask(queue: DispatchQueue,
                                   with request: URLRequest) -> DeferredURLDownloadTask
  {
    return DeferredURLDownloadTask(with: request, session: self, queue: queue)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with request: URLRequest) -> DeferredURLDownloadTask
  {
    return DeferredURLDownloadTask(with: request, session: self, qos: qos)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with url: URL) -> DeferredURLDownloadTask
  {
    return DeferredURLDownloadTask(with: url, session: self, qos: qos)
  }

  public func deferredDownloadTask(queue: DispatchQueue,
                                   withResumeData data: Data) -> DeferredURLDownloadTask
  {
    return DeferredURLDownloadTask(withResumeData: data, session: self, queue: queue)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   withResumeData data: Data) -> DeferredURLDownloadTask
  {
    return DeferredURLDownloadTask(withResumeData: data, session: self, qos: qos)
  }
}
