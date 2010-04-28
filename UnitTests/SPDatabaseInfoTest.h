//
//  SPDatabaseInfoTest.h
//  sequel-pro
//
//  Created by David Rekowski on 22.04.10.
//  Copyright 2010 Papaya Software GmbH. All rights reserved.
//

#define USE_APPLICATION_UNIT_TEST 1

#import <SenTestingKit/SenTestingKit.h>


@interface SPDatabaseInfoTest : SenTestCase {

}

- (void)testDatabaseExists;
- (void)testListDBs;
- (void)testListDBsLike;


@end
