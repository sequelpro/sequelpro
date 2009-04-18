//
//  RegexKitLite.h
//  http://regexkit.sourceforge.net/
//  Licensesd under the terms of the BSD License, as specified below.
//

/*
 Copyright (c) 2008, John Engelhart
 
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

#ifdef __OBJC__

#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#endif // __OBJC__

#include <limits.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

// For Mac OS X < 10.5.
#ifndef NSINTEGER_DEFINED
#define NSINTEGER_DEFINED
#ifdef __LP64__ || NS_BUILD_32_LIKE_64
typedef long           NSInteger;
typedef unsigned long  NSUInteger;
#define NSIntegerMin   LONG_MIN
#define NSIntegerMax   LONG_MAX
#define NSUIntegerMax  ULONG_MAX
#else
typedef int            NSInteger;
typedef unsigned int   NSUInteger;
#define NSIntegerMin   INT_MIN
#define NSIntegerMax   INT_MAX
#define NSUIntegerMax  UINT_MAX
#endif
#endif // NSINTEGER_DEFINED

#ifndef _REGEXKITLITE_H_
#define _REGEXKITLITE_H_

#ifdef __OBJC__

@class NSError;

// NSError error domains and user info keys.
extern NSString * const RKLICURegexErrorDomain;

extern NSString * const RKLICURegexErrorNameErrorKey;
extern NSString * const RKLICURegexLineErrorKey;
extern NSString * const RKLICURegexOffsetErrorKey;
extern NSString * const RKLICURegexPreContextErrorKey;
extern NSString * const RKLICURegexPostContextErrorKey;
extern NSString * const RKLICURegexRegexErrorKey;
extern NSString * const RKLICURegexRegexOptionsErrorKey;

// These must be idential to their ICU regex counterparts. See http://www.icu-project.org/userguide/regexp.html
enum {
  RKLNoOptions             = 0,
  RKLCaseless              = 2,
  RKLComments              = 4,
  RKLDotAll                = 32,
  RKLMultiline             = 8,
  RKLUnicodeWordBoundaries = 256
};
typedef uint32_t RKLRegexOptions;

@interface NSString (RegexKitLiteAdditions)

+ (void)clearStringCache;

+ (NSInteger)captureCountForRegex:(NSString *)regexString;
+ (NSInteger)captureCountForRegex:(NSString *)regexString options:(RKLRegexOptions)options error:(NSError **)error;

- (BOOL)isMatchedByRegex:(NSString *)regexString;
- (BOOL)isMatchedByRegex:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range error:(NSError **)error;

- (NSRange)rangeOfRegex:(NSString *)regexString;
- (NSRange)rangeOfRegex:(NSString *)regexString capture:(NSInteger)capture;
- (NSRange)rangeOfRegex:(NSString *)regexString inRange:(NSRange)range;
- (NSRange)rangeOfRegex:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error;

- (NSString *)stringByMatching:(NSString *)regexString;
- (NSString *)stringByMatching:(NSString *)regexString capture:(NSInteger)capture;
- (NSString *)stringByMatching:(NSString *)regexString inRange:(NSRange)range;
- (NSString *)stringByMatching:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error;

@end

#endif // _REGEXKITLITE_H_

#endif // __OBJC__

#ifdef __cplusplus
}  // extern "C"
#endif

