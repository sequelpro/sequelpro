//  DMLocalizedNib.m
//
//  Created by Rowan Beentje on July 4, 2010
//  Copyright © 2010 Rowan Beentje. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Rowan Beentje otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.


#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>


@interface NSNib (DMLocalizedNib)
- (id)deliciousInitWithNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle;
- (id)deliciousInitWithContentsOfURL:(NSURL *)nibFileURL;
- (BOOL)deliciousInstantiateNibWithOwner:(id)owner topLevelObjects:(NSArray **)topLevelObjects;
- (void)setDeliciousNibName:(NSString *)nibName;
- (NSString *)deliciousNibName;
- (void)deliciousDealloc;
@end

static NSMutableDictionary *deliciousNibNames = nil;

@implementation NSNib (DMLocalizedNib)

#pragma mark NSObject

/**
 * On NSNib class load, swizzle in our overrides of the basic methods.
 */
+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (self == [NSNib class]) {
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(initWithNibNamed:bundle:)), class_getInstanceMethod(self, @selector(deliciousInitWithNibNamed:bundle:)));
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(initWithContentsOfURL:)), class_getInstanceMethod(self, @selector(deliciousInitWithContentsOfURL:)));
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(instantiateNibWithOwner:topLevelObjects:)), class_getInstanceMethod(self, @selector(deliciousInstantiateNibWithOwner:topLevelObjects:)));
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(dealloc)), class_getInstanceMethod(self, @selector(deliciousDealloc)));
	}
    [autoreleasePool release];
}


#pragma mark API

/**
 * An init method swizzled with the original method, storing the base
 * name passed into the init method for later reuse.
 */
- (id)deliciousInitWithNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle
{

	// Instantiate the nib using the original (swizzled) call
	id nib = [self deliciousInitWithNibNamed:nibName bundle:bundle];
	if (nib) {
		[self setDeliciousNibName:nibName];
	}

	return nib;
}

/**
 * An init method swizzled with the original method, extracting and
 * storing the base name of the nib for later reuse.
 */
- (id)deliciousInitWithContentsOfURL:(NSURL *)nibFileURL
{

	// Instantiate the nib using the original (swizzled) call
	id nib = [self deliciousInitWithContentsOfURL:nibFileURL];
	if (nib) {

		// Extract the filename from the URL
		NSArray *urlParts = [[nibFileURL path] componentsSeparatedByString:@"/"];
		NSString *nibName = [urlParts lastObject];
		[self setDeliciousNibName:nibName];
	}

	return nib;
}

/**
 * An instatiation method swizzled with the original method.  Instantiates
 * as before, and then if it can find a .strings file in a preferred language
 * to localize the instantiated objects with, does so.
 */
- (BOOL)deliciousInstantiateNibWithOwner:(id)owner topLevelObjects:(NSArray **)topLevelObjects
{
	if ([self deliciousInstantiateNibWithOwner:owner topLevelObjects:topLevelObjects]) {

		// Look for a localised strings table file based on the original nib name,
		// translating only if one was found and it wasn't English
		NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:[self deliciousNibName] ofType:@"strings"];
		if (localizedStringsTablePath && ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]) {
			[NSBundle _localizeStringsInObject:*topLevelObjects table:[self deliciousNibName]];
		}

		return YES;
	}

	return NO;
}

/**
 * Store the nib name that was used when setting up the nib, which will
 * also be used to look up the .strings file name
 */
- (void)setDeliciousNibName:(NSString *)nibName
{
	if (!deliciousNibNames) {
		deliciousNibNames = [[NSMutableDictionary alloc] init];
	}
	[deliciousNibNames setObject:nibName forKey:[NSValue valueWithPointer:self]];
}

/**
 * Retrieve the nib name to look up the matching .strings file name
 */
- (NSString *)deliciousNibName
{
	return [deliciousNibNames objectForKey:[NSValue valueWithPointer:self]];
}

/**
 * Swizzled deallocate to release custom stores.
 */
- (void)deliciousDealloc
{
	if (deliciousNibNames) {
		[deliciousNibNames removeObjectForKey:[NSValue valueWithPointer:self]];
		if (![deliciousNibNames count]) [deliciousNibNames release], deliciousNibNames = nil;
	}
	[self deliciousDealloc];
}

@end