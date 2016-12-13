//
//  clang-atomics.m
//  Test23
//
//  Created by Guillaume Lessard on 2015-05-21.
//  Copyright (c) 2015 Guillaume Lessard. All rights reserved.
//

#import "ClangAtomics.h"

// See: http://clang.llvm.org/doxygen/stdatomic_8h_source.html
//      http://clang.llvm.org/docs/LanguageExtensions.html#c11-atomic-builtins
//      http://en.cppreference.com/w/c/atomic
//      http://en.cppreference.com/w/c/atomic/atomic_compare_exchange

// pointer

void* ReadRawPtr(void** ptr, memory_order order)
{
  return atomic_load_explicit((_Atomic(void*)*)ptr, order);
}

void StoreRawPtr(const void* val, void** ptr, memory_order order)
{
  atomic_store_explicit((_Atomic(void*)*)ptr, (void*)val, order);
}

void* SwapRawPtr(const void* val, void** ptr, memory_order order)
{
  return atomic_exchange_explicit((_Atomic(void*)*)ptr, (void*)val, order);
}

_Bool CASRawPtr(void** current, const void* future, void** ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_strong_explicit((_Atomic(void*)*)ptr, (void**)current, (void*)future, succ, fail);
}

_Bool CASWeakRawPtr(void** current, const void* future, void** ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_weak_explicit((_Atomic(void*)*)ptr, (void**)current, (void*)future, succ, fail);
}

// pointer-sized integer

long ReadWord(long *ptr, memory_order order)
{
  return atomic_load_explicit((_Atomic(long)*)ptr, order);
}

void StoreWord(long val, long* ptr, memory_order order)
{
  atomic_store_explicit((_Atomic(long)*)ptr, val, order);
}

long SwapWord(long val, long *ptr, memory_order order)
{
  return atomic_exchange_explicit((_Atomic(long)*)ptr, val, order);
}

long AddWord(long increment, long* ptr, memory_order order)
{
  return atomic_fetch_add_explicit((_Atomic(long)*)ptr, increment, order);
}

long SubWord(long increment, long* ptr, memory_order order)
{
  return atomic_fetch_sub_explicit((_Atomic(long)*)ptr, increment, order);
}

long OrWord(long bits, long* ptr, memory_order order)
{
  return atomic_fetch_or_explicit((_Atomic(long)*)ptr, bits, order);
}

long XorWord(long bits, long* ptr, memory_order order)
{
  return atomic_fetch_xor_explicit((_Atomic(long)*)ptr, bits, order);
}

long AndWord(long bits, long* ptr, memory_order order)
{
  return atomic_fetch_and_explicit((_Atomic(long)*)ptr, bits, order);
}

_Bool CASWord(long* current, long future, long* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_strong_explicit((_Atomic(long)*)ptr, current, future, succ, fail);
}

_Bool CASWeakWord(long* current, long future, long* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_weak_explicit((_Atomic(long)*)ptr, current, future, succ, fail);
}

// 32-bit integer

int Read32(int *ptr, memory_order order)
{
  return atomic_load_explicit((_Atomic(int)*)ptr, order);
}

void Store32(int val, int* ptr, memory_order order)
{
  atomic_store_explicit((_Atomic(int)*)ptr, val, order);
}

int Swap32(int val, int *ptr, memory_order order)
{
  return atomic_exchange_explicit((_Atomic(int)*)ptr, val, order);
}

int Add32(int increment, int* ptr, memory_order order)
{
  return atomic_fetch_add_explicit((_Atomic(int)*)ptr, increment, order);
}

int Sub32(int increment, int* ptr, memory_order order)
{
  return atomic_fetch_sub_explicit((_Atomic(int)*)ptr, increment, order);
}

int Or32(int bits, int* ptr, memory_order order)
{
  return atomic_fetch_or_explicit((_Atomic(int)*)ptr, bits, order);
}

int Xor32(int bits, int* ptr, memory_order order)
{
  return atomic_fetch_xor_explicit((_Atomic(int)*)ptr, bits, order);
}

int And32(int bits, int* ptr, memory_order order)
{
  return atomic_fetch_and_explicit((_Atomic(int)*)ptr, bits, order);
}

_Bool CAS32(int* current, int future, int* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_strong_explicit((_Atomic(int)*)ptr, current, future, succ, fail);
}

_Bool CASWeak32(int* current, int future, int* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_weak_explicit((_Atomic(int)*)ptr, current, future, succ, fail);
}

// 64-bit integer

long long Read64(long long *ptr, memory_order order)
{
  return atomic_load_explicit((_Atomic(long long)*)ptr, order);
}

void Store64(long long val, long long* ptr, memory_order order)
{
  atomic_store_explicit((_Atomic(long long)*)ptr, val, order);
}

long long Swap64(long long val, long long *ptr, memory_order order)
{
  return atomic_exchange_explicit((_Atomic(long long)*)ptr, val, order);
}

long long Add64(long long increment, long long* ptr, memory_order order)
{
  return atomic_fetch_add_explicit((_Atomic(long long)*)ptr, increment, order);
}

long long Sub64(long long increment, long long* ptr, memory_order order)
{
  return atomic_fetch_sub_explicit((_Atomic(long long)*)ptr, increment, order);
}

long long Or64(long long bits, long long* ptr, memory_order order)
{
  return atomic_fetch_or_explicit((_Atomic(long long)*)ptr, bits, order);
}

long long Xor64(long long bits, long long* ptr, memory_order order)
{
  return atomic_fetch_xor_explicit((_Atomic(long long)*)ptr, bits, order);
}

long long And64(long long bits, long long* ptr, memory_order order)
{
  return atomic_fetch_and_explicit((_Atomic(long long)*)ptr, bits, order);
}

_Bool CAS64(long long* current, long long future, long long* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_strong_explicit((_Atomic(long long)*)ptr, current, future, succ, fail);
}

_Bool CASWeak64(long long* current, long long future, long long* ptr, memory_order succ, memory_order fail)
{
  return atomic_compare_exchange_weak_explicit((_Atomic(long long)*)ptr, current, future, succ, fail);
}
