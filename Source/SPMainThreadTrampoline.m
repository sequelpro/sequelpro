//
//  $Id$
//
//  SPMainThreadTrampoline.m
//  sequel-pro
//
//  Created by Rowan Beentje on 20/03/2010.
//  Copyright 2010 Rowan Beentje. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>
//

#import "SPMainThreadTrampoline.h"

@implementation NSObject (SPMainThreadTrampoline)

/**
 * Provide a category on all NSObjects to return a trampoline for that
 * object on the main thread.
 * This cannot be retained or released.
 */
- (id) onMainThread
{

	// Return an autoreleased trampoline object
	return [[[SPMainThreadTrampoline alloc] initWithObject:self] autorelease];
}

/**
 * Provide a retained version of the category
 */
- (id) retainedOnMainThread
{
	return [[SPMainThreadTrampoline alloc] initWithObject:self];
}

@end


@implementation SPMainThreadTrampoline

/**
 * The master initiliasation - the category implementation calls this
 * with the requested object.
 */
- (id) initWithObject:(id)theObject
{
	if (self = [super init]) {
		trampolineObject = theObject;
	}
	return self;
}

/**
 * Delegate unrecognised methods to the trampolined objects, thanks to the magic
 * of NSInvocation (see forwardInvocation: docs for background). Must be paired
 * with methodSignationForSelector:.
 */
- (void) forwardInvocation:(NSInvocation *)theInvocation
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
- (NSMethodSignature *) methodSignatureForSelector:(SEL)theSelector
{
	NSMethodSignature *defaultSignature = [super methodSignatureForSelector:theSelector];
	if (defaultSignature) return defaultSignature;

	return [trampolineObject methodSignatureForSelector:theSelector];
}

/**
 * Override the default repondsToSelector:, returning true if either NSObject
 * or the trampolined object supports the selector.
 */
- (BOOL) respondsToSelector:(SEL)theSelector
{	
	return ([super respondsToSelector:theSelector] || [trampolineObject respondsToSelector:theSelector]);
}

/**
 * Override the default performSelector:, again either using NSObject defaults
 * or performing the selector on the trampolined object.
 * Note that the return value from the trampolined object is not preserved in this case.
 */
- (id) performSelector:(SEL)theSelector
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
- (id) performSelector:(SEL)theSelector withObject:(id)theObject
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
- (id) onMainThread
{
	return self;
}

@end