//
//  RegexKitLite.m
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

#import <CoreFoundation/CFBase.h>
#import <CoreFoundation/CFString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSException.h>
#import <libkern/OSAtomic.h>
#import <string.h>
#import <stdlib.h>
#import "RegexKitLite.h"

#ifndef RKL_CACHE_SIZE
#define RKL_CACHE_SIZE 23
#endif

#ifndef RKL_FIXED_LENGTH
#define RKL_FIXED_LENGTH 2048
#endif

// Ugly macros to keep other parts clean.

#define NSRangeInsideRange(inside, within) ({NSRange _inside = (inside), _within = (within); (((_inside.location - _within.location) <= _within.length) && ((NSMaxRange(_inside) - _within.location) <= _within.length));})
#define NSEqualRanges(range1, range2)      ({NSRange _r1 = (range1), _r2 = (range2); ((_r1.location == _r2.location) && (_r1.length == _r2.length));})
#define NSMakeRange(loc, len)              ((NSRange){(NSUInteger)(loc), (NSUInteger)(len)})
#define CFMakeRange(loc, len)              ((CFRange){(CFIndex)(loc), (CFIndex)(len)})
#define NSMaxRange(r)                      ({NSRange _r = (r); _r.location + _r.length;})
#define NSNotFoundRange                    ((NSRange){NSNotFound, 0})
#define NSMaxiumRange                      ((NSRange){0, NSUIntegerMax})

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
#define CFAutorelease(obj) ({CFTypeRef _obj = (obj); (_obj == NULL) ? NULL : [(id)CFMakeCollectable(_obj) autorelease]; })
#else
#define CFAutorelease(obj) ({CFTypeRef _obj = (obj); (_obj == NULL) ? NULL : [(id)(_obj) autorelease]; })
#endif

#define RKLMakeString(str, hash, len, uc) ((RKLString){(str), (hash), (len), (UniChar *)(uc)})
#define RKLClearCacheSlotLastString(ce) ({ ce->last = RKLMakeString(NULL, 0, 0, NULL); ce->lastFindRange = NSNotFoundRange; ce->lastMatchRange = NSNotFoundRange; })
#define RKLGetRangeForCapture(regex, status, capture, range) ({ range.location = (NSUInteger)uregex_start(regex, capture, &status); range.length = (NSUInteger)uregex_end(regex, capture, &status) - range.location; status; })
#define RKLInternalException [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"An internal error occured at %@:%d", [NSString stringWithUTF8String:__FILE__], __LINE__] userInfo:NULL]

// Exported symbols.  Error domains, keys, etc.
NSString * const RKLICURegexErrorDomain          = @"RKLICURegexErrorDomain";

NSString * const RKLICURegexErrorNameErrorKey    = @"RKLICURegexErrorName";
NSString * const RKLICURegexLineErrorKey         = @"RKLICURegexLine";
NSString * const RKLICURegexOffsetErrorKey       = @"RKLICURegexOffset";
NSString * const RKLICURegexPreContextErrorKey   = @"RKLICURegexPreContext";
NSString * const RKLICURegexPostContextErrorKey  = @"RKLICURegexPostContext";
NSString * const RKLICURegexRegexErrorKey        = @"RKLICURegexRegex";
NSString * const RKLICURegexRegexOptionsErrorKey = @"RKLICURegexRegexOptions";

// Type / struct definitions

typedef struct uregex uregex; // Opaque ICU regex type.

#define U_PARSE_CONTEXT_LEN 16

typedef struct UParseError {
  int32_t line;
  int32_t offset;
  unichar preContext[U_PARSE_CONTEXT_LEN];
  unichar postContext[U_PARSE_CONTEXT_LEN];
} UParseError;

typedef struct {
  void       *string; // Used ONLY for pointer equality tests! Never messaged!
  CFHashCode  hash;
  NSUInteger  length;
  UniChar    *uniChar;
} RKLString;

typedef struct {
  NSString        *regexString;
  RKLRegexOptions  regexOptions;
  uregex          *icu_regex;
  NSInteger        captureCount;

  RKLString        last;
  NSRange          lastFindRange;
  NSRange          lastMatchRange;
} RKLCacheSlot;

