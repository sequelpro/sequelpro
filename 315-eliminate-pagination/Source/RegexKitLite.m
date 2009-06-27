//
//  RegexKitLite.m
//  http://regexkit.sourceforge.net/
//  Licensed under the terms of the BSD License, as specified below.
//

/*
 Copyright (c) 2008-2009, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSRunLoop.h>
#ifdef    __OBJC_GC__
#import <Foundation/NSGarbageCollector.h>
#define RKL_STRONG_REF __strong
#else  // __OBJC_GC__
#define RKL_STRONG_REF
#endif // __OBJC_GC__

#include <objc/runtime.h>
#include <libkern/OSAtomic.h>
#include <mach-o/loader.h>
#include <AvailabilityMacros.h>
#include <dlfcn.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

#import "RegexKitLite.h"

// If the gcc flag -mmacosx-version-min is used with, for example, '=10.2', give a warning that the libicucore.dylib is only available on >= 10.3.
// If you are reading this comment because of this warning, this is to let you know that linking to /usr/lib/libicucore.dylib will cause your executable to fail on < 10.3.
// You will need to build your own version of the ICU library and link to that in order for RegexKitLite to work successfully on < 10.3.  This is not simple.

#if MAC_OS_X_VERSION_MIN_REQUIRED < 1030
#warning The ICU dynamic shared library, /usr/lib/libicucore.dylib, is only available on Mac OS X 10.3 and later.
#warning You will need to supply a version of the ICU library to use RegexKitLite on Mac OS X 10.2 and earlier.
#endif

////////////
#pragma mark Compile time tuneables

#ifndef RKL_CACHE_SIZE
#define RKL_CACHE_SIZE (23UL)
#endif

#ifndef RKL_FIXED_LENGTH
#define RKL_FIXED_LENGTH (2048UL)
#endif

#ifndef RKL_STACK_LIMIT
#define RKL_STACK_LIMIT (128UL * 1024UL)
#endif

#ifdef    RKL_APPEND_TO_ICU_FUNCTIONS
#define RKL_ICU_FUNCTION_APPEND(x) _RKL_CONCAT(x, RKL_APPEND_TO_ICU_FUNCTIONS)
#else  // RKL_APPEND_TO_ICU_FUNCTIONS
#define RKL_ICU_FUNCTION_APPEND(x) x
#endif // RKL_APPEND_TO_ICU_FUNCTIONS

#if       defined(RKL_DTRACE) && (RKL_DTRACE != 0)
#define _RKL_DTRACE_ENABLED
#endif // defined(RKL_DTRACE) && (RKL_DTRACE != 0)

// These are internal, non-public tuneables.
#define RKL_SCRATCH_BUFFERS (4UL)
#define RKL_CACHE_LINE_SIZE (64UL)
#define RKL_DTRACE_REGEXUTF8_SIZE (64UL)

//////////////
#pragma mark -
#pragma mark GCC / Compiler macros

#if       defined (__GNUC__) && (__GNUC__ >= 4)
#define RKL_ATTRIBUTES(attr, ...)        __attribute__((attr, ##__VA_ARGS__))
#define RKL_EXPECTED(cond, expect)       __builtin_expect((long)(cond), (expect))
#define RKL_PREFETCH(ptr)                __builtin_prefetch(ptr)
#define RKL_PREFETCH_UNICHAR(ptr, off)   { const char *p = ((const char *)(ptr)) + ((off) * sizeof(UniChar)) + RKL_CACHE_LINE_SIZE; RKL_PREFETCH(p); RKL_PREFETCH(p + RKL_CACHE_LINE_SIZE); }
#define RKL_HAVE_CLEANUP
#define RKL_CLEANUP(func)                __attribute__((cleanup(func)))
#else  // defined (__GNUC__) && (__GNUC__ >= 4) 
#define RKL_ATTRIBUTES(attr, ...)
#define RKL_EXPECTED(cond, expect)       cond
#define RKL_PREFETCH(ptr)
#define RKL_PREFETCH_UNICHAR(ptr, off)
#define RKL_CLEANUP(func)
#endif // defined (__GNUC__) && (__GNUC__ >= 4) 

#define RKL_STATIC_INLINE                         static __inline__ RKL_ATTRIBUTES(always_inline)
#define RKL_UNUSED_ARG                                              RKL_ATTRIBUTES(unused)
#define RKL_NONNULL_ARGS(arg, ...)                                  RKL_ATTRIBUTES(nonnull(arg, ##__VA_ARGS__))
#define RKL_NONNULL_ARGS_WARN_UNUSED(arg, ...)                      RKL_ATTRIBUTES(warn_unused_result, nonnull(arg, ##__VA_ARGS__))

#if       defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)
#define RKL_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(as, nn, ...) RKL_ATTRIBUTES(warn_unused_result, nonnull(nn, ##__VA_ARGS__), alloc_size(as))
#else  // defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)
#define RKL_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(as, nn, ...) RKL_ATTRIBUTES(warn_unused_result, nonnull(nn, ##__VA_ARGS__))
#endif // defined (__GNUC__) && (__GNUC__ >= 4) && (__GNUC_MINOR__ >= 3)


////////////
#pragma mark -
#pragma mark Assertion macros

// These macros are nearly identical to their NSCParameterAssert siblings.
// This is required because nearly everything is done while cacheSpinLock is locked.
// We need to safely unlock before throwing any of these exceptions.
// @try {} @finally {} significantly slows things down so it's not used.

#define RKLCAssertDictionary(d, ...) rkl_makeAssertDictionary(__PRETTY_FUNCTION__, __FILE__, __LINE__, (d), ##__VA_ARGS__)
#define RKLCDelayedHardAssert(c, e, g) do { id *_e=(e); int _c=(c); if(RKL_EXPECTED(_e == NULL, 0L) || RKL_EXPECTED(*_e != NULL, 0L)) { goto g; } if(RKL_EXPECTED(!_c, 0L)) { *_e = RKLCAssertDictionary(@"Invalid parameter not satisfying: %s", #c); goto g; } } while(0)

#ifdef    NS_BLOCK_ASSERTIONS
#define RKLCDelayedAssert(c, e, g)
#define RKL_UNUSED_ASSERTION_ARG RKL_ATTRIBUTES(unused)
#else  // NS_BLOCK_ASSERTIONS
#define RKLCDelayedAssert(c, e, g) RKLCDelayedHardAssert(c, e, g)
#define RKL_UNUSED_ASSERTION_ARG
#endif // NS_BLOCK_ASSERTIONS

#define RKL_EXCEPTION(e, f, ...)       [NSException exceptionWithName:(e) reason:rkl_stringFromClassAndMethod((self), (_cmd), (f), ##__VA_ARGS__) userInfo:NULL]
#define RKL_RAISE_EXCEPTION(e, f, ...) [RKL_EXCEPTION(e, f, ##__VA_ARGS__) raise]

////////////
#pragma mark -
#pragma mark Utility functions and macros

RKL_STATIC_INLINE BOOL NSRangeInsideRange(NSRange cin, NSRange win) RKL_ATTRIBUTES(warn_unused_result);
RKL_STATIC_INLINE BOOL NSRangeInsideRange(NSRange cin, NSRange win) { return((((cin.location - win.location) <= win.length) && ((NSMaxRange(cin) - win.location) <= win.length)) ? YES : NO); }

#define NSMakeRange(loc, len) ((NSRange){.location=(NSUInteger)(loc), .length=(NSUInteger)(len)})
#define CFMakeRange(loc, len) ((CFRange){.location=   (CFIndex)(loc), .length=   (CFIndex)(len)})
#define NSNotFoundRange       ((NSRange){.location=       NSNotFound, .length=              0UL})
#define NSMaxiumRange         ((NSRange){.location=              0UL, .length=    NSUIntegerMax})

////////////
#pragma mark -
#pragma mark Exported NSString symbols for exception names, error domains, error keys, etc

NSString * const RKLICURegexException            = @"RKLICURegexException";

NSString * const RKLICURegexErrorDomain          = @"RKLICURegexErrorDomain";

NSString * const RKLICURegexErrorCodeErrorKey    = @"RKLICURegexErrorCode";
NSString * const RKLICURegexErrorNameErrorKey    = @"RKLICURegexErrorName";
NSString * const RKLICURegexLineErrorKey         = @"RKLICURegexLine";
NSString * const RKLICURegexOffsetErrorKey       = @"RKLICURegexOffset";
NSString * const RKLICURegexPreContextErrorKey   = @"RKLICURegexPreContext";
NSString * const RKLICURegexPostContextErrorKey  = @"RKLICURegexPostContext";
NSString * const RKLICURegexRegexErrorKey        = @"RKLICURegexRegex";
NSString * const RKLICURegexRegexOptionsErrorKey = @"RKLICURegexRegexOptions";

////////////
#pragma mark -
#pragma mark Type / struct definitions

// In general, the ICU bits and pieces here must exactly match the definition in the ICU sources.

#define U_ZERO_ERROR              0
#define U_INDEX_OUTOFBOUNDS_ERROR 8
#define U_BUFFER_OVERFLOW_ERROR   15

#define U_PARSE_CONTEXT_LEN       16

typedef struct uregex uregex; // Opaque ICU regex type.

typedef struct UParseError { // This must be exactly the same as the 'real' ICU declaration.
  int32_t line;
  int32_t offset;
  UniChar preContext[U_PARSE_CONTEXT_LEN];
  UniChar postContext[U_PARSE_CONTEXT_LEN];
} UParseError;

// For use with GCC's cleanup() __attribute__.
#define  RKLLockedCacheSpinLock   ((NSUInteger)(1UL<<0))
#define  RKLUnlockedCacheSpinLock ((NSUInteger)(1UL<<1))

enum {
  RKLSplitOp           = 1,
  RKLReplaceOp         = 2,
  RKLRangeOp           = 3,
  RKLArrayOfStringsOp  = 4,
  RKLArrayOfCapturesOp = 5,
  RKLCapturesArrayOp   = 6,
  RKLMaskOp            = 0xf,
  RKLReplaceMutable    = 1 << 4,
  RKLSubcapturesArray  = 1 << 5,
};
typedef NSUInteger RKLRegexOp;

typedef struct {
                 NSRange    *ranges, findInRange;
                 NSInteger   capacity, found, findUpTo, capture;
                 size_t      size, stackUsed;
                 void      **rangesScratchBuffer;
  RKL_STRONG_REF void      **stringsScratchBuffer;
  RKL_STRONG_REF void      **arraysScratchBuffer;
} RKLFindAll;

typedef struct {
                 CFStringRef  string;
                 CFHashCode   hash;
                 CFIndex      length;
  RKL_STRONG_REF UniChar     *uniChar;
} RKLBuffer;

typedef struct {
  CFStringRef      regexString;
  RKLRegexOptions  options;
  uregex          *icu_regex;
  NSInteger        captureCount;
  
  CFStringRef      setToString;
  CFHashCode       setToHash;
  CFIndex          setToLength;
  NSUInteger       setToIsImmutable:1;
  NSUInteger       setToNeedsConversion:1;
  const UniChar   *setToUniChar;
  NSRange          setToRange, lastFindRange, lastMatchRange;
#ifndef   __LP64__
  NSUInteger       pad[1]; // For 32 bits, this makes the struct 64 bytes exactly, which is good for cache line alignment.
#endif // __LP64__
} RKLCacheSlot;

////////////
#pragma mark -
#pragma mark Translation unit scope global variables

static UniChar              fixedUniChar[(RKL_FIXED_LENGTH)];     // This is the fixed sized UTF-16 conversion buffer.
static RKLCacheSlot         rkl_cacheSlots[(RKL_CACHE_SIZE)], *lastCacheSlot;
static OSSpinLock           cacheSpinLock = OS_SPINLOCK_INIT;
static RKLBuffer            dynamicBuffer, fixedBuffer = {NULL, 0UL, 0L, &fixedUniChar[0]};
static const UniChar        emptyUniCharString[1];                // For safety, icu_regexes are 'set' to this when the string they were searched is cleared.
static RKL_STRONG_REF void *scratchBuffer[(RKL_SCRATCH_BUFFERS)]; // Used to hold temporary allocations that are allocated via reallocf().

////////////
#pragma mark -
#pragma mark CFArray call backs

// These are used when running under manual memory management for the array that rkl_splitArray creates.
// The split strings are created, but not autoreleased.  The (immutable) array is created using these callbacks, which skips the CFRetain() call, effectively transferring ownership to the CFArray object.
// For each split string this saves the overhead of an autorelease, then an array retain, then an NSAutoreleasePool release. This is good for a ~30% speed increase.

static void             RKLCFArrayRelease                 (CFAllocatorRef allocator RKL_UNUSED_ARG, const void *ptr) { CFRelease((CFTypeRef)ptr);                                       }
static CFArrayCallBacks transferOwnershipArrayCallBacks =                                                            { (CFIndex)0L, NULL, RKLCFArrayRelease, CFCopyDescription, CFEqual };

#if defined(__OBJC_GC__) || defined(RKL_FORCE_GC)
////////////
#pragma mark -
#pragma mark Low-level Garbage Collection aware memory/resource allocation utilities
// If compiled with Garbage Collection, we need to be able to do a few things slightly differently.
// The basic premiss is that under GC we use a trampoline function pointer which is set to a _start function to catch the first invocation.
// The _start function checks if GC is running and then overwrites the function pointer with the appropriate routine.  Think of it as 'lazy linking'.

enum { RKLScannedOption = NSScannedOption };

// rkl_collectingEnabled uses objc_getClass() to get the NSGarbageCollector class, which doesn't exist on earlier systems.
// This allows for graceful failure should we find ourselves running on an earlier version of the OS without NSGarbageCollector.
static BOOL  rkl_collectingEnabled_first (void);
static BOOL  rkl_collectingEnabled_yes   (void) { return(YES); }
static BOOL  rkl_collectingEnabled_no    (void) { return(NO); }
static BOOL(*rkl_collectingEnabled)      (void) = rkl_collectingEnabled_first;
static BOOL  rkl_collectingEnabled_first (void) {
  BOOL gcEnabled = ([objc_getClass("NSGarbageCollector") defaultCollector] != NULL) ? YES : NO;
  if(gcEnabled == YES) {
    // This section of code is required due to what I consider to be a fundamental design flaw in Cocoas GC system.
    // Earlier versions of "Garbage Collection Programming Guide" stated that (paraphrased) "all globals are automatically roots".
    // Current versions of the guide now include the following warning:
    //    "You may pass addresses of strong globals or statics into routines expecting pointers to object pointers (such as id* or NSError**)
    //     only if they have first been assigned to directly, rather than through a pointer dereference."
    // This is a surprisingly non-trivial condition to actually meet in practice and is a recipe for impossible to debug race condition bugs.
    // We just happen to be very, very, very lucky in the fact that we can initilize our root set before the first use.
    int x;
    for(x = 0; x < (int)(RKL_SCRATCH_BUFFERS); x++) { scratchBuffer[x] = NSAllocateCollectable(16UL, 0UL); scratchBuffer[x] = NULL; }
    dynamicBuffer.uniChar = (RKL_STRONG_REF UniChar *)NSAllocateCollectable(16UL, 0UL); dynamicBuffer.uniChar = NULL;
  }
  return((rkl_collectingEnabled = (gcEnabled == YES) ? rkl_collectingEnabled_yes : rkl_collectingEnabled_no)());
}

// rkl_realloc()
static void   *rkl_realloc_first (RKL_STRONG_REF void **ptr, size_t size, NSUInteger flags);
static void   *rkl_realloc_std   (RKL_STRONG_REF void **ptr, size_t size, NSUInteger flags RKL_UNUSED_ARG) { return((*ptr = reallocf(*ptr, size))); }
static void   *rkl_realloc_gc    (RKL_STRONG_REF void **ptr, size_t size, NSUInteger flags)                { return((*ptr = NSReallocateCollectable(*ptr, (NSUInteger)size, flags))); }
static void *(*rkl_realloc)      (RKL_STRONG_REF void **ptr, size_t size, NSUInteger flags) RKL_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(2,1) = rkl_realloc_first;
static void   *rkl_realloc_first (RKL_STRONG_REF void **ptr, size_t size, NSUInteger flags)                { return((rkl_realloc = (rkl_collectingEnabled()==YES) ? rkl_realloc_gc : rkl_realloc_std)(ptr, size, flags)); }

// rkl_free()
static void *  rkl_free_first (RKL_STRONG_REF void **ptr);
static void *  rkl_free_std   (RKL_STRONG_REF void **ptr) { if(*ptr != NULL) { free(*ptr); *ptr = NULL; } return(NULL); }
static void *  rkl_free_gc    (RKL_STRONG_REF void **ptr) { if(*ptr != NULL) { *ptr = NULL; } return(NULL); }
static void *(*rkl_free)      (RKL_STRONG_REF void **ptr) RKL_NONNULL_ARGS(1) = rkl_free_first;
static void *  rkl_free_first (RKL_STRONG_REF void **ptr) { return((rkl_free = (rkl_collectingEnabled()==YES) ? rkl_free_gc : rkl_free_std)(ptr)); }

// rkl_CFAutorelease()
static id  rkl_CFAutorelease_first (CFTypeRef obj);
static id  rkl_CFAutorelease_std   (CFTypeRef obj) { return([(id)obj autorelease]); }
static id  rkl_CFAutorelease_gc    (CFTypeRef obj) { return(NSMakeCollectable(obj)); }
static id(*rkl_CFAutorelease)      (CFTypeRef obj) = rkl_CFAutorelease_first;
static id  rkl_CFAutorelease_first (CFTypeRef obj) { return((rkl_CFAutorelease = (rkl_collectingEnabled()==YES) ? rkl_CFAutorelease_gc : rkl_CFAutorelease_std)(obj)); }

// rkl_CreateStringWithSubstring()
static id  rkl_CreateStringWithSubstring_first (id string, NSRange range);
static id  rkl_CreateStringWithSubstring_std   (id string, NSRange range) { return((id)CFStringCreateWithSubstring(NULL, (CFStringRef)string, CFMakeRange((CFIndex)range.location, (CFIndex)range.length))); }
static id  rkl_CreateStringWithSubstring_gc    (id string, NSRange range) { return([string substringWithRange:range]); }
static id(*rkl_CreateStringWithSubstring)      (id string, NSRange range) RKL_NONNULL_ARGS_WARN_UNUSED(1) = rkl_CreateStringWithSubstring_first;
static id  rkl_CreateStringWithSubstring_first (id string, NSRange range) { return((rkl_CreateStringWithSubstring = (rkl_collectingEnabled()==YES) ? rkl_CreateStringWithSubstring_gc : rkl_CreateStringWithSubstring_std)(string, range)); }

// rkl_ReleaseObject()
static id   rkl_ReleaseObject_first (id obj);
static id   rkl_ReleaseObject_std   (id obj)                { CFRelease((CFTypeRef)obj); return(NULL); }
static id   rkl_ReleaseObject_gc    (id obj RKL_UNUSED_ARG) { return(NULL); }
static id (*rkl_ReleaseObject)      (id obj) RKL_NONNULL_ARGS(1) = rkl_ReleaseObject_first;
static id   rkl_ReleaseObject_first (id obj)                { return((rkl_ReleaseObject = (rkl_collectingEnabled()==YES) ? rkl_ReleaseObject_gc : rkl_ReleaseObject_std)(obj)); }

// rkl_CreateArrayWithObjects()
static id  rkl_CreateArrayWithObjects_first (void **objects, NSUInteger count);
static id  rkl_CreateArrayWithObjects_std   (void **objects, NSUInteger count) { return((id)CFArrayCreate(NULL, (const void **)objects, (CFIndex)count, &transferOwnershipArrayCallBacks)); }
static id  rkl_CreateArrayWithObjects_gc    (void **objects, NSUInteger count) { return([NSArray arrayWithObjects:(const id *)objects count:count]); }
static id(*rkl_CreateArrayWithObjects)      (void **objects, NSUInteger count) RKL_NONNULL_ARGS_WARN_UNUSED(1) = rkl_CreateArrayWithObjects_first;
static id  rkl_CreateArrayWithObjects_first (void **objects, NSUInteger count) { return((rkl_CreateArrayWithObjects = (rkl_collectingEnabled()==YES) ? rkl_CreateArrayWithObjects_gc : rkl_CreateArrayWithObjects_std)(objects, count)); }

// rkl_CreateAutoreleasedArray()
static id  rkl_CreateAutoreleasedArray_first (void **objects, NSUInteger count);
static id  rkl_CreateAutoreleasedArray_std   (void **objects, NSUInteger count) { return((id)rkl_CFAutorelease(rkl_CreateArrayWithObjects(objects, count))); }
static id  rkl_CreateAutoreleasedArray_gc    (void **objects, NSUInteger count) { return(rkl_CreateArrayWithObjects(objects, count)); }
static id(*rkl_CreateAutoreleasedArray)      (void **objects, NSUInteger count) RKL_NONNULL_ARGS_WARN_UNUSED(1) = rkl_CreateAutoreleasedArray_first;
static id  rkl_CreateAutoreleasedArray_first (void **objects, NSUInteger count) { return((rkl_CreateAutoreleasedArray = (rkl_collectingEnabled()==YES) ? rkl_CreateAutoreleasedArray_gc : rkl_CreateAutoreleasedArray_std)(objects, count)); }

#else  // __OBJC_GC__ not defined
////////////
#pragma mark -
#pragma mark Low-level explicit memory/resource allocation utilities

enum { RKLScannedOption = 0 };

#define rkl_collectingEnabled() (NO)

RKL_STATIC_INLINE void *rkl_realloc                   (void **ptr, size_t size, NSUInteger flags) RKL_ALLOC_SIZE_NON_NULL_ARGS_WARN_UNUSED(2,1);
RKL_STATIC_INLINE void *rkl_free                      (void **ptr)                                RKL_NONNULL_ARGS(1);
RKL_STATIC_INLINE id    rkl_CFAutorelease             (CFTypeRef obj);
RKL_STATIC_INLINE id    rkl_CreateAutoreleasedArray   (void **objects, NSUInteger count)          RKL_NONNULL_ARGS_WARN_UNUSED(1);
RKL_STATIC_INLINE id    rkl_CreateArrayWithObjects    (void **objects, NSUInteger count)          RKL_NONNULL_ARGS_WARN_UNUSED(1);
RKL_STATIC_INLINE id    rkl_CreateStringWithSubstring (id string, NSRange range)                  RKL_NONNULL_ARGS_WARN_UNUSED(1);
RKL_STATIC_INLINE id    rkl_ReleaseObject             (id obj)                                    RKL_NONNULL_ARGS(1);

RKL_STATIC_INLINE void *rkl_realloc                   (void **ptr, size_t size, NSUInteger flags RKL_UNUSED_ARG) { return((*ptr = reallocf(*ptr, size))); }
RKL_STATIC_INLINE void *rkl_free                      (void **ptr)                                               { if(*ptr != NULL) { free(*ptr); *ptr = NULL; } return(NULL); }
RKL_STATIC_INLINE id    rkl_CFAutorelease             (CFTypeRef obj)                                            { return([(id)obj autorelease]); }
RKL_STATIC_INLINE id    rkl_CreateArrayWithObjects    (void **objects, NSUInteger count)                         { return((id)CFArrayCreate(NULL, (const void **)objects, (CFIndex)count, &transferOwnershipArrayCallBacks)); }
RKL_STATIC_INLINE id    rkl_CreateAutoreleasedArray   (void **objects, NSUInteger count)                         { return(rkl_CFAutorelease(rkl_CreateArrayWithObjects(objects, count))); }
RKL_STATIC_INLINE id    rkl_CreateStringWithSubstring (id string, NSRange range)                                 { return((id)CFStringCreateWithSubstring(NULL, (CFStringRef)string, CFMakeRange((CFIndex)range.location, (CFIndex)range.length))); }
RKL_STATIC_INLINE id    rkl_ReleaseObject             (id obj)                                                   { CFRelease((CFTypeRef)obj); return(NULL); }

#endif // __OBJC_GC__

////////////
#pragma mark -
#pragma mark ICU function prototypes

// ICU functions.  See http://www.icu-project.org/apiref/icu4c/uregex_8h.html Tweaked slightly from the originals, but functionally identical.
const char *RKL_ICU_FUNCTION_APPEND(u_errorName)              (int32_t status)   RKL_ATTRIBUTES(pure);
int32_t     RKL_ICU_FUNCTION_APPEND(u_strlen)                 (const UniChar *s) RKL_ATTRIBUTES(nonnull(1), pure);
int32_t     RKL_ICU_FUNCTION_APPEND(uregex_appendReplacement) (uregex *regexp, const UniChar *replacementText, int32_t replacementLength, UniChar **destBuf, int32_t *destCapacity, int32_t *status) RKL_NONNULL_ARGS(1,2,4,5,6);
int32_t     RKL_ICU_FUNCTION_APPEND(uregex_appendTail)        (uregex *regexp, UniChar **destBuf, int32_t *destCapacity, int32_t *status) RKL_NONNULL_ARGS(1,2,3,4);
void        RKL_ICU_FUNCTION_APPEND(uregex_close)             (uregex *regexp) RKL_NONNULL_ARGS(1);
int32_t     RKL_ICU_FUNCTION_APPEND(uregex_end)               (uregex *regexp, int32_t groupNum, int32_t *status) RKL_NONNULL_ARGS(1,3);
BOOL        RKL_ICU_FUNCTION_APPEND(uregex_find)              (uregex *regexp, int32_t location, int32_t *status) RKL_NONNULL_ARGS(1,3);
BOOL        RKL_ICU_FUNCTION_APPEND(uregex_findNext)          (uregex *regexp, int32_t *status) RKL_NONNULL_ARGS(1,2);
int32_t     RKL_ICU_FUNCTION_APPEND(uregex_groupCount)        (uregex *regexp, int32_t *status) RKL_NONNULL_ARGS(1,2);
uregex     *RKL_ICU_FUNCTION_APPEND(uregex_open)              (const UniChar *pattern, int32_t patternLength, RKLRegexOptions flags, UParseError *parseError, int32_t *status) RKL_NONNULL_ARGS_WARN_UNUSED(1,4,5);
void        RKL_ICU_FUNCTION_APPEND(uregex_reset)             (uregex *regexp, int32_t newIndex, int32_t *status) RKL_NONNULL_ARGS(1,3);
void        RKL_ICU_FUNCTION_APPEND(uregex_setText)           (uregex *regexp, const UniChar *text, int32_t textLength, int32_t *status) RKL_NONNULL_ARGS(1,2,4);
int32_t     RKL_ICU_FUNCTION_APPEND(uregex_start)             (uregex *regexp, int32_t groupNum, int32_t *status) RKL_NONNULL_ARGS(1,3);

////////////
#pragma mark -
#pragma mark RegexKitLite internal, private function prototypes

static RKLCacheSlot *rkl_getCachedRegex            (NSString *regexString, RKLRegexOptions options, NSError **error, id *exception RKL_UNUSED_ASSERTION_ARG)                                                                                                   RKL_NONNULL_ARGS_WARN_UNUSED(1,4);
static NSUInteger    rkl_setCacheSlotToString      (RKLCacheSlot *cacheSlot, const NSRange *range, int32_t *status, id *exception RKL_UNUSED_ASSERTION_ARG)                                                                                                    RKL_NONNULL_ARGS_WARN_UNUSED(1,2,3,4);
static RKLCacheSlot *rkl_getCachedRegexSetToString (NSString *regexString, RKLRegexOptions options, NSString *matchString, NSUInteger *matchLengthPtr, NSRange *matchRange, NSError **error, id *exception, int32_t *status)                                   RKL_NONNULL_ARGS_WARN_UNUSED(1,3,4,5,7,8);
static id            rkl_performRegexOp            (id self, SEL _cmd, RKLRegexOp regexOp, NSString *regexString, RKLRegexOptions options, NSInteger capture, id matchString, NSRange *matchRange, NSString *replacementString, NSError **error, void *result) RKL_NONNULL_ARGS(1,2);
static void          rkl_handleDelayedAssert       (id self, SEL _cmd, id exception)                                                                                                                                                                           RKL_NONNULL_ARGS(1,2,3);

static NSUInteger    rkl_search                    (RKLCacheSlot *cacheSlot, NSRange *searchRange, NSUInteger updateSearchRange, id *exception RKL_UNUSED_ASSERTION_ARG, int32_t *status)                        RKL_NONNULL_ARGS_WARN_UNUSED(1,2,4,5);

static BOOL          rkl_findRanges                (RKLCacheSlot *cacheSlot, RKLRegexOp regexOp,      RKLFindAll *findAll, id *exception, int32_t *status)                                                       RKL_NONNULL_ARGS_WARN_UNUSED(1,3,4,5);
static NSUInteger    rkl_growFindRanges            (RKLCacheSlot *cacheSlot, NSUInteger lastLocation, RKLFindAll *findAll, id *exception RKL_UNUSED_ASSERTION_ARG)                                               RKL_NONNULL_ARGS_WARN_UNUSED(1,3,4);
static NSArray      *rkl_makeArray                 (RKLCacheSlot *cacheSlot, RKLRegexOp regexOp,      RKLFindAll *findAll, id *exception RKL_UNUSED_ASSERTION_ARG)                                               RKL_NONNULL_ARGS_WARN_UNUSED(1,3,4);

static NSString     *rkl_replaceString             (RKLCacheSlot *cacheSlot, id searchString, NSUInteger searchU16Length, NSString *replacementString, NSUInteger replacementU16Length, NSUInteger *replacedCount, NSUInteger replaceMutable, id *exception, int32_t *status)            RKL_NONNULL_ARGS_WARN_UNUSED(1,2,4,8,9);
static int32_t       rkl_replaceAll                (RKLCacheSlot *cacheSlot, const UniChar *replacementUniChar, int32_t replacementU16Length, UniChar *replacedUniChar, int32_t replacedU16Capacity, NSUInteger *replacedCount, id *exception RKL_UNUSED_ASSERTION_ARG, int32_t *status) RKL_NONNULL_ARGS_WARN_UNUSED(1,2,4,7,8);

static NSUInteger    rkl_isRegexValid              (id self, SEL _cmd, NSString *regex, RKLRegexOptions options, NSInteger *captureCountPtr, NSError **error) RKL_NONNULL_ARGS(1,2);

static void          rkl_clearStringCache          (void);
static void          rkl_clearBuffer               (RKLBuffer *buffer, NSUInteger freeDynamicBuffer) RKL_NONNULL_ARGS(1);
static void          rkl_clearCacheSlotRegex       (RKLCacheSlot *cacheSlot)                         RKL_NONNULL_ARGS(1);
static void          rkl_clearCacheSlotSetTo       (RKLCacheSlot *cacheSlot)                         RKL_NONNULL_ARGS(1);

static NSDictionary *rkl_userInfoDictionary        (NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status, ...) RKL_ATTRIBUTES(sentinel, nonnull(1), warn_unused_result);
static NSError      *rkl_NSErrorForRegex           (NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status)      RKL_NONNULL_ARGS_WARN_UNUSED(1);
static NSException  *rkl_NSExceptionForRegex       (NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status)      RKL_NONNULL_ARGS_WARN_UNUSED(1);
static NSDictionary *rkl_makeAssertDictionary      (const char *function, const char *file, int line, NSString *format, ...)                            RKL_NONNULL_ARGS_WARN_UNUSED(1,2,4);
static NSString     *rkl_stringFromClassAndMethod  (id object, SEL selector, NSString *format, ...)                                                     RKL_NONNULL_ARGS_WARN_UNUSED(1,2,3);

RKL_STATIC_INLINE int32_t rkl_getRangeForCapture(RKLCacheSlot *cs, int32_t *s, int32_t c, NSRange *r) RKL_NONNULL_ARGS_WARN_UNUSED(1,2,4);
RKL_STATIC_INLINE int32_t rkl_getRangeForCapture(RKLCacheSlot *cs, int32_t *s, int32_t c, NSRange *r) { uregex *re = cs->icu_regex; int32_t start = RKL_ICU_FUNCTION_APPEND(uregex_start)(re, c, s); if(RKL_EXPECTED((*s > U_ZERO_ERROR), 0L) || (start == -1)) { *r = NSNotFoundRange; } else { r->location = (NSUInteger)start; r->length = (NSUInteger)RKL_ICU_FUNCTION_APPEND(uregex_end)(re, c, s) - r->location; r->location += cs->setToRange.location; } return(*s); }

RKL_STATIC_INLINE RKLFindAll rkl_makeFindAll(NSRange *r, NSRange fir, NSInteger c, size_t s, size_t su, void **rsb, RKL_STRONG_REF void **ssb, RKL_STRONG_REF void **asb, NSInteger f, NSInteger cap, NSInteger fut) RKL_ATTRIBUTES(warn_unused_result);
RKL_STATIC_INLINE RKLFindAll rkl_makeFindAll(NSRange *r, NSRange fir, NSInteger c, size_t s, size_t su, void **rsb, RKL_STRONG_REF void **ssb, RKL_STRONG_REF void **asb, NSInteger f, NSInteger cap, NSInteger fut) { return(((RKLFindAll){ .ranges=r, .findInRange=fir, .capacity=c, .found=f, .findUpTo=fut, .capture=cap, .size=s, .stackUsed=su, .rangesScratchBuffer=rsb, .stringsScratchBuffer=ssb, .arraysScratchBuffer=asb})); }

////////////
#pragma mark -
#pragma mark RKL_FAST_MUTABLE_CHECK implementation

#ifdef RKL_FAST_MUTABLE_CHECK
// We use a trampoline function pointer to check at run time if the function __CFStringIsMutable is available.
// If it is, the trampoline function pointer is replaced with the address of that function.
// Otherwise, we assume the worst case that every string is mutable.
// This hopefully helps to protect us since we're using an undocumented, non-public API call.
// We will keep on working if it ever does go away, just with a bit less performance due to the overhead of mutable checks.

static BOOL  rkl_CFStringIsMutable_first (CFStringRef str);
static BOOL  rkl_CFStringIsMutable_yes   (CFStringRef str RKL_UNUSED_ARG) { return(YES); }
static BOOL(*rkl_CFStringIsMutable)      (CFStringRef str) = rkl_CFStringIsMutable_first;
static BOOL  rkl_CFStringIsMutable_first (CFStringRef str)                { if((rkl_CFStringIsMutable = (BOOL(*)(CFStringRef))dlsym(RTLD_DEFAULT, "__CFStringIsMutable")) == NULL) { rkl_CFStringIsMutable = rkl_CFStringIsMutable_yes; } return(rkl_CFStringIsMutable(str)); }
#else  // RKL_FAST_MUTABLE_CHECK is not defined.  Assume that all strings are potentially mutable.
#define rkl_CFStringIsMutable(s) (YES)
#endif // RKL_FAST_MUTABLE_CHECK


////////////
#pragma mark -
#pragma mark iPhone / iPod touch low memory notification handler

#if       defined(RKL_REGISTER_FOR_IPHONE_LOWMEM_NOTIFICATIONS) && (RKL_REGISTER_FOR_IPHONE_LOWMEM_NOTIFICATIONS == 1)

// The next few lines are specifically for the iPhone to catch low memory conditions.
// The basic idea is that rkl_RegisterForLowMemoryNotifications() is set to be run once by the linker at load time via __attribute((constructor)).
// rkl_RegisterForLowMemoryNotifications() tries to find the iPhone low memory notification symbol.  If it can find it,
// it registers with the default NSNotificationCenter to call the RKLLowMemoryWarningObserver class method +lowMemoryWarning:.
// rkl_RegisterForLowMemoryNotifications() uses an atomic compare and swap to guarantee that it initalizes exactly once.
// +lowMemoryWarning tries to acquire the cache lock.  If it gets the lock, it clears the cache.  If it can't, it calls performSelector:
// with a delay of half a second to try again.  This will hopefully prevent any deadlocks, such as a RegexKitLite request for
// memory triggering a notifcation while the lock is held.

static void rkl_RegisterForLowMemoryNotifications(void) RKL_ATTRIBUTES(used);

@interface      RKLLowMemoryWarningObserver : NSObject +(void)lowMemoryWarning:(id)notification; @end
@implementation RKLLowMemoryWarningObserver
+(void)lowMemoryWarning:(id)notification {
  if(OSSpinLockTry(&cacheSpinLock)) { rkl_clearStringCache(); OSSpinLockUnlock(&cacheSpinLock); }
  else { [[RKLLowMemoryWarningObserver class] performSelector:@selector(lowMemoryWarning:) withObject:NULL afterDelay:(NSTimeInterval)0.1]; }
}
@end

static int rkl_HaveRegisteredForLowMemoryNotifications = 0;

__attribute__((constructor)) static void rkl_RegisterForLowMemoryNotifications(void) {
  void **memoryWarningNotification = NULL;
  
  if(OSAtomicCompareAndSwapIntBarrier(0, 1, &rkl_HaveRegisteredForLowMemoryNotifications)) {
    if((memoryWarningNotification = (void **)dlsym(RTLD_DEFAULT, "UIApplicationDidReceiveMemoryWarningNotification")) != NULL) {
      [[NSNotificationCenter defaultCenter] addObserver:[RKLLowMemoryWarningObserver class] selector:@selector(lowMemoryWarning:) name:(NSString *)*memoryWarningNotification object:NULL];
    }
  }
}

#endif // defined(RKL_REGISTER_FOR_IPHONE_LOWMEM_NOTIFICATIONS) && (RKL_REGISTER_FOR_IPHONE_LOWMEM_NOTIFICATIONS == 1)

#ifdef    _RKL_DTRACE_ENABLED

// compiledRegexCache(unsigned long eventID, const char *regexUTF8, int options, int captures, int hitMiss, int icuStatusCode, const char *icuErrorMessage, double *hitRate);
// utf16ConversionCache(unsigned long eventID, unsigned int lookupResultFlags, double *hitRate, const void *string, unsigned long NSRange.location, unsigned long NSRange.length, long length);

/*
provider RegexKitLite {
 probe compiledRegexCache(unsigned long, const char *, unsigned int, int, int, int, const char *, double *);
 probe utf16ConversionCache(unsigned long, unsigned int, double *, const void *, unsigned long, unsigned long, long);
};
 
#pragma D attributes Unstable/Unstable/Common provider RegexKitLite provider
#pragma D attributes Private/Private/Common   provider RegexKitLite module
#pragma D attributes Private/Private/Common   provider RegexKitLite function
#pragma D attributes Unstable/Unstable/Common provider RegexKitLite name
#pragma D attributes Unstable/Unstable/Common provider RegexKitLite args
*/

