//
//  SPThreadAdditions.m
//  sequel-pro
//
//  Created by Rowan Beentje on October 14th, 2012.
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

#import "SPThreadAdditions.h"
#import <objc/objc-runtime.h>

//this is a "private" class only needed by the +detachNewThreadWithName:… method below.
@interface SPNamedThread : NSObject {
	@private
	NSString *name;
	id object;
	SEL selector;
}
- (id)initWithTarget:(id)aObject selector:(SEL)aSelector name:(NSString *)aName;
- (void)run:(id)argument;
@end

@implementation NSThread (SPThreadAdditions)

+ (void)detachNewThreadWithName:(NSString *)aName target:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
{
	// -[NSThread setName:] has two limitations when it comes to visibility in Xcode:
	// a) Xcode only updates the thread name in UI once (on the first time the thread is shown in the debugger).
	// b) Internally this method calls
	//        int	pthread_setname_np(const char*);
	//    which, as can be seen, does not allow to specify a thread id. Therefore it is skipped if <calling thread != self>.
	//    Unfortunately this (and not the property of the NSThread) seems to be the actual name shown in Xcode.
	// The consequence is, we can only set a thread's name from within the thread, so let's add a proxy object to do that.
	SPNamedThread *namedThread = [[SPNamedThread alloc] initWithTarget:aTarget selector:aSelector name:aName];
	
	NSThread *newThread = [[NSThread alloc] initWithTarget:namedThread selector:@selector(run:) object:anArgument];
	[newThread start];
	[newThread autorelease];
	[namedThread autorelease];
}

@end

#pragma mark -

@implementation SPNamedThread

- (id)initWithTarget:(id)aObject selector:(SEL)aSelector name:(NSString *)aName
{
	if(self = [super init]) {
		name = [aName copy];
		object = [aObject retain];
		selector = aSelector;
	}
	return self;
}

- (void)run:(id)argument
{
	[[NSThread currentThread] setName:name];
	
	void (*msgsend)(id, SEL, id) = (void (*)(id, SEL, id)) objc_msgSend; //hint for the compiler
	
	msgsend(object,selector,argument);
}

- (void)dealloc
{
	SPClear(object);
	selector = NULL;
	SPClear(name);
	[super dealloc];
}

@end

#pragma mark -

NSString * SPCtxt(NSString *description,NSObject<SPCountedObject> *object)
{
	NSString *idString = @"nil";
	if(object) {
		idString = [object className];
		if([object respondsToSelector:@selector(instanceId)]) {
			idString = [idString stringByAppendingFormat:@"#%lld", [object instanceId]];
		}
	}
	return [NSString stringWithFormat:@"%@ (%@)",description,idString];
}