// ICU functions.  See http://www.icu-project.org/apiref/icu4c/uregex_8h.html Tweaked slightly from the originals, but functionally identical.
const char * u_errorName       (int32_t status);
int32_t      u_strlen          (const UniChar *s);
void         uregex_close      (uregex *regexp);
int32_t      uregex_end        (uregex *regexp, int32_t groupNum, int32_t *status);
BOOL         uregex_find       (uregex *regexp, int32_t location, int32_t *status);
BOOL         uregex_findNext   (uregex *regexp, int32_t *status);
int32_t      uregex_groupCount (uregex *regexp, int32_t *status);
uregex     * uregex_open       (const UniChar *pattern, int32_t patternLength, RKLRegexOptions flags, UParseError *parseError, int32_t *status);
void         uregex_setText    (uregex *regexp, const UniChar *text, int32_t textLength, int32_t *status);
int32_t      uregex_start      (uregex *regexp, int32_t groupNum, int32_t *status);

static RKLCacheSlot *getCachedRegex     (NSString *regexString, RKLRegexOptions regexOptions, NSError **error);
static NSError      *RKLNSErrorForRegex (NSString *regexString, RKLRegexOptions regexOptions, UParseError *parseError, int status);

// Compile unit local global variables
static OSSpinLock    cacheSpinLock = OS_SPINLOCK_INIT;
static RKLCacheSlot  RKLCache[RKL_CACHE_SIZE];
static RKLCacheSlot *lastCacheSlot;
static void         *lastRegexString;
static UniChar       fixedUniChar[(RKL_FIXED_LENGTH * sizeof(UniChar))];
static RKLString     fixedString = {NULL, 0, 0, &fixedUniChar[0]};
static RKLString     dynamicString;

//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  IMPORTANT!   Should only be called with cacheSpinLock already locked!
//  ----------

static RKLCacheSlot *getCachedRegex(NSString *regexString, RKLRegexOptions regexOptions, NSError **error) {
  CFHashCode    regexHash    = CFHash(regexString);
  RKLCacheSlot *cacheSlot    = &RKLCache[regexHash % RKL_CACHE_SIZE]; // Retrieve the cache slot for this regex.
  UParseError   parseError   = (UParseError){-1, -1, {0}, {0}};
  UniChar      *regexUniChar = NULL;
  CFIndex       regexLength  = 0;
  int32_t       status       = 0;

  // Return the cached entry if it's a match, otherwise clear the slot and create a new ICU regex in its place.
  if((cacheSlot->regexOptions == regexOptions) && (cacheSlot->icu_regex != NULL) && (cacheSlot->regexString != NULL) && (CFEqual(regexString, cacheSlot->regexString) == YES)) { lastCacheSlot = cacheSlot; lastRegexString = regexString; return(cacheSlot); }

  RKLClearCacheSlotLastString(cacheSlot); // Clear any cached string state for this cache slot.
  if(cacheSlot->regexString != NULL) { CFRelease(cacheSlot->regexString);  cacheSlot->regexString = NULL; cacheSlot->regexOptions =  0; }
  if(cacheSlot->icu_regex   != NULL) { uregex_close(cacheSlot->icu_regex); cacheSlot->icu_regex   = NULL; cacheSlot->captureCount = -1; }

  cacheSlot->regexString  = (NSString *)CFStringCreateCopy(NULL, (CFStringRef)regexString); // Get a cheap immutable copy.
  cacheSlot->regexOptions = regexOptions;
  regexLength             = CFStringGetLength((CFStringRef)regexString); // In UTF16 code pairs.

  // Try to quickly obtain the regex string in UTF16 format. Otherwise allocate enough space on the stack and convert to UTF16 using the stack buffer.
  if((regexUniChar = (UniChar *)CFStringGetCharactersPtr((CFStringRef)regexString)) == NULL) {
    if((regexUniChar = alloca(regexLength * sizeof(UniChar))) == NULL) { return(NULL); }
    CFStringGetCharacters((CFStringRef)regexString, CFRangeMake(0, regexLength), regexUniChar);
  }

  // Create the ICU regex. If there is a problem, create a NSError if requested.
  if(((cacheSlot->icu_regex = uregex_open(regexUniChar, (int32_t)regexLength, regexOptions, &parseError, &status)) == NULL) && (status > 0)) {
    if(error != NULL) { *error = RKLNSErrorForRegex(regexString, regexOptions, &parseError, status); }
    return(NULL);
  }

  cacheSlot->captureCount = (NSUInteger)uregex_groupCount(cacheSlot->icu_regex, &status);
  lastCacheSlot           = cacheSlot;
  lastRegexString         = regexString;

  return(cacheSlot);
}