#define REGEXKITLITE_STABILITY "___dtrace_stability$RegexKitLite$v1$4_4_5_1_1_5_1_1_5_4_4_5_4_4_5"
#define REGEXKITLITE_TYPEDEFS  "___dtrace_typedefs$RegexKitLite$v1"
#define REGEXKITLITE_COMPILEDREGEXCACHE(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) { __asm__ volatile(".reference " REGEXKITLITE_TYPEDEFS); __dtrace_probe$RegexKitLite$compiledRegexCache$v1$756e7369676e6564206c6f6e67$63686172202a$756e7369676e656420696e74$696e74$696e74$696e74$63686172202a$646f75626c65202a(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7); __asm__ volatile(".reference " REGEXKITLITE_STABILITY); }
#define REGEXKITLITE_COMPILEDREGEXCACHE_ENABLED() __dtrace_isenabled$RegexKitLite$compiledRegexCache$v1()
#define	REGEXKITLITE_CONVERTEDSTRINGU16CACHE(arg0, arg1, arg2, arg3, arg4, arg5, arg6) { __asm__ volatile(".reference " REGEXKITLITE_TYPEDEFS); __dtrace_probe$RegexKitLite$utf16ConversionCache$v1$756e7369676e6564206c6f6e67$756e7369676e656420696e74$646f75626c65202a$766f6964202a$756e7369676e6564206c6f6e67$756e7369676e6564206c6f6e67$6c6f6e67(arg0, arg1, arg2, arg3, arg4, arg5, arg6); __asm__ volatile(".reference " REGEXKITLITE_STABILITY); }
#define	REGEXKITLITE_CONVERTEDSTRINGU16CACHE_ENABLED() __dtrace_isenabled$RegexKitLite$utf16ConversionCache$v1()

