//
//  SPAsyncTests.m
//  Unit Tests
//
//  Created by James on 12/6/2020.
//  Copyright © 2020 Sequel-Ace. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "SPFunctions.h"
#import "SPMainThreadTrampoline.h"

@interface SPSyncTests : XCTestCase

@end

@implementation SPSyncTests

- (void)setUp {
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPerformance_dispatch_sync {
	
	// this is on main thread
	[self measureBlock:^{
		// Put the code you want to measure the time of here.
		int const iterations = 1000000;
				
		NSTextField *errorTextTitle = [[NSTextField alloc] init];
		
		for (int i = 0; i < iterations; i++) {
			@autoreleasepool {
				// exec on bg thread
				dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
					
					// test dispatch_sync
					dispatch_sync(dispatch_get_main_queue(), ^{
						[errorTextTitle setStringValue:@"JIMMY"];
					});
				});
			}
		}
	}];
}

// DOESN'T WORK
- (void)testPerformance_onMainThread {
	// this is on main thread
	[self measureBlock:^{
		// Put the code you want to measure the time of here.
		int const iterations = 1000000;
		
		NSTextField *errorTextTitle = [[NSTextField alloc] init];

		for (int i = 0; i < iterations; i++) {
			@autoreleasepool {
				// exec on bg thread
				dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
					
					// use the object trampoline
					// onMainThread is synchronous I believe
					[[errorTextTitle onMainThread] setStringValue:@"JIMMY"];
				});
			}
		}
	}];
}

- (void)testPerformance_SPMainQSync {
	// this is on main thread
	[self measureBlock:^{
		// Put the code you want to measure the time of here.
		int const iterations = 1000000;
		
		NSTextField *errorTextTitle = [[NSTextField alloc] init];

		for (int i = 0; i < iterations; i++) {
			@autoreleasepool {
				// exec on bg thread
				dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
					// exec on main thread sync
					SPMainQSync(^{
						[errorTextTitle setStringValue:@"JIMMY"];
					});
					
				});
			}
		}
	}];
}

@end