static NSError *RKLNSErrorForRegex(NSString *regexString, RKLRegexOptions regexOptions, UParseError *parseError, int status) {
  NSNumber *regexOptionsNumber = [NSNumber numberWithInt:regexOptions];
  NSNumber *lineNumber         = [NSNumber numberWithInt:parseError->line];
  NSNumber *offsetNumber       = [NSNumber numberWithInt:parseError->offset];
  NSString *preContextString   = [NSString stringWithCharacters:&parseError->preContext[0]  length:u_strlen(&parseError->preContext[0])];
  NSString *postContextString  = [NSString stringWithCharacters:&parseError->postContext[0] length:u_strlen(&parseError->postContext[0])];
  NSString *errorNameString    = [NSString stringWithUTF8String:u_errorName(status)];
  NSString *reasonString       = [NSString stringWithFormat:@"The error %@ occured at line %d, column %d: %@<<HERE>>%@", errorNameString, parseError->line, parseError->offset, preContextString, postContextString];

  // If line == -1, parseError doesn't contain any useful information.  Set lineNumber to NULL,
  // which will stop adding objects to the dictionary at that point, ignoring everything after.
  if(parseError->line == -1) { reasonString = [NSString stringWithFormat:@"The error %@ occured.", errorNameString]; lineNumber = NULL; }

  return([NSError errorWithDomain:RKLICURegexErrorDomain code:(NSInteger)status userInfo:[NSDictionary dictionaryWithObjectsAndKeys: @"There was an error compiling the regular expression.", @"NSLocalizedDescription", reasonString, @"NSLocalizedFailureReason", regexString, RKLICURegexRegexErrorKey, regexOptionsNumber, RKLICURegexRegexOptionsErrorKey, lineNumber, RKLICURegexLineErrorKey, offsetNumber, RKLICURegexOffsetErrorKey, preContextString, RKLICURegexPreContextErrorKey, postContextString, RKLICURegexPostContextErrorKey, errorNameString, RKLICURegexErrorNameErrorKey, NULL]]);
}

@implementation NSString (RegexKitLiteAdditions)

+ (void)clearStringCache
{
  OSSpinLockLock(&cacheSpinLock);
  fixedString   = RKLMakeString(NULL, 0, 0, fixedString.uniChar);
  dynamicString = RKLMakeString(NULL, 0, 0, reallocf(dynamicString.uniChar, 0));
  NSUInteger x = 0;
  for(x = 0; x < RKL_CACHE_SIZE; x++) { RKLClearCacheSlotLastString((&RKLCache[x])); }
  OSSpinLockUnlock(&cacheSpinLock);
}

+ (NSInteger)captureCountForRegex:(NSString *)regexString
{
  return([self captureCountForRegex:regexString options:RKLNoOptions error:NULL]);
}

+ (NSInteger)captureCountForRegex:(NSString *)regexString options:(RKLRegexOptions)options error:(NSError **)error
{
  if(error       != NULL) { *error = NULL; }
  if(regexString == NULL) { [NSException raise:NSInvalidArgumentException format:@"The regular expression argument is NULL."]; }

  RKLCacheSlot *cacheSlot    = NULL;
  NSInteger     captureCount = -1;

  OSSpinLockLock(&cacheSpinLock);
  if((cacheSlot = getCachedRegex(regexString, options, error)) != NULL) { captureCount = cacheSlot->captureCount; }
  OSSpinLockUnlock(&cacheSpinLock);

  return(captureCount);
}