extern void __dtrace_probe$RegexKitLite$compiledRegexCache$v1$756e7369676e6564206c6f6e67$63686172202a$756e7369676e656420696e74$696e74$696e74$696e74$63686172202a$646f75626c65202a(unsigned long, const char *, unsigned int, int, int, int, const char *, double *);
extern int  __dtrace_isenabled$RegexKitLite$compiledRegexCache$v1(void);
extern void __dtrace_probe$RegexKitLite$utf16ConversionCache$v1$756e7369676e6564206c6f6e67$756e7369676e656420696e74$646f75626c65202a$766f6964202a$756e7369676e6564206c6f6e67$756e7369676e6564206c6f6e67$6c6f6e67(unsigned long, unsigned int, double *, const void *, unsigned long, unsigned long, long);
extern int  __dtrace_isenabled$RegexKitLite$utf16ConversionCache$v1(void);

////////////////////////////

enum {
  RKLCacheHitLookupFlag           = 1 << 0,
  RKLConversionRequiredLookupFlag = 1 << 1,
  RKLSetTextLookupFlag            = 1 << 2,
  RKLDynamicBufferLookupFlag      = 1 << 3,
  RKLErrorLookupFlag              = 1 << 4,
};

#define rkl_dtrace_addLookupFlag(a,b) do { a |= (unsigned int)(b); } while(0)

static char rkl_dtrace_regexUTF8[(RKL_CACHE_SIZE) + 1][(RKL_DTRACE_REGEXUTF8_SIZE)];
static NSUInteger rkl_dtrace_eventID, rkl_dtrace_compiledCacheLookups, rkl_dtrace_compiledCacheHits, rkl_dtrace_conversionBufferLookups, rkl_dtrace_conversionBufferHits;

#define rkl_dtrace_incrementEventID() do { rkl_dtrace_eventID++; } while(0)
#define rkl_dtrace_compiledRegexCache(a0, a1, a2, a3, a4, a5) do { int _a3 = (a3); rkl_dtrace_compiledCacheLookups++; if(_a3 == 1) { rkl_dtrace_compiledCacheHits++; } if(RKL_EXPECTED(REGEXKITLITE_COMPILEDREGEXCACHE_ENABLED(), 0L)) { double hitRate = 0.0; if(rkl_dtrace_compiledCacheLookups > 0UL) { hitRate = ((double)rkl_dtrace_compiledCacheHits / (double)rkl_dtrace_compiledCacheLookups) * 100.0; } REGEXKITLITE_COMPILEDREGEXCACHE(rkl_dtrace_eventID, a0, a1, a2, _a3, a4, a5, &hitRate); } } while(0)
#define rkl_dtrace_utf16ConversionCache(a0, a1, a2, a3, a4) do { unsigned int _a0 = (a0); if((_a0 & RKLConversionRequiredLookupFlag) != 0U) { rkl_dtrace_conversionBufferLookups++; if((_a0 & RKLCacheHitLookupFlag) != 0U) { rkl_dtrace_conversionBufferHits++; } } if(RKL_EXPECTED(REGEXKITLITE_CONVERTEDSTRINGU16CACHE_ENABLED(), 0L)) { double hitRate = 0.0; if(rkl_dtrace_conversionBufferLookups > 0UL) { hitRate = ((double)rkl_dtrace_conversionBufferHits / (double)rkl_dtrace_conversionBufferLookups) * 100.0; } REGEXKITLITE_CONVERTEDSTRINGU16CACHE(rkl_dtrace_eventID, _a0, &hitRate, a1, a2, a3, a4); } } while(0)


// \342\200\246 == UTF8 for HORIZONTAL ELLIPSIS, aka triple dots '...'
#define RKL_UTF8_ELLIPSE "\342\200\246"

// rkl_dtrace_getRegexUTF8 will copy the str argument to utf8Buffer using UTF8 as the string encoding.
// If the utf8 encoding would take up more bytes than the utf8Buffers length, then the unicode character 'HORIZONTAL ELLIPSIS' ('...') is appened to indicate truncation occured.
static void rkl_dtrace_getRegexUTF8(CFStringRef str, char *utf8Buffer) RKL_NONNULL_ARGS(2);
static void rkl_dtrace_getRegexUTF8(CFStringRef str, char *utf8Buffer) {
  if((str == NULL) || (utf8Buffer == NULL)) { return; }
  CFIndex maxLength = ((CFIndex)(RKL_DTRACE_REGEXUTF8_SIZE) - 2L), maxBytes = (maxLength - (CFIndex)sizeof(RKL_UTF8_ELLIPSE) - 1L), stringU16Length = CFStringGetLength(str), usedBytes = 0L;
  CFStringGetBytes(str, CFMakeRange(0L, ((stringU16Length < maxLength) ? stringU16Length : maxLength)), kCFStringEncodingUTF8, (UInt8)'?', (Boolean)0, (UInt8 *)utf8Buffer, maxBytes, &usedBytes);
  if(usedBytes == maxBytes) { strncpy(utf8Buffer + usedBytes, RKL_UTF8_ELLIPSE, ((size_t)(RKL_DTRACE_REGEXUTF8_SIZE) - (size_t)usedBytes) - 2UL); } else { utf8Buffer[usedBytes] = (char)0; }
}

#else  // _RKL_DTRACE_ENABLED

#define rkl_dtrace_incrementEventID()
#define rkl_dtrace_compiledRegexCache(a0, a1, a2, a3, a4, a5)
#define rkl_dtrace_utf16ConversionCache(a0, a1, a2, a3, a4)
#define rkl_dtrace_getRegexUTF8(str, buf)
#define rkl_dtrace_addLookupFlag(a,b)

#endif // _RKL_DTRACE_ENABLED

////////////
#pragma mark -
#pragma mark RegexKitLite low-level internal functions

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called with cacheSpinLock already locked!
//  ----------

