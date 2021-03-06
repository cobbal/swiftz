//
//  Future.swift
//  swiftz
//
//  Created by Maxwell Swadling on 4/06/2014.
//  Copyright (c) 2014 Maxwell Swadling. All rights reserved.
//

import Foundation

class Future<A> {
  var value: Optional<(() -> A)>
  
  var mutex: CMutablePointer<pthread_mutex_t>
  var cond: CMutablePointer<pthread_cond_t>
  let matt: CConstPointer<pthread_mutexattr_t>
  let execCtx: ExecutionContext // for map
  
  init(exec: ExecutionContext, a: () -> A) {
    var mattr:CMutablePointer<pthread_mutexattr_t> = CMutablePointer(owner: nil, value: malloc(UInt(sizeof(pthread_mutexattr_t))).value)
    // TODO: is owner nil ok? is malloc leaking?
    mutex = CMutablePointer(owner: nil, value: malloc(UInt(sizeof(pthread_mutex_t))).value)
    cond = CMutablePointer(owner: nil, value: malloc(UInt(sizeof(pthread_cond_t))).value)
    pthread_mutexattr_init(mattr)
    pthread_mutexattr_settype(mattr, PTHREAD_MUTEX_RECURSIVE)
    matt = CConstPointer(nil, mattr.value)
    pthread_mutex_init(mutex, matt)
    pthread_cond_init(cond, nil)
    
    execCtx = exec
    exec.submit(self, work: a)
  }
  
  deinit {
    free(CMutableVoidPointer(owner: nil, value: mutex.value))
    free(CMutableVoidPointer(owner: nil, value: cond.value))
    free(CMutableVoidPointer(owner: nil, value: matt.value))
  }
  
  func sig(x: A) {
    pthread_mutex_lock(mutex)
    self.value = { x }
    pthread_mutex_unlock(mutex)
    pthread_cond_signal(cond)
  }
  
  func result() -> A {
    pthread_mutex_lock(mutex)
    while !(value) {
      pthread_cond_wait(cond, mutex)
    }
    pthread_mutex_unlock(mutex)
    return value!()
  }
  
  func map<B>(f: A -> B) -> Future<B> {
    return Future<B>(exec: execCtx, { f(self.result()) })
  }
  
  func flatMap<B>(f: A -> Future<B>) -> Future<B> {
    return Future<B>(exec: execCtx, { f(self.result()).result() })
  }
}