- (BOOL)isMatchedByRegex:(NSString *)regexString
{
  return([self isMatchedByRegex:regexString options:RKLNoOptions inRange:NSMaxiumRange error:NULL]);
}

- (BOOL)isMatchedByRegex:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range error:(NSError **)error
{
  return(([self rangeOfRegex:regexString options:options inRange:range capture:0 error:error].location == NSNotFound) ? NO : YES);
}

- (NSString *)stringByMatching:(NSString *)regexString
{
  return([self stringByMatching:regexString options:RKLNoOptions inRange:NSMaxiumRange capture:0 error:NULL]);
}

- (NSString *)stringByMatching:(NSString *)regexString capture:(NSInteger)capture
{
  return([self stringByMatching:regexString options:RKLNoOptions inRange:NSMaxiumRange capture:capture error:NULL]);
}

- (NSString *)stringByMatching:(NSString *)regexString inRange:(NSRange)range
{
  return([self stringByMatching:regexString options:RKLNoOptions inRange:range capture:0 error:NULL]);
}

- (NSString *)stringByMatching:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error
{
  NSRange matchedRange = [self rangeOfRegex:regexString options:options inRange:range capture:capture error:error];
  return((matchedRange.location == NSNotFound) ? NULL : CFAutorelease(CFStringCreateWithSubstring(NULL, (CFStringRef)self, CFMakeRange(matchedRange.location, matchedRange.length))));
}

- (NSRange)rangeOfRegex:(NSString *)regexString
{
  return([self rangeOfRegex:regexString options:RKLNoOptions inRange:NSMaxiumRange capture:0 error:NULL]);
}

- (NSRange)rangeOfRegex:(NSString *)regexString capture:(NSInteger)capture
{
  return([self rangeOfRegex:regexString options:RKLNoOptions inRange:NSMaxiumRange capture:capture error:NULL]);
}

- (NSRange)rangeOfRegex:(NSString *)regexString inRange:(NSRange)range
{
  return([self rangeOfRegex:regexString options:RKLNoOptions inRange:range capture:0 error:NULL]);
}


//  IMPORTANT!   This code is critical path code.  Because of this, it has been written for speed, not clarity.
//  ----------