static RKLCacheSlot *rkl_getCachedRegex(NSString *regexString, RKLRegexOptions options, NSError **error, id *exception RKL_UNUSED_ASSERTION_ARG) {
  RKLCacheSlot *cacheSlot = NULL;
  CFHashCode    regexHash = 0UL;
  int32_t       status    = 0;
  
  RKLCDelayedAssert((cacheSpinLock != 0) && (regexString != NULL), exception, exitNow);
  
  // Fast path the common case where this regex is exactly the same one used last time.
  // The pointer equality test is valid under these circumstances since the cacheSlot->regexString is an immutable copy.
  // If the regexString argument is mutable, this test will fail, and we'll use the the slow path cache check below.
  if(RKL_EXPECTED(lastCacheSlot != NULL, 1L) && RKL_EXPECTED(lastCacheSlot->options == options, 1L) && RKL_EXPECTED(lastCacheSlot->icu_regex != NULL, 1L) && RKL_EXPECTED(lastCacheSlot->regexString != NULL, 1L) && RKL_EXPECTED(lastCacheSlot->regexString == (CFStringRef)regexString, 1L)) {
    rkl_dtrace_compiledRegexCache(&rkl_dtrace_regexUTF8[(lastCacheSlot - &rkl_cacheSlots[0])][0], lastCacheSlot->options, (int)lastCacheSlot->captureCount, 1, 0, NULL);
    return(lastCacheSlot);
  }
  
  regexHash = CFHash((CFTypeRef)regexString);
  cacheSlot = &rkl_cacheSlots[(regexHash % (CFHashCode)(RKL_CACHE_SIZE))]; // Retrieve the cache slot for this regex.
  
  // Return the cached entry if it's a match, otherwise clear the slot and create a new ICU regex in its place.
  // If regexString is mutable, the pointer equality test will fail, and CFEqual() is used to determine true
  // equality with the immutable cacheSlot copy.  CFEqual() performs a slow character by character check.
  if(RKL_EXPECTED(cacheSlot->options == options, 1L) && RKL_EXPECTED(cacheSlot->icu_regex != NULL, 1L) && RKL_EXPECTED(cacheSlot->regexString != NULL, 1L) && (RKL_EXPECTED(cacheSlot->regexString == (CFStringRef)regexString, 1L) || RKL_EXPECTED(CFEqual((CFTypeRef)regexString, (CFTypeRef)cacheSlot->regexString) == YES, 1L))) {
    lastCacheSlot = cacheSlot;
    rkl_dtrace_compiledRegexCache(&rkl_dtrace_regexUTF8[(lastCacheSlot - &rkl_cacheSlots[0])][0], lastCacheSlot->options, (int)lastCacheSlot->captureCount, 1, 0, NULL);
    return(cacheSlot);
  }
  
  rkl_clearCacheSlotRegex(cacheSlot);
  
  if(RKL_EXPECTED((cacheSlot->regexString = CFStringCreateCopy(NULL, (CFStringRef)regexString)) == NULL, 0L)) { goto exitNow; } ; // Get a cheap immutable copy.
  rkl_dtrace_getRegexUTF8(cacheSlot->regexString, &rkl_dtrace_regexUTF8[(cacheSlot - &rkl_cacheSlots[0])][0]);
  cacheSlot->options = options;
  
  CFIndex        regexStringU16Length = CFStringGetLength(cacheSlot->regexString); // In UTF16 code units.
  UParseError    parseError           = (UParseError){-1, -1, {0}, {0}};
  const UniChar *regexUniChar         = NULL;
  
  if(RKL_EXPECTED(regexStringU16Length >= (CFIndex)INT_MAX, 0L)) { *exception = [NSException exceptionWithName:NSRangeException reason:@"Regex string length exceeds INT_MAX" userInfo:NULL]; goto exitNow; }

  // Try to quickly obtain regexString in UTF16 format.
  if((regexUniChar = CFStringGetCharactersPtr(cacheSlot->regexString)) == NULL) { // We didn't get the UTF16 pointer quickly and need to perform a full conversion in a temp buffer.
    UniChar *uniCharBuffer = NULL;
    if(((size_t)regexStringU16Length * sizeof(UniChar)) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((uniCharBuffer = (UniChar *)alloca(                        (size_t)regexStringU16Length * sizeof(UniChar)     )) == NULL, 0L)) { goto exitNow; } } // Try to use the stack.
    else {                                                                             if(RKL_EXPECTED((uniCharBuffer = (UniChar *)rkl_realloc(&scratchBuffer[0], (size_t)regexStringU16Length * sizeof(UniChar), 0UL)) == NULL, 0L)) { goto exitNow; } } // Otherwise use the heap.
    CFStringGetCharacters(cacheSlot->regexString, CFMakeRange(0L, regexStringU16Length), uniCharBuffer); // Convert regexString to UTF16.
    regexUniChar = uniCharBuffer;
  }
  
  // Create the ICU regex.
  if(RKL_EXPECTED((cacheSlot->icu_regex = RKL_ICU_FUNCTION_APPEND(uregex_open)(regexUniChar, (int32_t)regexStringU16Length, options, &parseError, &status)) == NULL, 0L)) { goto exitNow; }
  if(RKL_EXPECTED(status <= U_ZERO_ERROR, 1L)) { cacheSlot->captureCount = (NSInteger)RKL_ICU_FUNCTION_APPEND(uregex_groupCount)(cacheSlot->icu_regex, &status); }
  if(RKL_EXPECTED(status <= U_ZERO_ERROR, 1L)) { lastCacheSlot           = cacheSlot; }
  
exitNow:
  if(RKL_EXPECTED(scratchBuffer[0] != NULL,         0L)) { scratchBuffer[0] = rkl_free(&scratchBuffer[0]); }
  if(RKL_EXPECTED(status            > U_ZERO_ERROR, 0L)) { cacheSlot = NULL; if(error != NULL) { *error = rkl_NSErrorForRegex(regexString, options, &parseError, status); } }
  
#ifdef    _RKL_DTRACE_ENABLED
  if(RKL_EXPECTED(cacheSlot != NULL, 1L)) { rkl_dtrace_compiledRegexCache(&rkl_dtrace_regexUTF8[(cacheSlot - &rkl_cacheSlots[0])][0], cacheSlot->options, (int)cacheSlot->captureCount, 0, status, NULL); }
  else { char regexUTF8[(RKL_DTRACE_REGEXUTF8_SIZE)]; const char *err = NULL; if(status != U_ZERO_ERROR) { err = RKL_ICU_FUNCTION_APPEND(u_errorName)(status); } rkl_dtrace_getRegexUTF8((CFStringRef)regexString, regexUTF8); rkl_dtrace_compiledRegexCache(regexUTF8, options, -1, -1, status, err); }
#endif // _RKL_DTRACE_ENABLED
  
  return(cacheSlot);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called with cacheSpinLock already locked!
//  ----------

