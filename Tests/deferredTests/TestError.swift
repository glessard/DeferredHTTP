//
//  TestError.swift
//  async-deferred
//
//  Created by Guillaume Lessard on 2015-09-24.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import enum deferred.Result

struct TestError: Error, Equatable
{
  let error: Int
  init(_ e: Int = 0) { error = e }

  func matches<T>(_ result: Result<T>) -> Bool
  {
    if let e = result.error as? TestError
    {
      return self == e
    }
    return false
  }
}

func == (l: TestError, r: TestError) -> Bool
{
  return l.error == r.error
}