- (NSRange)rangeOfRegex:(NSString *)regexString options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError **)error
{
  if(error       != NULL) { *error = NULL; }
  if(regexString == NULL) { [NSException raise:NSInvalidArgumentException format:@"The regular expression argument is NULL."]; }

  NSRange       captureRange = NSNotFoundRange;
  CFIndex       stringLength = CFStringGetLength((CFStringRef)self); // In UTF16 code pairs.
  RKLCacheSlot *cacheSlot    = NULL;
  NSException  *exception    = NULL;
  int32_t       status       = 0;

  if(range.length == NSUIntegerMax) { range.length = stringLength; } // For convenience.
  if((NSUInteger)stringLength < NSMaxRange(range)) { [NSException raise:NSRangeException format:@"The search range exceeds the strings bounds."]; }

  // IMPORTANT!   Once we have obtained the lock, code MUST exit via 'goto exitNow;' to unlock the lock!  NO EXCEPTIONS!

  OSSpinLockLock(&cacheSpinLock); // Grab the lock and get cache entry.
  // Fast path the common case where this regex is the same one used last time.
  // On a miss, do full lookup with getCachedRegex(), which compiles the regex if it's not in the cache.
  if((lastCacheSlot != NULL) && (options == lastCacheSlot->regexOptions) && (CFEqual(regexString, lastCacheSlot->regexString) == YES)) { cacheSlot = lastCacheSlot; }
  else if((cacheSlot = getCachedRegex(regexString, options, error)) == NULL) { goto exitNow; }
  if(cacheSlot->icu_regex == NULL) { exception = RKLInternalException; goto exitNow; } // assertion check.

  if((capture < 0) || (capture > cacheSlot->captureCount)) { exception = [NSException exceptionWithName:NSInvalidArgumentException reason:@"The capture argument is not valid." userInfo:NULL]; goto exitNow; }

  RKLString  selfString = RKLMakeString(self, CFHash(self), stringLength, CFStringGetCharactersPtr((CFStringRef)self));
  // *string will point to the most approrpiate buffer.  If selfString contains a valid uniChar pointer, that's used.
  // Otherwise, use the strings length to determine if the fixed or dynamically sized conversion buffer should be used.
  RKLString *string     = (selfString.uniChar != NULL) ? &selfString : (stringLength < RKL_FIXED_LENGTH) ? &fixedString : &dynamicString;
  
  // Check if this regex is already set to this string.
  if((cacheSlot->last.uniChar == string->uniChar) && (cacheSlot->last.string == selfString.string) && (cacheSlot->last.hash == selfString.hash) && (cacheSlot->last.length == selfString.length) && (cacheSlot->last.string != NULL)) { goto alreadySetText; }
  
  // If we didn't get direct UTF16 access, perform any required UTF16 conversions if the current buffer doesn't match this string.
  if((string != &selfString) && ((string->string != self) || (string->length != selfString.length) || (string->hash != selfString.hash))) {
    *string = RKLMakeString(self, selfString.hash, selfString.length, string->uniChar);
    // If this is the dynamically sized buffer, resize the allocation to the correct size.
    if((stringLength >= RKL_FIXED_LENGTH) && ((string->uniChar = reallocf(string->uniChar, (selfString.length * sizeof(UniChar)))) == NULL)) { goto exitNow; }
    CFStringGetCharacters((CFStringRef)self, CFRangeMake(0, string->length), string->uniChar); // Convert to a UTF16 string.
  }

  RKLClearCacheSlotLastString(cacheSlot); // Clear the cached state for this regex.
  if(string->uniChar == NULL) { exception = RKLInternalException; goto exitNow; } // assertion check.
  uregex_setText(cacheSlot->icu_regex, string->uniChar, string->length, &status); // "set" the ICU regex to this string.
  if(status != 0) { goto exitNow; }
  cacheSlot->last = *string; // Cache the last string we set this regex to.
  
 alreadySetText:
  if((NSEqualRanges(range, cacheSlot->lastFindRange) == NO)) { // Perform a 'find' if the current range is different than the last find range.
    // Using uregex_findNext can be a slight performance win.
    BOOL useFindNext = (range.location == (NSMaxRange(cacheSlot->lastMatchRange) + ((cacheSlot->lastMatchRange.length == 0) ? 1 : 0))) ? YES : NO;

    cacheSlot->lastFindRange = NSNotFoundRange; // Cleared the cached search/find range.
    if(useFindNext == NO) { if((uregex_find    (cacheSlot->icu_regex, range.location, &status) == NO) || (status != 0)) { goto exitNow; } }
    else {                  if((uregex_findNext(cacheSlot->icu_regex,                 &status) == NO) || (status != 0)) { goto exitNow; } }

    if(RKLGetRangeForCapture(cacheSlot->icu_regex, status, 0, cacheSlot->lastMatchRange) != 0) { goto exitNow; }
    cacheSlot->lastFindRange = range; // Cache the successful search/find range.
  }

  if(NSRangeInsideRange(cacheSlot->lastMatchRange, range) == NO) { goto exitNow; } // If the regex matched outside the requested range, exit.
  if(capture == 0) { captureRange = cacheSlot->lastMatchRange; } else { RKLGetRangeForCapture(cacheSlot->icu_regex, status, capture, captureRange); }

 exitNow: // A bit of advice...
  OSSpinLockUnlock(&cacheSpinLock); // Always... no, no... never... forget to unlock your locks.
  if(exception != NULL) { [exception raise]; } // I think the young people enjoy it when I "get down" verbally, don't you? 
  if(status > 0) { [NSException raise:NSInternalInconsistencyException format:@"ICU regular expression error #%d, %s", status, u_errorName(status)]; }
  return((status == 0) ? captureRange : NSNotFoundRange);
}

@end
