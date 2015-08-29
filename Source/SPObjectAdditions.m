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
static NSMutableDictionary *gScrollViewListeners;

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

- (void)_scrollViewDidChangeBounds:(id)obj
{
	NSMutableString *msg = [NSMutableString string];
	
	[msg appendFormat:@"%s tripped!\n\n",__PRETTY_FUNCTION__];
	
retryDescribe:
	[msg appendFormat:@"passed object (class <%@>): %@\n\n",[obj className],obj];
	
	if ([obj isKindOfClass:[NSNotification class]]) {
		NSNotification *notif = (NSNotification *)obj;
		[msg appendFormat:@"unwrapping NSNotification named '%@' (userInfo=%@)\n\n",
						  [notif name],
		                  [notif userInfo]];
		obj = [notif object];
		goto retryDescribe;
	}
	
	if([obj isKindOfClass:[NSView class]]) {
		[msg appendString:@"View hierarchy (parents):\n"];
		id parent = obj;
		while(parent) {
			[msg appendFormat:@"- %p (class <%@>): %@, id=%@, tag=%ld\n",
							  parent,
			                  [parent className],
			                  parent,
			                  [(NSView *)parent identifier],
			                  [(NSView *)parent tag]];
			parent = [parent superview];
		}
		[msg appendString:@"\n"];
		
		[msg appendString:@"View hierarchy (own children): \n"];
		for (id child in [(NSView *)obj subviews]) {
			[msg appendFormat:@"- %p (class <%@>): %@, id=%@, tag=%ld\n",
			 child,
			 [child className],
			 child,
			 [(NSView *)child identifier],
			 [(NSView *)child tag]];
		}
		[msg appendString:@"\n"];
	}
	
	if([obj respondsToSelector:@selector(window)]) {
		[msg appendFormat:@"In Window: %@\n\n",[obj window]];
	}
	
	[msg appendFormat:@"self: %p (class <%@>)\n\n",self,[self className]];
	
	NSString *key = [NSString stringWithFormat:@"snd=%p,obs=%p",obj,self];
	
	[msg appendFormat:@"registration info for pair (%@):\n %@",key,[gScrollViewListeners objectForKey:key]];
	
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:msg userInfo:nil];
}

@end


@implementation NSNotificationCenter (SPScrollViewDebug)

+ (void)load
{
	 static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		gScrollViewListeners = [[NSMutableDictionary alloc] init];
		
		Class notificationCenter = [self class];
		
		SEL orig = @selector(addObserver:selector:name:object:);
		SEL exch = @selector(sp_addObserver:selector:name:object:);
		
		Method origM = class_getInstanceMethod(notificationCenter, orig);
		Method exchM = class_getInstanceMethod(notificationCenter, exch);
		
		method_exchangeImplementations(origM, exchM);
	});

}

- (void)sp_addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(id)notificationSender
{
	if(notificationSelector == @selector(_scrollViewDidChangeBounds:) && [notificationName isEqualToString:NSViewBoundsDidChangeNotification]) {
		NSString *key = [NSString stringWithFormat:@"snd=%p,obs=%p",notificationSender,notificationObserver];
		NSMutableString *val = [NSMutableString string];
		[val appendFormat:@"observer: %1$p (class %2$@) description: %1$@\n",notificationObserver,[notificationObserver className]];
		if([notificationObserver isKindOfClass:[NSView class]]) {
			[val appendFormat:@"  view info: id=%@, tag=%ld\n",[(NSView *)notificationObserver identifier], [(NSView *)notificationObserver tag]];
		}
		[val appendFormat:@"\nbacktrace:\n%@\n\n",[NSThread callStackSymbols]];
		
		[gScrollViewListeners setObject:val forKey:key];
	}
	// not recursive! method is swizzled.
	[self sp_addObserver:notificationObserver selector:notificationSelector name:notificationName object:notificationSender];
}

@end
