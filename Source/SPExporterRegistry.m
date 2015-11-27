//
//  SPExporterRegistry.m
//  sequel-pro
//
//  Created by Max Lohrmann on 22.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import "SPExporterRegistry.h"
#import "SPExportHandlerFactory.h"


@implementation SPExporterRegistry 

- (instancetype)init {
	[NSException raise:NSInternalInconsistencyException format:@"Can't init singleton from %s",__PRETTY_FUNCTION__];
	return nil; // compiler hint
}

- (instancetype)init_ {
	if((self = [super init])) {
		handlers = [[NSMutableArray alloc] init];
	}
	return self;
}

+ (id)sharedRegistry {
	static id sharedInstance = nil;
	static dispatch_once_t sharedInitToken;
	dispatch_once(&sharedInitToken, ^{
		sharedInstance = [[SPExporterRegistry alloc] init_];
	});
	return sharedInstance;
}

- (void)registerExportHandler:(id <SPExportHandlerFactory>)handler {
	@synchronized (self) {
		if([handlers containsObject:handler]) {
			SPLog(@"handler %@ is already registered!",handler);
			return;
		}
		for(id<SPExportHandlerFactory> h in handlers) {
			if([[h uniqueName] isEqualToString:[handler uniqueName]]) {
				[NSException raise:NSInternalInconsistencyException format:@"Trying to add %@ as handler for type %@ while another handler %@ already exists!",handler,[h uniqueName],h];
				return; // compiler hint
			}
		}

		[handlers addObject:handler];
	}
}

- (NSArray *)registeredHandlers {
	@synchronized (self) {
		return [[handlers copy] autorelease];
	}
}

- (id<SPExportHandlerFactory>)handlerNamed:(NSString *)name
{
	@synchronized (self) {
		for(id<SPExportHandlerFactory> handler in handlers) {
			if([[handler uniqueName] isEqualToString:name])
				return handler;
		}
		return nil;
	}
}

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

- (NSUInteger)retainCount {
	return NSUIntegerMax;
}

- (instancetype)retain {
	return self;
}

- (oneway void)release {
	/* noop */
}

- (void)dealloc {
	SPClear(handlers);
	[super dealloc];
}


@end