static NSUInteger rkl_setCacheSlotToString(RKLCacheSlot *cacheSlot, const NSRange *range, int32_t *status, id *exception RKL_UNUSED_ASSERTION_ARG) {
  RKLCDelayedAssert((cacheSlot != NULL) && (cacheSlot->setToString != NULL) && ((range != NULL) && (NSEqualRanges(*range, NSNotFoundRange) == NO)) && (status != NULL), exception, exitNow);
  const UniChar *stringUniChar = NULL;
#ifdef _RKL_DTRACE_ENABLED
  unsigned int lookupResultFlags = 0U;
#endif
  
  if(cacheSlot->setToNeedsConversion == 0U) {
    if(RKL_EXPECTED((stringUniChar = CFStringGetCharactersPtr(cacheSlot->setToString)) == NULL, 0L)) { cacheSlot->setToNeedsConversion = 1U; }
    else { if(RKL_EXPECTED(cacheSlot->setToUniChar != stringUniChar, 0L)) { cacheSlot->setToRange = NSNotFoundRange; cacheSlot->setToUniChar = stringUniChar; } goto setRegexText; }
  }
  rkl_dtrace_addLookupFlag(lookupResultFlags, RKLConversionRequiredLookupFlag);
  
  NSUInteger  useFixedBuffer = (cacheSlot->setToLength < (CFIndex)(RKL_FIXED_LENGTH)) ? 1UL : 0UL;
  RKLBuffer  *buffer         = useFixedBuffer ? &fixedBuffer : &dynamicBuffer;
  rkl_dtrace_addLookupFlag(lookupResultFlags, (useFixedBuffer ? 0U : RKLDynamicBufferLookupFlag));
  
  if((cacheSlot->setToUniChar != NULL) && ((cacheSlot->setToString == buffer->string) || ((cacheSlot->setToLength == buffer->length) && (cacheSlot->setToHash == buffer->hash)))) { rkl_dtrace_addLookupFlag(lookupResultFlags, RKLCacheHitLookupFlag); goto setRegexText; }
  
  if(RKL_EXPECTED((stringUniChar = CFStringGetCharactersPtr(cacheSlot->setToString)) != NULL, 0L)) { cacheSlot->setToNeedsConversion = 0U; cacheSlot->setToRange = NSNotFoundRange; cacheSlot->setToUniChar = stringUniChar; goto setRegexText; }

  rkl_clearBuffer(buffer, 0UL);
  
  if(useFixedBuffer == 0U) {
    RKLCDelayedAssert(buffer == &dynamicBuffer, exception, exitNow);
    RKL_STRONG_REF void *p = (RKL_STRONG_REF void *)dynamicBuffer.uniChar;
    if(RKL_EXPECTED((dynamicBuffer.uniChar = (RKL_STRONG_REF UniChar *)rkl_realloc(&p, ((size_t)cacheSlot->setToLength * sizeof(UniChar)), 0UL)) == NULL, 0L)) { goto exitNow; } // Resize the buffer.
  }
  
  RKLCDelayedAssert(buffer->uniChar != NULL, exception, exitNow);
  CFStringGetCharacters(cacheSlot->setToString, CFMakeRange(0L, cacheSlot->setToLength), (UniChar *)buffer->uniChar); // Convert to a UTF16 string.
  
  RKLCDelayedAssert(buffer->string == NULL, exception, exitNow);
  if(RKL_EXPECTED((buffer->string = (CFStringRef)CFRetain((CFTypeRef)cacheSlot->setToString)) == NULL, 0L)) { goto exitNow; }
  buffer->hash            = cacheSlot->setToHash;
  buffer->length          = cacheSlot->setToLength;
  
  cacheSlot->setToUniChar = buffer->uniChar;
  cacheSlot->setToRange   = NSNotFoundRange;
  
setRegexText:
  if(NSEqualRanges(cacheSlot->setToRange, *range) == NO) {
    RKLCDelayedAssert((cacheSlot->icu_regex != NULL) && (cacheSlot->setToUniChar != NULL) && (NSMaxRange(*range) <= (NSUInteger)cacheSlot->setToLength) && (cacheSlot->setToRange.length <= INT_MAX), exception, exitNow);
    cacheSlot->lastFindRange = cacheSlot->lastMatchRange = NSNotFoundRange;
    cacheSlot->setToRange    = *range;
    RKL_ICU_FUNCTION_APPEND(uregex_setText)(cacheSlot->icu_regex, cacheSlot->setToUniChar + cacheSlot->setToRange.location, (int32_t)cacheSlot->setToRange.length, status);
    rkl_dtrace_addLookupFlag(lookupResultFlags, RKLSetTextLookupFlag);
    if(RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { goto exitNow; }
  }
  
  rkl_dtrace_utf16ConversionCache(lookupResultFlags, cacheSlot->setToString, cacheSlot->setToRange.location, cacheSlot->setToRange.length, cacheSlot->setToLength);
  return(1UL);
  
exitNow:
  return(0UL);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called with cacheSpinLock already locked!
//  ----------

static RKLCacheSlot *rkl_getCachedRegexSetToString(NSString *regexString, RKLRegexOptions options, NSString *matchString, NSUInteger *matchLengthPtr, NSRange *matchRange, NSError **error, id *exception, int32_t *status) {
  RKLCacheSlot *cacheSlot = NULL;
  RKLCDelayedAssert((regexString != NULL) && (exception != NULL) && (status != NULL) && (matchLengthPtr != NULL), exception, exitNow);
  
  // Fast path the common case where this regex is exactly the same one used last time.
  if(RKL_EXPECTED(lastCacheSlot != NULL, 1L) && RKL_EXPECTED(lastCacheSlot->regexString == (CFStringRef)regexString, 1L) && RKL_EXPECTED(lastCacheSlot->options == options, 1L)) { cacheSlot = lastCacheSlot; rkl_dtrace_compiledRegexCache(&rkl_dtrace_regexUTF8[(cacheSlot - &rkl_cacheSlots[0])][0], cacheSlot->options, (int)cacheSlot->captureCount, 1, 0, NULL); }
  else { if(RKL_EXPECTED((cacheSlot = rkl_getCachedRegex(regexString, options, error, exception)) == NULL, 0L)) { goto exitNow; } }
  
  // Optimize the case where the string to search (matchString) is immutable and the setToString immutable copy is the same string with its reference count incremented.
  NSUInteger isSetTo     = ((cacheSlot->setToString != NULL) && (cacheSlot->setToString      == (CFStringRef)matchString)) ? 1UL : 0UL;
  CFIndex    matchLength = ((isSetTo                == 1UL)  && (cacheSlot->setToIsImmutable == 1U))                       ? cacheSlot->setToLength : CFStringGetLength((CFStringRef)matchString);
  
  *matchLengthPtr = (NSUInteger)matchLength;
  if(matchRange->length == NSUIntegerMax) { matchRange->length = (NSUInteger)matchLength; } // For convenience, allow NSUIntegerMax == string length.
  
  if(RKL_EXPECTED((NSUInteger)matchLength < NSMaxRange(*matchRange), 0L)) { goto exitNow; } // The match range is out of bounds for the string.  performRegexOp will catch and report the problem.
  
  if((cacheSlot->setToIsImmutable == 0U) && (cacheSlot->setToString != NULL) && ((cacheSlot->setToLength != CFStringGetLength(cacheSlot->setToString)) || (cacheSlot->setToHash != CFHash((CFTypeRef)cacheSlot->setToString)))) { isSetTo = 0UL; }
  else { // If the first pointer equality check failed, check the hash and length.
    if(((isSetTo == 0UL) || (cacheSlot->setToIsImmutable == 0U)) && (cacheSlot->setToString != NULL)) { isSetTo = ((cacheSlot->setToLength == matchLength) && (cacheSlot->setToHash == CFHash((CFTypeRef)matchString))) ? 1UL : 0UL; }
    
    if(isSetTo == 1UL) { if(RKL_EXPECTED(rkl_setCacheSlotToString(cacheSlot, matchRange, status, exception) == 0UL, 0L)) { cacheSlot = NULL; if(*exception == NULL) { *exception = (id)RKLCAssertDictionary(@"Failed to set up UTF16 buffer."); } } goto exitNow; }
  }
  
  // Sometimes the range that the regex is set to isn't right, in which case we don't want to clear the cache slot.  Otherwise, flush it out.
  if((cacheSlot->setToString != NULL) && (isSetTo == 0UL)) { rkl_clearCacheSlotSetTo(cacheSlot); }
  
  if(cacheSlot->setToString == NULL) {
    cacheSlot->setToString          = (CFStringRef)CFRetain((CFTypeRef)matchString);
    RKLCDelayedAssert(cacheSlot->setToString != NULL, exception, exitNow);
    cacheSlot->setToUniChar         = CFStringGetCharactersPtr(cacheSlot->setToString);
    cacheSlot->setToNeedsConversion = (cacheSlot->setToUniChar == NULL) ? 1U : 0U;
    cacheSlot->setToIsImmutable     = (rkl_CFStringIsMutable(cacheSlot->setToString) == YES) ? 0U : 1U; // If RKL_FAST_MUTABLE_CHECK is not defined then setToIsImmutable will always be set to '0', or in other words mutable..
    cacheSlot->setToHash            = CFHash((CFTypeRef)cacheSlot->setToString);
    cacheSlot->setToRange           = NSNotFoundRange;
    cacheSlot->setToLength          = matchLength;
  }
  
  if(RKL_EXPECTED(rkl_setCacheSlotToString(cacheSlot, matchRange, status, exception) == 0UL, 0L)) { cacheSlot = NULL; if(*exception == NULL) { *exception = (id)RKLCAssertDictionary(@"Failed to set up UTF16 buffer."); } goto exitNow; }
  
exitNow:
  return(cacheSlot);
}

#ifdef    RKL_HAVE_CLEANUP

// rkl_cleanup_cacheSpinLockStatus takes advantage of GCC's 'cleanup' variable attribute.  When an 'auto' variable with the 'cleanup' attribute goes out of scope,
// GCC arranges to have the designated function called.  In this case, we make sure that if rkl_cacheSpinLock was locked that it was also unlocked.
// If rkl_cacheSpinLock was locked, but the cacheSpinLockStatus unlocked flag was not set, we force cacheSpinLock unlocked with a call to OSSpinLockUnlock.
// This is not a panacea for preventing mutex usage errors.  Old style ObjC exceptions will bypass the cleanup call, but newer C++ style ObjC exceptions should cause the cleanup function to be called during the stack unwind.

// We do not depend on this cleanup function being called.  It is used only as an extra safety net.  It is probably a bug in RegexKitLite if it is ever invoked and forced to take some kind of protective action.

volatile NSUInteger rkl_debugCacheSpinLockCount = 0UL;

void        rkl_debugCacheSpinLock          (void)                                        RKL_ATTRIBUTES(used, noinline, visibility("default"));
static void rkl_cleanup_cacheSpinLockStatus (volatile NSUInteger *cacheSpinLockStatusPtr) RKL_ATTRIBUTES(used);

void rkl_debugCacheSpinLock(void) {
  rkl_debugCacheSpinLockCount++; // This is here primarily to prevent the optimizer from optimizing away the function.
}

static void rkl_cleanup_cacheSpinLockStatus(volatile NSUInteger *cacheSpinLockStatusPtr) {
  static NSUInteger didPrintForcedUnlockWarning = 0UL, didPrintNotLockedWarning = 0UL;
  NSUInteger        cacheSpinLockStatus         = *cacheSpinLockStatusPtr;
  
  if(RKL_EXPECTED((cacheSpinLockStatus & RKLUnlockedCacheSpinLock) == 0UL, 0L) && RKL_EXPECTED((cacheSpinLockStatus & RKLLockedCacheSpinLock) != 0UL, 1L)) {
    if(cacheSpinLock != 0) {
      if(didPrintForcedUnlockWarning == 0UL) { didPrintForcedUnlockWarning = 1UL; NSLog(@"[RegexKitLite] Unusual condition detected: Recorded that cacheSpinLock was locked, but for some reason it was not unlocked.  Forcibly unlocking cacheSpinLock. Set a breakpoint at rkl_debugCacheSpinLock to debug. This warning is only printed once."); }
      rkl_debugCacheSpinLock(); // Since this is an unusual condition, offer an attempt to catch it before we unlock.
      OSSpinLockUnlock(&cacheSpinLock);
    } else {
      if(didPrintNotLockedWarning    == 0UL) { didPrintNotLockedWarning    = 1UL; NSLog(@"[RegexKitLite] Unusual condition detected: Recorded that cacheSpinLock was locked, but for some reason it was not unlocked, yet cacheSpinLock is currently not locked? Set a breakpoint at rkl_debugCacheSpinLock to debug. This warning is only printed once."); }
      rkl_debugCacheSpinLock();
    }
  }
}

#endif // RKL_HAVE_CLEANUP

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  ----------

static id rkl_performRegexOp(id self, SEL _cmd, RKLRegexOp regexOp, NSString *regexString, RKLRegexOptions options, NSInteger capture, id matchString, NSRange *matchRange, NSString *replacementString, NSError **error, void *result) {
  volatile NSUInteger RKL_CLEANUP(rkl_cleanup_cacheSpinLockStatus) cacheSpinLockStatus = 0UL;
  
  NSUInteger replaceMutable = 0UL;
  RKLRegexOp maskedRegexOp  = (regexOp & RKLMaskOp);
  
  if((error != NULL) && (*error != NULL))                            { *error = NULL; }
  
  if(RKL_EXPECTED(regexString == NULL, 0L))                          { RKL_RAISE_EXCEPTION(NSInvalidArgumentException, @"The regular expression argument is NULL."); }
  if(RKL_EXPECTED(matchString == NULL, 0L))                          { RKL_RAISE_EXCEPTION(NSInternalInconsistencyException, @"The match string argument is NULL."); }
  if((maskedRegexOp == RKLReplaceOp) && (replacementString == NULL)) { RKL_RAISE_EXCEPTION(NSInvalidArgumentException, @"The replacement string argument is NULL."); }
  
  id            resultObject    = NULL, exception = NULL;
  int32_t       status          = U_ZERO_ERROR;
  RKLCacheSlot *cacheSlot       = NULL;
  NSUInteger    stringU16Length = 0UL;
  NSRange       stackRanges[2048];
  RKLFindAll    findAll;
  
  
  // IMPORTANT!   Once we have obtained the lock, code MUST exit via 'goto exitNow;' to unlock the lock!  NO EXCEPTIONS!
  // ----------
  OSSpinLockLock(&cacheSpinLock); // Grab the lock and get cache entry.
  cacheSpinLockStatus |= RKLLockedCacheSpinLock;
  rkl_dtrace_incrementEventID();
  
  if(RKL_EXPECTED((cacheSlot = rkl_getCachedRegexSetToString(regexString, options, matchString, &stringU16Length, matchRange, error, &exception, &status)) == NULL, 0L)) { stringU16Length = (NSUInteger)CFStringGetLength((CFStringRef)matchString); }
  if(RKL_EXPECTED(matchRange->length == NSUIntegerMax, 1L)) { matchRange->length = stringU16Length; } // For convenience.
  if(RKL_EXPECTED(stringU16Length  < NSMaxRange(*matchRange), 0L) && RKL_EXPECTED(exception == NULL, 1L)) { exception = (id)RKL_EXCEPTION(NSRangeException, @"Range or index out of bounds");  goto exitNow; }
  if(RKL_EXPECTED(stringU16Length >= (NSUInteger)INT_MAX,     0L) && RKL_EXPECTED(exception == NULL, 1L)) { exception = (id)RKL_EXCEPTION(NSRangeException, @"String length exceeds INT_MAX"); goto exitNow; }
  if(((maskedRegexOp == RKLRangeOp) || (maskedRegexOp == RKLArrayOfStringsOp)) && RKL_EXPECTED(cacheSlot != NULL, 1L) && (RKL_EXPECTED(capture < 0L, 0L) || RKL_EXPECTED(capture > cacheSlot->captureCount, 0L)) && RKL_EXPECTED(exception == NULL, 1L)) { exception = (id)RKL_EXCEPTION(NSInvalidArgumentException, @"The capture argument is not valid."); goto exitNow; }
  if(RKL_EXPECTED(cacheSlot == NULL, 0L) || RKL_EXPECTED(status > U_ZERO_ERROR, 0L) || RKL_EXPECTED(exception != NULL, 0L)) { goto exitNow; }
  
  RKLCDelayedAssert((cacheSlot->icu_regex != NULL) && (cacheSlot->regexString != NULL) && (cacheSlot->captureCount >= 0L) && (cacheSlot->setToString != NULL) && (cacheSlot->setToLength >= 0L) && (cacheSlot->setToUniChar != NULL) && ((CFIndex)NSMaxRange(cacheSlot->setToRange) <= cacheSlot->setToLength), &exception, exitNow);
  
#ifndef NS_BLOCK_ASSERTIONS
  if(cacheSlot->setToNeedsConversion == 0U) { RKLCDelayedAssert((cacheSlot->setToUniChar == CFStringGetCharactersPtr(cacheSlot->setToString)), &exception, exitNow); }
  else {
    RKLBuffer *buffer = (cacheSlot->setToLength < (CFIndex)(RKL_FIXED_LENGTH)) ? &fixedBuffer : &dynamicBuffer;
    RKLCDelayedAssert((cacheSlot->setToHash == buffer->hash) && (cacheSlot->setToLength == buffer->length) && (cacheSlot->setToUniChar == buffer->uniChar), &exception, exitNow);
  }
#endif
  
  switch(maskedRegexOp) {
    case RKLRangeOp:
      if((rkl_search(cacheSlot, matchRange, 0UL, &exception, &status) == NO) || (RKL_EXPECTED(status > U_ZERO_ERROR, 0L))) { *(NSRange *)result = NSNotFoundRange; goto exitNow; }
      if(RKL_EXPECTED(capture == 0L, 1L)) { *(NSRange *)result = cacheSlot->lastMatchRange; } else { if(RKL_EXPECTED(rkl_getRangeForCapture(cacheSlot, &status, (int32_t)capture, (NSRange *)result) > U_ZERO_ERROR, 0L)) { goto exitNow; } }
      break;
      
    case RKLSplitOp:          // Fall-thru...
    case RKLArrayOfStringsOp: // Fall-thru...
    case RKLCapturesArrayOp:  // Fall-thru...
    case RKLArrayOfCapturesOp:
      findAll = rkl_makeFindAll(stackRanges, *matchRange, 2048L, (2048UL * sizeof(NSRange)), 0UL, (void **)&scratchBuffer[0], &scratchBuffer[1], &scratchBuffer[2], 0L, capture, ((maskedRegexOp == RKLCapturesArrayOp) ? 1L : NSIntegerMax));
      
      if(RKL_EXPECTED(rkl_findRanges(cacheSlot, regexOp, &findAll, &exception, &status) == NO, 1L)) {
        if(RKL_EXPECTED(findAll.found == 0L, 0L)) { resultObject = [NSArray array]; } else { resultObject = rkl_makeArray(cacheSlot, regexOp, &findAll, &exception); }
      }
      
      if(RKL_EXPECTED(scratchBuffer[0] != NULL, 0L)) { scratchBuffer[0] = rkl_free(&scratchBuffer[0]); }
      if(RKL_EXPECTED(scratchBuffer[1] != NULL, 0L)) { scratchBuffer[1] = rkl_free(&scratchBuffer[1]); }
      if(RKL_EXPECTED(scratchBuffer[2] != NULL, 0L)) { scratchBuffer[2] = rkl_free(&scratchBuffer[2]); }

      break;
      
    case RKLReplaceOp: resultObject = rkl_replaceString(cacheSlot, matchString, stringU16Length, replacementString, (NSUInteger)CFStringGetLength((CFStringRef)replacementString), (NSUInteger *)result, (replaceMutable = (((regexOp & RKLReplaceMutable) != 0) ? 1UL : 0UL)), &exception, &status); break;
    default:           exception    = RKLCAssertDictionary(@"Unknown regexOp code."); break;
  }
  
exitNow:
  OSSpinLockUnlock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLUnlockedCacheSpinLock;
  
  if(RKL_EXPECTED(status     > U_ZERO_ERROR, 0L) && RKL_EXPECTED(exception == NULL, 0L)) { exception = rkl_NSExceptionForRegex(regexString, options, NULL, status); } // If we had a problem, prepare an exception to be thrown.
  if(RKL_EXPECTED(exception != NULL,         0L))                                        { rkl_handleDelayedAssert(self, _cmd, exception);                          } // If there is an exception, throw it at this point.
  // If we're working on a mutable string and there were successful matches/replacements, then we still have work to do.
  // This is done outside the cache lock and with the objc replaceCharactersInRange:withString: method because Core Foundation
  // does not assert that the string we are attempting to update is actually a mutable string, whereas Foundation ensures
  // the object receiving the message is a mutable string and throws an exception if we're attempting to modify an immutable string.
  if(RKL_EXPECTED(replaceMutable == 1UL, 0L) && RKL_EXPECTED(*((NSUInteger *)result) > 0UL, 1L)) { NSCParameterAssert(resultObject != NULL); [matchString replaceCharactersInRange:*matchRange withString:resultObject]; }
  
  return(resultObject);
}

static void rkl_handleDelayedAssert(id self, SEL _cmd, id exception) {
  if(RKL_EXPECTED(exception != NULL, 0L)) {
    if([exception isKindOfClass:[NSException class]]) { [[NSException exceptionWithName:[exception name] reason:rkl_stringFromClassAndMethod(self, _cmd, [exception reason]) userInfo:[exception userInfo]] raise]; }
    else {
      id functionString = [exception objectForKey:@"function"], fileString = [exception objectForKey:@"file"], descriptionString = [exception objectForKey:@"description"], lineNumber = [exception objectForKey:@"line"];
      NSCParameterAssert((functionString != NULL) && (fileString != NULL) && (descriptionString != NULL) && (lineNumber != NULL));
      [[NSAssertionHandler currentHandler] handleFailureInFunction:functionString file:fileString lineNumber:(NSInteger)[lineNumber longValue] description:descriptionString];
    }
  }
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called from rkl_performRegexOp() or rkl_findRanges().
//  ----------

static NSUInteger rkl_search(RKLCacheSlot *cacheSlot, NSRange *searchRange, NSUInteger updateSearchRange, id *exception RKL_UNUSED_ASSERTION_ARG, int32_t *status) {
  NSUInteger foundMatch = 0UL, searchEqualsEndOfRange = (RKL_EXPECTED(NSEqualRanges(*searchRange, NSMakeRange(NSMaxRange(cacheSlot->setToRange), 0UL)) == YES, 0L) ? 1UL : 0UL);
    
  if((NSEqualRanges(*searchRange, cacheSlot->lastFindRange) == YES) || (searchEqualsEndOfRange == 1UL)) { foundMatch = (((cacheSlot->lastMatchRange.location == NSNotFound) || (searchEqualsEndOfRange == 1UL)) ? 0UL : 1UL);}
  else { // Only perform an expensive 'find' operation iff the current find range is different than the last find range.
    NSUInteger findLocation = (searchRange->location - cacheSlot->setToRange.location);
    RKLCDelayedAssert(((searchRange->location >= cacheSlot->setToRange.location)) && (NSRangeInsideRange(*searchRange, cacheSlot->setToRange) == YES) && (findLocation < INT_MAX) && (findLocation <= cacheSlot->setToRange.length), exception, exitNow);
    
    RKL_PREFETCH_UNICHAR(cacheSlot->setToUniChar, searchRange->location); // Spool up the CPU caches.
    
    // Using uregex_findNext can be a slight performance win.
    NSUInteger useFindNext = ((searchRange->location == (NSMaxRange(cacheSlot->lastMatchRange) + (((cacheSlot->lastMatchRange.length == 0UL) && (cacheSlot->lastMatchRange.location < NSMaxRange(cacheSlot->setToRange))) ? 1UL : 0UL))) ? 1UL : 0UL);

    cacheSlot->lastFindRange = *searchRange;
    if(RKL_EXPECTED(useFindNext == 0UL, 0L)) { if(RKL_EXPECTED((RKL_ICU_FUNCTION_APPEND(uregex_find)    (cacheSlot->icu_regex, (int32_t)findLocation, status) == NO), 0L) || RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { goto finishedFind; } }
    else {                                     if(RKL_EXPECTED((RKL_ICU_FUNCTION_APPEND(uregex_findNext)(cacheSlot->icu_regex,                        status) == NO), 0L) || RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { goto finishedFind; } }
    foundMatch = 1UL; 
    
    if(RKL_EXPECTED(rkl_getRangeForCapture(cacheSlot, status, 0, &cacheSlot->lastMatchRange) > U_ZERO_ERROR, 0L)) { goto finishedFind; }
    RKLCDelayedAssert(NSRangeInsideRange(cacheSlot->lastMatchRange, *searchRange) == YES, exception, exitNow);
  }
  
finishedFind:
  if(RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { foundMatch = 0UL; cacheSlot->lastFindRange = NSNotFoundRange; }
  
  if(foundMatch == 0UL) { cacheSlot->lastMatchRange = NSNotFoundRange; if(updateSearchRange == 1UL) { *searchRange = NSMakeRange(NSMaxRange(*searchRange), 0UL); } }
  else {
    RKLCDelayedAssert(NSRangeInsideRange(cacheSlot->lastMatchRange, *searchRange) == YES, exception, exitNow);
    if(updateSearchRange == 1UL) {
      NSUInteger nextLocation = (NSMaxRange(cacheSlot->lastMatchRange) + (((cacheSlot->lastMatchRange.length == 0UL) && (cacheSlot->lastMatchRange.location < NSMaxRange(cacheSlot->setToRange))) ? 1UL : 0UL)), locationDiff = nextLocation - searchRange->location;
      RKLCDelayedAssert((((locationDiff > 0UL) || ((locationDiff == 0UL) && (cacheSlot->lastMatchRange.location == NSMaxRange(cacheSlot->setToRange)))) && (locationDiff <= searchRange->length)), exception, exitNow);
      searchRange->location  = nextLocation;
      searchRange->length   -= locationDiff;
    }
  }
  
exitNow:
  return(foundMatch);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called from rkl_doFindOp().
//  ----------

static BOOL rkl_findRanges(RKLCacheSlot *cacheSlot, RKLRegexOp regexOp, RKLFindAll *findAll, id *exception, int32_t *status) {
  BOOL returnWithError = YES;
  RKLCDelayedAssert((((cacheSlot != NULL) && (cacheSlot->icu_regex != NULL) && (cacheSlot->setToUniChar != NULL) && (cacheSlot->captureCount >= 0L) && (cacheSlot->setToRange.location != NSNotFound)) && (status != NULL) && ((findAll != NULL) && (findAll->found == 0L) && ((findAll->capacity >= 0L) && (((findAll->capacity > 0L) || (findAll->size > 0UL)) ? ((findAll->ranges != NULL) && (findAll->capacity > 0L) && (findAll->size > 0UL)) : 1)) && (findAll->rangesScratchBuffer != NULL) && ((findAll->capture >= 0L) && (findAll->capture <= cacheSlot->captureCount)))), exception, exitNow);
  
  if(RKL_EXPECTED(cacheSlot->setToLength == 0L, 0L) || RKL_EXPECTED(cacheSlot->setToRange.length == 0UL, 0L)) { returnWithError = NO; goto exitNow; }
  
  NSInteger  captureCount  = cacheSlot->captureCount;
  RKLRegexOp maskedRegexOp = (regexOp & RKLMaskOp);
  NSUInteger lastLocation  = findAll->findInRange.location;
  NSRange    searchRange   = findAll->findInRange;
  
  for(findAll->found = 0L; (findAll->found < findAll->findUpTo) && ((findAll->found < findAll->capacity) || (findAll->found == 0L)); findAll->found++) {
    NSInteger loopCapture, shouldBreak = 0L;
    
    if(RKL_EXPECTED(findAll->found >= ((findAll->capacity - ((captureCount + 2L) * 4L)) - 4L), 0L)) { if(RKL_EXPECTED(rkl_growFindRanges(cacheSlot, lastLocation, findAll, exception) == 0UL, 0L)) { goto exitNow; } }
    
    RKLCDelayedAssert((searchRange.location != NSNotFound) && (NSRangeInsideRange(searchRange, cacheSlot->setToRange) == YES) && (NSRangeInsideRange(findAll->findInRange, cacheSlot->setToRange) == YES), exception, exitNow);
    
    // This fixes a 'bug' that is also present in ICU's uregex_split().  'Bug', in this case, means that the results of a split operation can differ from those that perl's split() creates for the same input.
    // "I|at|ice I eat rice" split using the regex "\b\s*" demonstrates the problem. ICU bug http://bugs.icu-project.org/trac/ticket/6826
    // ICU : "", "I", "|", "at", "|", "ice", "", "I", "", "eat", "", "rice" <- Results that RegexKitLite used to produce.
    // PERL:     "I", "|", "at", "|", "ice",     "I",     "eat",     "rice" <- Results that RegexKitLite now produces.
    do { if((rkl_search(cacheSlot, &searchRange, 1UL, exception, status) == NO) || (RKL_EXPECTED(*status > U_ZERO_ERROR, 0L))) { shouldBreak = 1L; } }
    while((maskedRegexOp == RKLSplitOp) && RKL_EXPECTED(shouldBreak == 0L, 1L) && RKL_EXPECTED(cacheSlot->lastMatchRange.length == 0UL, 0L) && RKL_EXPECTED((cacheSlot->lastMatchRange.location - lastLocation) == 0UL, 0L));
    if(RKL_EXPECTED(shouldBreak == 1L, 0L)) { break; }

    RKLCDelayedAssert((searchRange.location != NSNotFound) && (NSRangeInsideRange(searchRange, cacheSlot->setToRange) == YES) && (NSRangeInsideRange(findAll->findInRange, cacheSlot->setToRange) == YES) && (NSRangeInsideRange(searchRange, findAll->findInRange) == YES), exception, exitNow);
    RKLCDelayedAssert((NSRangeInsideRange(cacheSlot->lastFindRange, cacheSlot->setToRange) == YES) && (NSRangeInsideRange(cacheSlot->lastMatchRange, cacheSlot->setToRange) == YES) && (NSRangeInsideRange(cacheSlot->lastMatchRange, findAll->findInRange) == YES), exception, exitNow);
    RKLCDelayedAssert((findAll->ranges != NULL) && (findAll->found >= 0L) && (findAll->capacity >= 0L) && ((findAll->found + (captureCount + 3L) + 1L) < (findAll->capacity - 2L)), exception, exitNow);
    
    switch(maskedRegexOp) {
      case RKLArrayOfStringsOp:
        if(findAll->capture == 0L) { findAll->ranges[findAll->found] = cacheSlot->lastMatchRange; } else { if(RKL_EXPECTED(rkl_getRangeForCapture(cacheSlot, status, (int32_t)findAll->capture, &findAll->ranges[findAll->found]) > U_ZERO_ERROR, 0L)) { goto exitNow; } }
        break;
        
      case RKLSplitOp:         // Fall-thru...
      case RKLCapturesArrayOp: // Fall-thru...
      case RKLArrayOfCapturesOp:
        findAll->ranges[findAll->found] = ((maskedRegexOp == RKLSplitOp) ? NSMakeRange(lastLocation, cacheSlot->lastMatchRange.location - lastLocation) : cacheSlot->lastMatchRange);
        
        for(loopCapture = 1L; loopCapture <= captureCount; loopCapture++) {
          RKLCDelayedAssert((findAll->found >= 0L) && (findAll->found < (findAll->capacity - 2L)) && (loopCapture < INT_MAX), exception, exitNow);
          if(RKL_EXPECTED(rkl_getRangeForCapture(cacheSlot, status, (int32_t)loopCapture, &findAll->ranges[++findAll->found]) > U_ZERO_ERROR, 0L)) { goto exitNow; }
        }
        break;
        
      default: if(*exception != NULL) { *exception = RKLCAssertDictionary(@"Unknown regexOp."); } goto exitNow; break;
    }
    
    lastLocation = NSMaxRange(cacheSlot->lastMatchRange);
  }
  
  if(RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { goto exitNow; }
  
  RKLCDelayedAssert((findAll->ranges != NULL) && (findAll->found >= 0L) && (findAll->found < (findAll->capacity - 2L)), exception, exitNow);
  if((maskedRegexOp == RKLSplitOp) && (lastLocation != NSMaxRange(findAll->findInRange))) { findAll->ranges[findAll->found++] = NSMakeRange(lastLocation, NSMaxRange(findAll->findInRange) - lastLocation); }
    
  RKLCDelayedAssert((findAll->ranges != NULL) && (findAll->found >= 0L) && (findAll->found < (findAll->capacity - 2L)), exception, exitNow);
  returnWithError = NO;
  
exitNow:
  return(returnWithError);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called from rkl_findRanges().
//  ----------

static NSUInteger rkl_growFindRanges(RKLCacheSlot *cacheSlot, NSUInteger lastLocation, RKLFindAll *findAll, id *exception RKL_UNUSED_ASSERTION_ARG) {
  NSUInteger didGrowRanges = 0UL;
  RKLCDelayedAssert((((cacheSlot != NULL) && (cacheSlot->captureCount >= 0L)) && ((findAll != NULL) && (findAll->capacity >= 0L) && (findAll->rangesScratchBuffer != NULL) && (findAll->found >= 0L) && (((findAll->capacity > 0L) || (findAll->size > 0UL) || (findAll->ranges != NULL)) ? ((findAll->capacity > 0L) && (findAll->size > 0UL) && (findAll->ranges != NULL) && (((size_t)findAll->capacity * sizeof(NSRange)) == findAll->size)) : 1))), exception, exitNow);
  
  // Attempt to guesstimate the required capacity based on: the total length needed to search / (length we've searched so far / ranges found so far).
  NSInteger newCapacity = (findAll->capacity + (findAll->capacity / 2L)), estimate = (NSInteger)((float)cacheSlot->setToLength / (((float)lastLocation + 1.0f) / ((float)findAll->found + 1.0f)));
  newCapacity = (((newCapacity + ((estimate > newCapacity) ? estimate : newCapacity)) / 2L) + ((cacheSlot->captureCount + 2L) * 4L) + 4L);
  
  NSUInteger  needToCopy = ((findAll->ranges != NULL) && (*findAll->rangesScratchBuffer != findAll->ranges)) ? 1UL : 0UL; // If findAll->ranges is set to a stack allocation then we need to manually copy the data from the stack to the new heap allocation.
  size_t      newSize    = ((size_t)newCapacity * sizeof(NSRange));
  NSRange    *newRanges  = NULL;
  
  if(RKL_EXPECTED((newRanges = (NSRange *)rkl_realloc((RKL_STRONG_REF void **)findAll->rangesScratchBuffer, newSize, 0UL)) == NULL, 0L)) { findAll->capacity = 0L; findAll->size = 0UL; findAll->ranges = NULL; *findAll->rangesScratchBuffer = rkl_free((RKL_STRONG_REF void **)findAll->rangesScratchBuffer); goto exitNow; } else { didGrowRanges = 1UL; }
  if(needToCopy == 1UL) { memcpy(newRanges, findAll->ranges, findAll->size); } // If necessary, copy the existing data to the new heap allocation.
  
  findAll->capacity = newCapacity;
  findAll->size     = newSize;
  findAll->ranges   = newRanges;
  
exitNow:
  return(didGrowRanges);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called from rkl_doFindOp().
//  ----------

static NSArray *rkl_makeArray(RKLCacheSlot *cacheSlot, RKLRegexOp regexOp, RKLFindAll *findAll, id *exception RKL_UNUSED_ASSERTION_ARG) {
  NSUInteger  createdStringsCount = 0UL,   createdArraysCount = 0UL,  transferedStringsCount = 0UL;
  id         *matchedStrings      = NULL, *subcaptureArrays   = NULL, emptyString            = @"";
  NSArray    *resultArray         = NULL;
  
  RKLCDelayedAssert((cacheSlot != NULL) && ((findAll != NULL) && (findAll->found >= 0L) && (findAll->stringsScratchBuffer != NULL) && (findAll->arraysScratchBuffer != NULL)), exception, exitNow);
  
  size_t      matchedStringsSize = ((size_t)findAll->found * sizeof(id));
  CFStringRef setToString        = cacheSlot->setToString;
  
  if((findAll->stackUsed + matchedStringsSize) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((matchedStrings = (id *)alloca(matchedStringsSize))                                                                   == NULL, 0L)) { goto exitNow; } findAll->stackUsed += matchedStringsSize; }
  else {                                                                      if(RKL_EXPECTED((matchedStrings = (id *)rkl_realloc(findAll->stringsScratchBuffer, matchedStringsSize, (NSUInteger)RKLScannedOption)) == NULL, 0L)) { goto exitNow; } }
  
  { // This sub-block (and its local variables) is here for the benefit of the optimizer.
    NSUInteger     found             = (NSUInteger)findAll->found;
    const NSRange *rangePtr          = findAll->ranges;
    id            *matchedStringsPtr = matchedStrings;
    
    for(createdStringsCount = 0UL; createdStringsCount < found; createdStringsCount++) {
      NSRange range = *rangePtr++;
      if(RKL_EXPECTED(((*matchedStringsPtr++ = RKL_EXPECTED(range.length == 0UL, 0L) ? emptyString : rkl_CreateStringWithSubstring((id)setToString, range)) == NULL), 0L)) { goto exitNow; }
    }
  }
  
  NSUInteger  arrayCount   = createdStringsCount;
  id         *arrayObjects = matchedStrings;
  
  if((regexOp & RKLSubcapturesArray) != 0UL) {
    RKLCDelayedAssert(((createdStringsCount % ((NSUInteger)cacheSlot->captureCount + 1UL)) == 0UL) && (createdArraysCount == 0UL), exception, exitNow);
    
    NSUInteger captureCount          = ((NSUInteger)cacheSlot->captureCount + 1UL);
    NSUInteger subcaptureArraysCount = (createdStringsCount / captureCount);
    size_t     subcaptureArraysSize  = ((size_t)subcaptureArraysCount * sizeof(id));
    
    if((findAll->stackUsed + subcaptureArraysSize) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((subcaptureArrays = (id *)alloca(subcaptureArraysSize))                                                                  == NULL, 0L)) { goto exitNow; } findAll->stackUsed += subcaptureArraysSize; }
    else {                                                                        if(RKL_EXPECTED((subcaptureArrays = (id *)rkl_realloc(findAll->arraysScratchBuffer, subcaptureArraysSize, (NSUInteger)RKLScannedOption)) == NULL, 0L)) { goto exitNow; } }
    
    { // This sub-block (and its local variables) is here for the benefit of the optimizer.
      id *subcaptureArraysPtr = subcaptureArrays;
      id *matchedStringsPtr   = matchedStrings;
      
      for(createdArraysCount = 0UL; createdArraysCount < subcaptureArraysCount; createdArraysCount++) {
        if(RKL_EXPECTED((*subcaptureArraysPtr++ = rkl_CreateArrayWithObjects((void **)matchedStringsPtr, captureCount)) == NULL, 0L)) { goto exitNow; }
        matchedStringsPtr      += captureCount;
        transferedStringsCount += captureCount;
      }
    }
    
    RKLCDelayedAssert((transferedStringsCount == createdStringsCount), exception, exitNow);
    arrayCount   = createdArraysCount;
    arrayObjects = subcaptureArrays;
  }
  
  RKLCDelayedAssert((arrayObjects != NULL), exception, exitNow);
  resultArray = rkl_CreateAutoreleasedArray((void **)arrayObjects, (NSUInteger)arrayCount);
  
exitNow:
  if(RKL_EXPECTED(resultArray == NULL, 0L) && (rkl_collectingEnabled() == NO)) { // If we did not create an array then we need to make sure that we release any objects we created.
    NSUInteger x;
    if(matchedStrings   != NULL) { for(x = transferedStringsCount; x < createdStringsCount; x++) { if((matchedStrings[x]  != NULL) && (matchedStrings[x] != emptyString)) { matchedStrings[x]   = rkl_ReleaseObject(matchedStrings[x]);   } } }
    if(subcaptureArrays != NULL) { for(x = 0UL;                    x < createdArraysCount;  x++) { if(subcaptureArrays[x] != NULL)                                        { subcaptureArrays[x] = rkl_ReleaseObject(subcaptureArrays[x]); } } }
  }
  
  return(resultArray);
}

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called from rkl_performRegexOp().
//  ----------

static NSString *rkl_replaceString(RKLCacheSlot *cacheSlot, id searchString, NSUInteger searchU16Length, NSString *replacementString, NSUInteger replacementU16Length, NSUInteger *replacedCountPtr, NSUInteger replaceMutable, id *exception, int32_t *status) {
  uint64_t       searchU16Length64  = (uint64_t)searchU16Length, replacementU16Length64 = (uint64_t)replacementU16Length;
  int32_t        resultU16Length    = 0, tempUniCharBufferU16Capacity = 0;
  UniChar       *tempUniCharBuffer  = NULL;
  const UniChar *replacementUniChar = NULL;
  id             resultObject       = NULL;
  NSUInteger     replacedCount      = 0UL;
  
  if((RKL_EXPECTED(replacementU16Length64 >= (uint64_t)INT_MAX, 0L) || RKL_EXPECTED(((searchU16Length64 / 2ULL) + (replacementU16Length64 * 2ULL)) >= (uint64_t)INT_MAX, 0L))) { *exception = [NSException exceptionWithName:NSRangeException reason:@"Replacement string length exceeds INT_MAX" userInfo:NULL]; goto exitNow; }

  RKLCDelayedAssert((searchU16Length64 < (uint64_t)INT_MAX) && (replacementU16Length64 < (uint64_t)INT_MAX) && (((searchU16Length64 / 2ULL) + (replacementU16Length64 * 2ULL)) < (uint64_t)INT_MAX), exception, exitNow);
  
  // Zero order approximation of the buffer sizes for holding the replaced string or split strings and split strings pointer offsets.  As UTF16 code units.
  tempUniCharBufferU16Capacity = (int32_t)(16UL + (searchU16Length + (searchU16Length / 2UL)) + (replacementU16Length * 2UL));
  
  // Buffer sizes converted from native units to bytes.
  size_t stackSize = 0UL, replacementSize = ((size_t)replacementU16Length * sizeof(UniChar)), tempUniCharBufferSize = ((size_t)tempUniCharBufferU16Capacity * sizeof(UniChar));
  
  // For the various buffers we require, we first try to allocate from the stack if we're not over the RKL_STACK_LIMIT.  If we are, switch to using the heap for the buffer.
  if((stackSize + tempUniCharBufferSize) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((tempUniCharBuffer = (UniChar *)alloca(tempUniCharBufferSize))                              == NULL, 0L)) { goto exitNow; } stackSize += tempUniCharBufferSize; }
  else                                                                { if(RKL_EXPECTED((tempUniCharBuffer = (UniChar *)rkl_realloc(&scratchBuffer[0], tempUniCharBufferSize, 0UL)) == NULL, 0L)) { goto exitNow; } }
  
  // Try to get the pointer to the replacement strings UTF16 data.  If we can't, allocate some buffer space, then covert to UTF16.
  if((replacementUniChar = CFStringGetCharactersPtr((CFStringRef)replacementString)) == NULL) {
    UniChar *uniCharBuffer = NULL;
    if((stackSize + replacementSize) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((uniCharBuffer = (UniChar *)alloca(replacementSize))                              == NULL, 0L)) { goto exitNow; } stackSize += replacementSize; } 
    else                                                          { if(RKL_EXPECTED((uniCharBuffer = (UniChar *)rkl_realloc(&scratchBuffer[1], replacementSize, 0UL)) == NULL, 0L)) { goto exitNow; } }
    CFStringGetCharacters((CFStringRef)replacementString, CFMakeRange(0L, replacementU16Length), uniCharBuffer); // Convert to a UTF16 string.
    replacementUniChar = uniCharBuffer;
  }
  
  resultU16Length = rkl_replaceAll(cacheSlot, replacementUniChar, (int32_t)replacementU16Length, tempUniCharBuffer, tempUniCharBufferU16Capacity, &replacedCount, exception, status);
  
  if(RKL_EXPECTED(*status == U_BUFFER_OVERFLOW_ERROR, 0L)) { // Our buffer guess(es) were too small.  Resize the buffers and try again.
    tempUniCharBufferSize = ((size_t)(tempUniCharBufferU16Capacity = resultU16Length + 4) * sizeof(UniChar));
    if((stackSize + tempUniCharBufferSize) < (size_t)(RKL_STACK_LIMIT)) { if(RKL_EXPECTED((tempUniCharBuffer = (UniChar *)alloca(tempUniCharBufferSize))                              == NULL, 0L)) { goto exitNow; } stackSize += tempUniCharBufferSize; }
    else                                                                { if(RKL_EXPECTED((tempUniCharBuffer = (UniChar *)rkl_realloc(&scratchBuffer[0], tempUniCharBufferSize, 0UL)) == NULL, 0L)) { goto exitNow; } }
    
    *status         = U_ZERO_ERROR; // Make sure the status var is cleared and try again.
    resultU16Length = rkl_replaceAll(cacheSlot, replacementUniChar, (int32_t)replacementU16Length, tempUniCharBuffer, tempUniCharBufferU16Capacity, &replacedCount, exception, status);
  }
  
  if(RKL_EXPECTED(*status > U_ZERO_ERROR, 0L)) { goto exitNow; } // Something went wrong.
  
  if(resultU16Length == 0) { resultObject = @""; } // Optimize the case where the replaced text length == 0 with a @"" string.
  else if(((NSUInteger)resultU16Length == searchU16Length) && (replacedCount == 0UL)) { // Optimize the case where the replacement == original by creating a copy. Very fast if self is immutable.
    if(replaceMutable == 0UL) { resultObject = rkl_CFAutorelease(CFStringCreateCopy(NULL, (CFStringRef)searchString)); } // .. but only if this is not replacing a mutable self.
  } else { resultObject = rkl_CFAutorelease(CFStringCreateWithCharacters(NULL, tempUniCharBuffer, (CFIndex)resultU16Length)); } // otherwise, create a new string.
  
  // If replaceMutable == 1UL, we don't do the replacement here.  We wait until after we return and unlock the cache lock.
  // This is because we may be trying to mutate an immutable string object.
  if((replacedCount > 0UL) && (replaceMutable == 1UL)) { // We're working on a mutable string and there were successfull matches with replaced text, so there's work to do.
    rkl_clearBuffer((cacheSlot->setToLength < (CFIndex)(RKL_FIXED_LENGTH)) ? &fixedBuffer : &dynamicBuffer, 0UL);
    rkl_clearCacheSlotSetTo(cacheSlot); // Flush any cached information about this string since it will mutate.
  }
  
exitNow:
  if(scratchBuffer[0] != NULL) { scratchBuffer[0] = rkl_free(&scratchBuffer[0]); }
  if(scratchBuffer[1] != NULL) { scratchBuffer[1] = rkl_free(&scratchBuffer[1]); }
  if(replacedCountPtr != NULL) { *replacedCountPtr = replacedCount; }
  return(resultObject);
}

//  IMPORTANT!   Should only be called from rkl_replaceString().
//  ----------
//  Modified version of the ICU libraries uregex_replaceAll() that keeps count of the number of replacements made.

static int32_t rkl_replaceAll(RKLCacheSlot *cacheSlot, const UniChar *replacementUniChar, int32_t replacementU16Length, UniChar *replacedUniChar, int32_t replacedU16Capacity, NSUInteger *replacedCount, id *exception RKL_UNUSED_ASSERTION_ARG, int32_t *status) {
  NSUInteger replaced  = 0UL, bufferOverflowed = 0UL;
  int32_t    u16Length = 0;
  RKLCDelayedAssert((cacheSlot != NULL) && (replacementUniChar != NULL) && (replacedUniChar != NULL) && (status != NULL) && (replacementU16Length >= 0) && (replacedU16Capacity >= 0), exception, exitNow);

  cacheSlot->lastFindRange = cacheSlot->lastMatchRange = NSNotFoundRange; // Clear the cached find information for this regex so a subsequent find works correctly.
  RKL_ICU_FUNCTION_APPEND(uregex_reset)(cacheSlot->icu_regex, 0, status);
  
  // Work around for ICU uregex_reset() bug, see http://bugs.icu-project.org/trac/ticket/6545
  // http://sourceforge.net/tracker/index.php?func=detail&aid=2105213&group_id=204582&atid=990188
  if(RKL_EXPECTED(cacheSlot->setToRange.length == 0L, 0L) && (*status == U_INDEX_OUTOFBOUNDS_ERROR)) { *status = U_ZERO_ERROR; }
  
  // This loop originally came from ICU source/i18n/uregex.cpp, uregex_replaceAll.
  // There is a bug in that code which causes the size of the buffer required for the replaced text to not be calculated correctly.
  // This contains a work around using the variable bufferOverflowed.
  // ICU bug: http://bugs.icu-project.org/trac/ticket/6656
  // http://sourceforge.net/tracker/index.php?func=detail&aid=2408447&group_id=204582&atid=990188
  while(RKL_ICU_FUNCTION_APPEND(uregex_findNext)(cacheSlot->icu_regex, status)) {
    replaced++;
    u16Length += RKL_ICU_FUNCTION_APPEND(uregex_appendReplacement)(cacheSlot->icu_regex, replacementUniChar, replacementU16Length, &replacedUniChar, &replacedU16Capacity, status);
    if(RKL_EXPECTED(*status == U_BUFFER_OVERFLOW_ERROR, 0L)) { bufferOverflowed = 1UL; *status = U_ZERO_ERROR; }
  }
  if(RKL_EXPECTED(*status == U_BUFFER_OVERFLOW_ERROR, 0L)) { bufferOverflowed = 1UL; *status = U_ZERO_ERROR; }
  u16Length += RKL_ICU_FUNCTION_APPEND(uregex_appendTail)(cacheSlot->icu_regex, &replacedUniChar, &replacedU16Capacity, status);
  
  if(RKL_EXPECTED(*status == U_ZERO_ERROR, 1L) && RKL_EXPECTED(bufferOverflowed == 1UL, 0L)) { *status = U_BUFFER_OVERFLOW_ERROR; } 
  if(replacedCount != NULL) { *replacedCount = replaced; }
exitNow:
  return(u16Length);
}

static NSUInteger rkl_isRegexValid(id self, SEL _cmd, NSString *regex, RKLRegexOptions options, NSInteger *captureCountPtr, NSError **error) {
  volatile NSUInteger RKL_CLEANUP(rkl_cleanup_cacheSpinLockStatus) cacheSpinLockStatus = 0UL;
  
  RKLCacheSlot *cacheSlot    = NULL;
  NSUInteger    gotCacheSlot = 0UL;
  NSInteger     captureCount = -1L;
  id            exception    = NULL;
  
  if((error != NULL) && (*error != NULL)) { *error = NULL; }
  if(regex == NULL) { RKL_RAISE_EXCEPTION(NSInvalidArgumentException, @"The regular expression argument is NULL."); }
  
  OSSpinLockLock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLLockedCacheSpinLock;
  rkl_dtrace_incrementEventID();
  if((cacheSlot = rkl_getCachedRegex(regex, options, error, &exception)) != NULL) { gotCacheSlot = 1UL; captureCount = cacheSlot->captureCount; }
  cacheSlot = NULL;
  OSSpinLockUnlock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLUnlockedCacheSpinLock;
  
  if(captureCountPtr != NULL) { *captureCountPtr = captureCount; }
  if(RKL_EXPECTED(exception != NULL, 0L)) { rkl_handleDelayedAssert(self, _cmd, exception); }
  return(gotCacheSlot);
}

static void rkl_clearStringCache(void) {
  NSCParameterAssert(cacheSpinLock != 0);
  lastCacheSlot = NULL;
  NSUInteger x = 0UL;
  for(x = 0UL; x < (NSUInteger)(RKL_SCRATCH_BUFFERS); x++) { if(scratchBuffer[x] != NULL) { scratchBuffer[x] = rkl_free(&scratchBuffer[x]); } }
  for(x = 0UL; x < (NSUInteger)(RKL_CACHE_SIZE);      x++) { rkl_clearCacheSlotRegex(&rkl_cacheSlots[x]); }
  rkl_clearBuffer(&fixedBuffer,   0UL);
  rkl_clearBuffer(&dynamicBuffer, 1UL);
}

static void rkl_clearBuffer(RKLBuffer *buffer, NSUInteger freeDynamicBuffer) {
  if(buffer == NULL) { return; }
  if((freeDynamicBuffer == 1UL) && (buffer->uniChar != NULL) && (buffer == &dynamicBuffer)) { RKL_STRONG_REF void *p = (RKL_STRONG_REF void *)dynamicBuffer.uniChar; dynamicBuffer.uniChar = (RKL_STRONG_REF UniChar *)rkl_free(&p); }
  if(buffer->string != NULL)                                                                { CFRelease((CFTypeRef)buffer->string); buffer->string = NULL; }
  buffer->length = 0L;
  buffer->hash   = 0UL;
}

static void rkl_clearCacheSlotRegex(RKLCacheSlot *cacheSlot) {
  if(cacheSlot              == NULL) { return; }
  if(cacheSlot->setToString != NULL) { rkl_clearCacheSlotSetTo(cacheSlot); }
  if(cacheSlot->icu_regex   != NULL) { RKL_ICU_FUNCTION_APPEND(uregex_close)(cacheSlot->icu_regex); cacheSlot->icu_regex   = NULL; cacheSlot->captureCount = -1L; }
  if(cacheSlot->regexString != NULL) { CFRelease((CFTypeRef)cacheSlot->regexString);                cacheSlot->regexString = NULL; cacheSlot->options      =  0U; }
}

static void rkl_clearCacheSlotSetTo(RKLCacheSlot *cacheSlot) {
  if(cacheSlot              == NULL) { return; }
  if(cacheSlot->icu_regex   != NULL) { int32_t status = 0; RKL_ICU_FUNCTION_APPEND(uregex_setText)(cacheSlot->icu_regex, &emptyUniCharString[0], 0, &status); }
  if(cacheSlot->setToString != NULL) { CFRelease((CFTypeRef)cacheSlot->setToString); cacheSlot->setToString = NULL; }
  cacheSlot->lastFindRange    = cacheSlot->lastMatchRange       = cacheSlot->setToRange = NSNotFoundRange;
  cacheSlot->setToIsImmutable = cacheSlot->setToNeedsConversion = 0U;
  cacheSlot->setToUniChar     = NULL;
  cacheSlot->setToHash        = 0UL;
  cacheSlot->setToLength      = 0L;
}

// Helps to keep things tidy.
#define addKeyAndObject(objs, keys, i, k, o) ({id _o=(o), _k=(k); if((_o != NULL) && (_k != NULL)) { objs[i] = _o; keys[i] = _k; i++; } })

static NSDictionary *rkl_userInfoDictionary(NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status, ...) {
  va_list varArgsList;
  va_start(varArgsList, status);
  if(regexString == NULL) { va_end(varArgsList); return(NULL); }
  
  id objects[64], keys[64];
  NSUInteger count = 0UL;
  
  NSString *errorNameString = [NSString stringWithUTF8String:RKL_ICU_FUNCTION_APPEND(u_errorName)(status)];
  
  addKeyAndObject(objects, keys, count, RKLICURegexRegexErrorKey,        regexString);
  addKeyAndObject(objects, keys, count, RKLICURegexRegexOptionsErrorKey, [NSNumber numberWithUnsignedInt:options]);
  addKeyAndObject(objects, keys, count, RKLICURegexErrorCodeErrorKey,    [NSNumber numberWithInt:status]);
  addKeyAndObject(objects, keys, count, RKLICURegexErrorNameErrorKey,    errorNameString);
  
  if((parseError != NULL) && (parseError->line != -1)) {
    NSString *preContextString  = [NSString stringWithCharacters:&parseError->preContext[0]  length:(NSUInteger)RKL_ICU_FUNCTION_APPEND(u_strlen)(&parseError->preContext[0])];
    NSString *postContextString = [NSString stringWithCharacters:&parseError->postContext[0] length:(NSUInteger)RKL_ICU_FUNCTION_APPEND(u_strlen)(&parseError->postContext[0])];
    
    addKeyAndObject(objects, keys, count, RKLICURegexLineErrorKey,        [NSNumber numberWithInt:parseError->line]);
    addKeyAndObject(objects, keys, count, RKLICURegexOffsetErrorKey,      [NSNumber numberWithInt:parseError->offset]);
    addKeyAndObject(objects, keys, count, RKLICURegexPreContextErrorKey,  preContextString);
    addKeyAndObject(objects, keys, count, RKLICURegexPostContextErrorKey, postContextString);
    addKeyAndObject(objects, keys, count, @"NSLocalizedFailureReason",    ([NSString stringWithFormat:@"The error %@ occurred at line %d, column %d: %@<<HERE>>%@", errorNameString, parseError->line, parseError->offset, preContextString, postContextString]));
  } else {
    addKeyAndObject(objects, keys, count, @"NSLocalizedFailureReason",    ([NSString stringWithFormat:@"The error %@ occurred.", errorNameString]));
  }
  
  while(count < 62UL) { id obj = va_arg(varArgsList, id), key = va_arg(varArgsList, id); if((obj != NULL) && (key != NULL)) { addKeyAndObject(objects, keys, count, key, obj); } else { break; } }
  va_end(varArgsList);
  
  return([NSDictionary dictionaryWithObjects:&objects[0] forKeys:&keys[0] count:count]);
}

static NSError *rkl_NSErrorForRegex(NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status) {
  return([NSError errorWithDomain:RKLICURegexErrorDomain code:(NSInteger)status userInfo:rkl_userInfoDictionary(regexString, options, parseError, status, @"There was an error compiling the regular expression.", @"NSLocalizedDescription", NULL)]);
}

static NSException *rkl_NSExceptionForRegex(NSString *regexString, RKLRegexOptions options, const UParseError *parseError, int32_t status) {
  return([NSException exceptionWithName:RKLICURegexException reason:[NSString stringWithFormat:@"ICU regular expression error #%d, %s", status, RKL_ICU_FUNCTION_APPEND(u_errorName)(status)] userInfo:rkl_userInfoDictionary(regexString, options, parseError, status, NULL)]);
}

static NSDictionary *rkl_makeAssertDictionary(const char *function, const char *file, int line, NSString *format, ...) {
  va_list varArgsList;
  va_start(varArgsList, format);
  NSString *formatString   = [[[NSString alloc] initWithFormat:format arguments:varArgsList] autorelease];
  va_end(varArgsList);
  NSString *functionString = [NSString stringWithUTF8String:function], *fileString = [NSString stringWithUTF8String:file];
  return([NSDictionary dictionaryWithObjectsAndKeys:formatString, @"description", functionString, @"function", fileString, @"file", [NSNumber numberWithInt:line], @"line", NSInternalInconsistencyException, @"exceptionName", NULL]);
}

static NSString *rkl_stringFromClassAndMethod(id object, SEL selector, NSString *format, ...) {
  va_list varArgsList;
  va_start(varArgsList, format);
  NSString *formatString = [[[NSString alloc] initWithFormat:format arguments:varArgsList] autorelease];
  va_end(varArgsList);
  Class     objectsClass = [object class];
  return([NSString stringWithFormat:@"*** %c[%@ %@]: %@", (object == objectsClass) ? '+' : '-', NSStringFromClass(objectsClass), NSStringFromSelector(selector), formatString]);
}

#pragma mark -
#pragma mark Objective-C Public Interface
#pragma mark -

@implementation NSString (RegexKitLiteAdditions)

#pragma mark +clearStringCache

+ (void)RKL_METHOD_PREPEND(clearStringCache)
{
  volatile NSUInteger RKL_CLEANUP(rkl_cleanup_cacheSpinLockStatus) cacheSpinLockStatus = 0UL;
  OSSpinLockLock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLLockedCacheSpinLock;
  rkl_clearStringCache();
  OSSpinLockUnlock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLUnlockedCacheSpinLock;
}

#pragma mark +captureCountForRegex:

+ (NSInteger)RKL_METHOD_PREPEND(captureCountForRegex):(NSString *)regex
{
  NSInteger captureCount = -1L;
  rkl_isRegexValid(self, _cmd, regex, RKLNoOptions, &captureCount, NULL);
  return(captureCount);
}

+ (NSInteger)RKL_METHOD_PREPEND(captureCountForRegex):(NSString *)regex options:(RKLRegexOptions)options error:(NSError **)error
{
  NSInteger captureCount = -1L;
  rkl_isRegexValid(self, _cmd, regex, options,      &captureCount, error);
  return(captureCount);
}

#pragma mark -captureCount:

- (NSInteger)RKL_METHOD_PREPEND(captureCount)
{
  NSInteger captureCount = -1L;
  rkl_isRegexValid(self, _cmd, self, RKLNoOptions, &captureCount, NULL);
  return(captureCount);
}

- (NSInteger)RKL_METHOD_PREPEND(captureCountWithOptions):(RKLRegexOptions)options error:(NSError **)error
{
  NSInteger captureCount = -1L;
  rkl_isRegexValid(self, _cmd, self, options,      &captureCount, error);
  return(captureCount);
}

#pragma mark -componentsSeparatedByRegex:

- (NSArray *)RKL_METHOD_PREPEND(componentsSeparatedByRegex):(NSString *)regex
{
  NSRange range = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLSplitOp, regex, RKLNoOptions, 0L, self, &range, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(componentsSeparatedByRegex):(NSString *)regex range:(NSRange)range
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLSplitOp, regex, RKLNoOptions, 0L, self, &range, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(componentsSeparatedByRegex):(NSString *)regex options:(RKLRegexOptions)options range:(NSRange)range error:(NSError **)error
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLSplitOp, regex, options,      0L, self, &range, NULL, error, NULL));
}

#pragma mark -isMatchedByRegex:

- (BOOL)RKL_METHOD_PREPEND(isMatchedByRegex):(NSString *)regex
{
  NSRange result = NSNotFoundRange, range = NSMaxiumRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions, 0L, self, &range, NULL, NULL,  &result);
  return((result.location == NSNotFound) ? NO : YES);
}

- (BOOL)RKL_METHOD_PREPEND(isMatchedByRegex):(NSString *)regex inRange:(NSRange)range
{
  NSRange result = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions, 0L, self, &range, NULL, NULL,  &result);
  return((result.location == NSNotFound) ? NO : YES);
}

- (BOOL)RKL_METHOD_PREPEND(isMatchedByRegex):(NSString *)regex options:(RKLRegexOptions)options inRange:(NSRange)range error:(NSError **)error
{
  NSRange result = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, options,      0L, self, &range, NULL, error, &result);
  return((result.location == NSNotFound) ? NO : YES);
}

#pragma mark -isRegexValid

- (BOOL)RKL_METHOD_PREPEND(isRegexValid)
{
  return(rkl_isRegexValid(self, _cmd, self, RKLNoOptions, NULL, NULL)  == 1UL ? YES : NO);
}

- (BOOL)RKL_METHOD_PREPEND(isRegexValidWithOptions):(RKLRegexOptions)options error:(NSError **)error
{
  return(rkl_isRegexValid(self, _cmd, self, options,      NULL, error) == 1UL ? YES : NO);
}

#pragma mark -flushCachedRegexData

- (void)RKL_METHOD_PREPEND(flushCachedRegexData)
{
  volatile NSUInteger RKL_CLEANUP(rkl_cleanup_cacheSpinLockStatus) cacheSpinLockStatus = 0UL;

  CFIndex    selfLength = CFStringGetLength((CFStringRef)self);
  CFHashCode selfHash   = CFHash((CFTypeRef)self);
  
  OSSpinLockLock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLLockedCacheSpinLock;
  rkl_dtrace_incrementEventID();

  NSUInteger slot;
  for(slot = 0UL; slot < (NSUInteger)(RKL_CACHE_SIZE); slot++) {
    RKLCacheSlot *cacheSlot = &rkl_cacheSlots[slot];
    if((cacheSlot->setToString != NULL) && ( (cacheSlot->setToString == (CFStringRef)self) || ((cacheSlot->setToLength == selfLength) && (cacheSlot->setToHash == selfHash)) ) ) { rkl_clearCacheSlotSetTo(cacheSlot); }
  }

  RKLBuffer *buffer = (selfLength < (CFIndex)(RKL_FIXED_LENGTH)) ? &fixedBuffer : &dynamicBuffer;
  if((buffer->string != NULL) && ((buffer->string == (CFStringRef)self) || ((buffer->length == selfLength) && (buffer->hash == selfHash)))) { rkl_clearBuffer(buffer, 0UL); }

  OSSpinLockUnlock(&cacheSpinLock);
  cacheSpinLockStatus |= RKLUnlockedCacheSpinLock;
}

#pragma mark -rangeOfRegex:

- (NSRange)RKL_METHOD_PREPEND(rangeOfRegex):(NSString *)regex
{
  NSRange result = NSNotFoundRange, range = NSMaxiumRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions, 0L,      self, &range, NULL, NULL,  &result);
  return(result);
}

