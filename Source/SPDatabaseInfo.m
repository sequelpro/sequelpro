//
//  $Id$
//
//  SPDatbaseInfo.h
//  sequel-pro
//
//  Created by David Rekowski on Apr 13, 2010
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

#import "SPDBActionCommons.h"
#import "SPDatabaseInfo.h"

@implementation SPDatabaseInfo

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
