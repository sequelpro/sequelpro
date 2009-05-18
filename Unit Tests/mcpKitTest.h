//
//  mcpKitTest.h
//  sequel-pro
//
//  Created by J Knight on 17/05/09.
//  Copyright 2009 TalonEdge Ltd.. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "CMMCPConnection.h"
#import "CMMCPResult.h"

@interface mcpKitTest : SenTestCase {
	
	CMMCPConnection *mySQLConnection;
}

@end
