//
//  SPObjectAdditions.m
//  sequel-pro
//
//  Created by Rowan Beentje (rowan.beent.je) on February 22, 2012.
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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
//  More info at <https://github.com/sequelpro/sequelpro>

#import <objc/runtime.h>

@implementation NSObject (SPObjectAdditions)

/**
 * Detect whether an object is a NSNull instance.
 */
- (BOOL)isNSNull
{
	id const null = [NSNull null];

	// [NSNull null] is documented as being a singleton class so a pointer equality
	// check is possible - and much faster than checking class membership.
	return (self == null);
}

- (instancetype)unboxNull
{
	if([self isNSNull]) return nil;
	
	return self;
}

- (BOOL)isInArray:(NSArray *)list
{
	return [list containsObject:self];
}

@end

// method swizzling to try and reproduce #2297
//#pragma mark -
//
//@interface NSAlert (ApplePrivate)
//
//- (IBAction)buttonPressed:(id)sender;
//
//@end
//
//@implementation NSAlert (SPAlertDebug)
//
//+ (void)load
//{
//	static dispatch_once_t onceToken;
//	
//	dispatch_once(&onceToken, ^{
//		Class alertClass = [self class];
//		
//		SEL orig = @selector(buttonPressed:);
//		SEL exch = @selector(sp_buttonPressed:);
//		
//		Method origM = class_getInstanceMethod(alertClass, orig);
//		Method exchM = class_getInstanceMethod(alertClass, exch);
//		
//		method_exchangeImplementations(origM, exchM);
//	});
//}
//
//- (IBAction)sp_buttonPressed:(id)obj
//{
//	NSLog(@"%s of %@ title=\n%@\ntext=\n%@",__func__,self,[self messageText],[self informativeText]);
//	
//	[self sp_buttonPressed:obj];
//}
//
//@end