- (NSRange)RKL_METHOD_PREPEND(rangeOfRegex):(NSString *)regex capture:(NSInteger)capture
{
  NSRange result = NSNotFoundRange, range = NSMaxiumRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions, capture, self, &range, NULL, NULL,  &result);
  return(result);
}

- (NSRange)RKL_METHOD_PREPEND(rangeOfRegex):(NSString *)regex inRange:(NSRange)range
{
  NSRange result = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions, 0L,      self, &range, NULL, NULL,  &result);
  return(result);
}

- (NSRange)RKL_METHOD_PREPEND(rangeOfRegex):(NSString *)regex options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error
{
  NSRange result = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, options,      capture, self, &range, NULL, error, &result);
  return(result);
}

#pragma mark -stringByMatching:

- (NSString *)RKL_METHOD_PREPEND(stringByMatching):(NSString *)regex
{
  NSRange matchedRange = NSNotFoundRange, range = NSMaxiumRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions,      0L,      self, &range, NULL, NULL,  &matchedRange);
  return((matchedRange.location == NSNotFound) ? NULL : rkl_CFAutorelease(CFStringCreateWithSubstring(NULL, (CFStringRef)self, CFMakeRange(matchedRange.location, matchedRange.length))));  
}

- (NSString *)RKL_METHOD_PREPEND(stringByMatching):(NSString *)regex capture:(NSInteger)capture
{
  NSRange matchedRange = NSNotFoundRange, range = NSMaxiumRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions,      capture, self, &range, NULL, NULL,  &matchedRange);
  return((matchedRange.location == NSNotFound) ? NULL : rkl_CFAutorelease(CFStringCreateWithSubstring(NULL, (CFStringRef)self, CFMakeRange(matchedRange.location, matchedRange.length))));  
}

