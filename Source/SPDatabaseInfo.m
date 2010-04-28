//
//  SPDatabaseInfo.m
//  sequel-pro
//
//  Created by David Rekowski on 19.04.10.
//  Copyright 2010 Papaya Software GmbH. All rights reserved.
//

#import "SPAlertSheets.h"
#import "SPDatabaseInfo.h"
#import "SPStringAdditions.h"
#import "Sequel-Pro.pch"

@implementation SPDatabaseInfo

@synthesize connection;
@synthesize parent;

- (NSObject *)getTableWindow {
	return [NSApp mainWindow];
}

-(BOOL)databaseExists:(NSString *)databaseName {
	NSArray *names = [self listDBs];
	return [names containsObject:databaseName];
}

- (NSArray *)listDBs {
	return [self listDBsLike:nil];
}

- (NSArray *)listDBsLike:(NSString *)dbsName
{
	NSString *listDBStatement = nil;
	if ((dbsName == nil) || ([dbsName isEqualToString:@""])) {
		listDBStatement = [NSString stringWithFormat:@"SHOW DATABASES"];
	}
	else {
		listDBStatement = [NSString stringWithFormat:@"SHOW DATABASES LIKE %@", [dbsName backtickQuotedString]];
	}
	DLog(@"running query : %@", listDBStatement);
	MCPResult *theResult = [connection queryString:listDBStatement];
		
	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Failed to retrieve databases list", @"database list error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to retrieve a list of databases.\n\nMySQL said: %@", 
																	   @"database list error informative message"), 
						   [connection getLastErrorMessage]]);
		return NO;
	}
	
	NSMutableArray *names = [NSMutableArray array];
	NSMutableString *name;
	if ([theResult numOfRows] > 1) {
		int i;
		for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
			name = [[theResult fetchRowAsArray] objectAtIndex:0];
			[names addObject:name];
		}		
	}
	
	return names;    
}

@end
