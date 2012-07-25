//
//  $Id$
//
//  SPMainThreadTrampoline.m
//  sequel-pro
//
//  Created by Rowan Beentje on March 20, 2010.
//  Copyright (c) 2010 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPMainThreadTrampoline.h"

@implementation NSObject (SPMainThreadTrampoline)

/**
 * Provide a category on all NSObjects to return a trampoline for that
 * object on the main thread.
 * This cannot be retained or released.
 */
- (id)onMainThread
{

	// Return an autoreleased trampoline object
	return [[[SPMainThreadTrampoline alloc] initWithObject:self] autorelease];
}

/**
 * Provide a retained version of the category
 */
- (id)retainedOnMainThread
{
	return [[SPMainThreadTrampoline alloc] initWithObject:self];
}

@end

@implementation SPMainThreadTrampoline

/**
 * The master initiliasation - the category implementation calls this
 * with the requested object.
 */
- (id)initWithObject:(id)theObject
{
	if ((self = [super init])) {
		trampolineObject = theObject;
	}
	
	return self;
}

/**
 * Delegate unrecognised methods to the trampolined objects, thanks to the magic
 * of NSInvocation (see forwardInvocation: docs for background). Must be paired
 * with methodSignationForSelector:.
 */
- (void)forwardInvocation:(NSInvocation *)theInvocation
{
	SEL theSelector = [theInvocation selector];
	if (![trampolineObject respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];

	// Retain the arguments and object for the call for safety
	[theInvocation retainArguments];
	[trampolineObject retain];
	[theInvocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:trampolineObject waitUntilDone:YES];
	[trampolineObject release];
}

/**
 * Return the correct method signatures for the trampolined object if
 * NSObject doesn't implement the requested methods.
 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)theSelector
{
	NSMethodSignature *defaultSignature = [super methodSignatureForSelector:theSelector];
	if (defaultSignature) return defaultSignature;

	return [trampolineObject methodSignatureForSelector:theSelector];
}

/**
 * Override the default repondsToSelector:, returning true if either NSObject
 * or the trampolined object supports the selector.
 */
- (BOOL)respondsToSelector:(SEL)theSelector
{	
	return ([super respondsToSelector:theSelector] || [trampolineObject respondsToSelector:theSelector]);
}

/**
 * Override the default performSelector:, again either using NSObject defaults
 * or performing the selector on the trampolined object.
 * Note that the return value from the trampolined object is not preserved in this case.
 */
- (id)performSelector:(SEL)theSelector
{
	if ([super respondsToSelector:theSelector]) return [super performSelector:theSelector];

	if (![trampolineObject respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];

	// Retain the object while performing calls on it
	[trampolineObject retain];
	[trampolineObject performSelectorOnMainThread:theSelector withObject:nil waitUntilDone:YES];
	[trampolineObject release];

	return nil;
}

/**
 * Override the default performSelector:withObject: - see performSelector:
 * Note that the return value from the trampolined object is not preserved in this case.
 */
- (id)performSelector:(SEL)theSelector withObject:(id)theObject
{
	if ([super respondsToSelector:theSelector]) return [super performSelector:theSelector withObject:theObject];

	if (![trampolineObject respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];

	// Retain the trampolined object, and the argument object, while performing calls
	[trampolineObject retain];
	[theObject retain];
	[trampolineObject performSelectorOnMainThread:theSelector withObject:theObject waitUntilDone:YES];
	[theObject release];
	[trampolineObject release];

	return nil;
}

/**
 * If the trampoline is sent the onMainThread category, just return the trampoline directly.
 */
- (id)onMainThread
{
	return self;
}

@end