- (NSString *)RKL_METHOD_PREPEND(stringByMatching):(NSString *)regex inRange:(NSRange)range
{
  NSRange matchedRange = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, RKLNoOptions,      0L,      self, &range, NULL, NULL,  &matchedRange);
  return((matchedRange.location == NSNotFound) ? NULL : rkl_CFAutorelease(CFStringCreateWithSubstring(NULL, (CFStringRef)self, CFMakeRange(matchedRange.location, matchedRange.length))));  
}

- (NSString *)RKL_METHOD_PREPEND(stringByMatching):(NSString *)regex options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error
{
  NSRange matchedRange = NSNotFoundRange;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLRangeOp, regex, options,           capture, self, &range, NULL, error, &matchedRange);
  return((matchedRange.location == NSNotFound) ? NULL : rkl_CFAutorelease(CFStringCreateWithSubstring(NULL, (CFStringRef)self, CFMakeRange(matchedRange.location, matchedRange.length))));
}

#pragma mark -stringByReplacingOccurrencesOfRegex:

- (NSString *)RKL_METHOD_PREPEND(stringByReplacingOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement
{
  NSRange searchRange = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLReplaceOp, regex, RKLNoOptions, 0L, self, &searchRange, replacement, NULL,  NULL));
}

- (NSString *)RKL_METHOD_PREPEND(stringByReplacingOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement range:(NSRange)searchRange
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLReplaceOp, regex, RKLNoOptions, 0L, self, &searchRange, replacement, NULL,  NULL));
}

