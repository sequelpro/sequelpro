//
//  SPTableData.h
//  sequel-pro
//
//  Created by Rowan Beentje on January 24, 2009.
//  Copyright (c) 2009 Arboreal. All rights reserved.
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

@class SPDatabaseDocument;
@class SPTablesList;
@class SPMySQLConnection;

@interface SPTableData : NSObject 
{
	IBOutlet SPDatabaseDocument* tableDocumentInstance;
	IBOutlet SPTablesList* tableListInstance;

	NSMutableArray *columns;
	NSMutableArray *columnNames;
	NSMutableArray *constraints;
	NSArray *triggers;
	NSMutableDictionary *status;
	NSMutableArray *primaryKeyColumns;
	
	NSString *tableEncoding;
	NSString *tableCreateSyntax;
	
	SPMySQLConnection *mySQLConnection;

	pthread_mutex_t dataProcessingLock;

	BOOL tableHasAutoIncrementField;
}

@property (readonly, assign) BOOL tableHasAutoIncrementField;
@property (nonatomic, retain) SPMySQLConnection *connection;

- (NSString *) tableEncoding;
- (NSString *) tableCreateSyntax;
- (NSArray *) columns;
- (NSDictionary *) columnWithName:(NSString *)colName;
- (NSArray *) columnNames;
- (NSDictionary *) columnAtIndex:(NSInteger)index;
- (NSArray *) getConstraints;
- (NSArray *) triggers;
- (BOOL) columnIsBlobOrText:(NSString *)colName;
- (BOOL) columnIsGeometry:(NSString *)colName;
- (NSString *) statusValueForKey:(NSString *)aKey;
- (void)setStatusValue:(NSString *)value forKey:(NSString *)key;
- (NSDictionary *) statusValues;
- (void) resetAllData;
- (void) resetStatusData;
- (void) resetColumnData;
- (BOOL) updateInformationForCurrentTable;
- (NSDictionary *) informationForTable:(NSString *)tableName;
- (BOOL) updateInformationForCurrentView;
- (NSDictionary *) informationForView:(NSString *)viewName;
- (BOOL) updateStatusInformationForCurrentTable;
- (BOOL) updateTriggersForCurrentTable;
- (BOOL) updateAccurateNumberOfRowsForCurrentTableForcingUpdate:(BOOL)alwaysUpdate;
- (NSDictionary *) parseFieldDefinitionStringParts:(NSArray *)definitionParts;
- (NSArray *) primaryKeyColumnNames;

#ifdef SP_CODA /* glue */
- (void)setTableDocumentInstance:(SPDatabaseDocument*)doc;
- (void)setTableListInstance:(SPTablesList*)list;
#endif

@end