- (NSString *)RKL_METHOD_PREPEND(stringByReplacingOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError **)error
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLReplaceOp, regex, options,      0L, self, &searchRange, replacement, error, NULL));
}

#pragma mark -componentsMatchedByRegex:

- (NSArray *)RKL_METHOD_PREPEND(componentsMatchedByRegex):(NSString *)regex
{
  NSRange searchRange = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLArrayOfStringsOp, regex, RKLNoOptions, 0L,      self, &searchRange, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(componentsMatchedByRegex):(NSString *)regex capture:(NSInteger)capture
{
  NSRange searchRange = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLArrayOfStringsOp, regex, RKLNoOptions, capture, self, &searchRange, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(componentsMatchedByRegex):(NSString *)regex range:(NSRange)range
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLArrayOfStringsOp, regex, RKLNoOptions, 0L,      self, &range,       NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(componentsMatchedByRegex):(NSString *)regex options:(RKLRegexOptions)options range:(NSRange)range capture:(NSInteger)capture error:(NSError **)error
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLArrayOfStringsOp, regex, options,      capture, self, &range,       NULL, error, NULL));
}

#pragma mark -captureComponentsMatchedByRegex:

- (NSArray *)RKL_METHOD_PREPEND(captureComponentsMatchedByRegex):(NSString *)regex
{
  NSRange searchRange = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLCapturesArrayOp, regex, RKLNoOptions, 0L, self, &searchRange, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(captureComponentsMatchedByRegex):(NSString *)regex range:(NSRange)range
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLCapturesArrayOp, regex, RKLNoOptions, 0L, self, &range,       NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(captureComponentsMatchedByRegex):(NSString *)regex options:(RKLRegexOptions)options range:(NSRange)range error:(NSError **)error
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)RKLCapturesArrayOp, regex, options,      0L, self, &range,       NULL, error, NULL));
}

#pragma mark -arrayOfCaptureComponentsMatchedByRegex:

- (NSArray *)RKL_METHOD_PREPEND(arrayOfCaptureComponentsMatchedByRegex):(NSString *)regex
{
  NSRange searchRange = NSMaxiumRange;
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLArrayOfCapturesOp | RKLSubcapturesArray), regex, RKLNoOptions, 0L, self, &searchRange, NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(arrayOfCaptureComponentsMatchedByRegex):(NSString *)regex range:(NSRange)range
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLArrayOfCapturesOp | RKLSubcapturesArray), regex, RKLNoOptions, 0L, self, &range,       NULL, NULL,  NULL));
}

- (NSArray *)RKL_METHOD_PREPEND(arrayOfCaptureComponentsMatchedByRegex):(NSString *)regex options:(RKLRegexOptions)options range:(NSRange)range error:(NSError **)error
{
  return(rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLArrayOfCapturesOp | RKLSubcapturesArray), regex, options,      0L, self, &range,       NULL, error, NULL));
}

@end


@implementation NSMutableString (RegexKitLiteAdditions)

#pragma mark -replaceOccurrencesOfRegex:

- (NSUInteger)RKL_METHOD_PREPEND(replaceOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement
{
  NSRange    searchRange   = NSMaxiumRange;
  NSUInteger replacedCount = 0UL;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLReplaceOp | RKLReplaceMutable), regex, RKLNoOptions, 0L, self, &searchRange, replacement, NULL,  (void **)((void *)&replacedCount));
  return(replacedCount);
}

- (NSUInteger)RKL_METHOD_PREPEND(replaceOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement range:(NSRange)searchRange
{
  NSUInteger replacedCount = 0UL;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLReplaceOp | RKLReplaceMutable), regex, RKLNoOptions, 0L, self, &searchRange, replacement, NULL,  (void **)((void *)&replacedCount));
  return(replacedCount);
}

- (NSUInteger)RKL_METHOD_PREPEND(replaceOccurrencesOfRegex):(NSString *)regex withString:(NSString *)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError **)error
{
  NSUInteger replacedCount = 0UL;
  rkl_performRegexOp(self, _cmd, (RKLRegexOp)(RKLReplaceOp | RKLReplaceMutable), regex, options,      0L, self, &searchRange, replacement, error, (void **)((void *)&replacedCount));
  return(replacedCount);
}

@end
