//
//  $Id$
//
//  QKQuery.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "QKQuery.h"
#import "QKQueryParameter.h"
#import "QKQueryUtilities.h"

static NSString *QKNoQueryTypeException = @"QKNoQueryType";
static NSString *QKNoQueryTableException = @"QKNoQueryTable";

@interface QKQuery ()

- (void)_validateRequiements;

- (NSString *)_buildQuery;
- (NSString *)_buildFieldList;
- (NSString *)_buildConstraints;

@end

@implementation QKQuery

@synthesize _database;
@synthesize _table;
@synthesize _parameters;
@synthesize _queryType;
@synthesize _fields;
@synthesize _quoteFields;

#pragma mark -
#pragma mark Initialization

+ (QKQuery *)queryTable:(NSString *)table
{
	return [[[QKQuery alloc] initWithTable:table] autorelease];
}

+ (QKQuery *)selectQueryFromTable:(NSString *)table
{
	QKQuery *query = [[[QKQuery alloc] initWithTable:table] autorelease];
	
	[query setQueryType:QKSelectQuery];
	
	return query;
}

- (id)initWithTable:(NSString *)table
{
	if ((self = [super init])) {
		[self setTable:table];
		[self setFields:[[NSMutableArray alloc] init]];
		[self setParameters:[[NSMutableArray alloc] init]];
		[self setQueryType:-1];
		[self setQuoteFields:NO];
		
		_query = [[NSMutableString alloc] init];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

- (NSString *)query
{
	return _query ? [self _buildQuery] : @""; 
}

/**
 * Shortcut for adding a new field to this query.
 */
- (void)addField:(NSString *)field
{
	[_fields addObject:field];
}

/**
 * Shortcut for adding a new parameter to this query.
 */
- (void)addParameter:(NSString *)field operator:(QKQueryOperator)operator value:(id)value
{
	QKQueryParameter *param = [QKQueryParameter queryParamWithField:field operator:operator value:value];
	
	[_parameters addObject:param];
}

#pragma mark -
#pragma mark Private API

/**
 *
 */
- (void)_validateRequiements
{
	if (_queryType == -1) {
		[NSException raise:QKNoQueryTypeException format:@"Attempt to build query with no query type specified."];
	}
	
	if (!_table || [_table length] == 0) {
		[NSException raise:QKNoQueryTableException format:@"Attempt to build query with no query table specified."];
	}
}

/**
 * Builds the actual query.
 */
- (NSString *)_buildQuery
{
	[self _validateRequiements];
	
	BOOL isSelect = (_queryType == QKSelectQuery);
	BOOL isInsert = (_queryType == QKInsertQuery);
	BOOL isUpdate = (_queryType == QKUpdateQuery);
	BOOL isDelete = (_queryType == QKDeleteQuery);
	
	NSString *fields = [self _buildFieldList];
	
	if (isSelect) {
		[_query appendFormat:@"SELECT %@ FROM ", fields];
	}
	else if (isInsert) {
		[_query appendString:@"INSERT INTO "];
	}
	else if (isUpdate) {
		[_query appendString:@"UPDATE "];
	}
	else if (isDelete) {
		[_query appendString:@"DELETE FROM "];
	}
	
	if (_database && [_database length] > 0) {
		[_query appendFormat:@"%@.", _database];
	}
	
	[_query appendString:_table];
	
	if ([_parameters count] > 0) {
		[_query appendString:@" WHERE "];
		[_query appendString:[self _buildConstraints]];
	}
	
	return _query;
}

/**
 * Builds the string representation of the query's field list.
 */
- (NSString *)_buildFieldList
{
	NSMutableString *fields = [NSMutableString string];
	
	if ([_fields count] == 0) {
		[fields appendString:@"*"];
		
		return fields;
	}
	
	for (NSString *field in _fields)
	{		
		field = [field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([field length] == 0) continue;
		
		if (_quoteFields) {
			[fields appendString:@"`"];
		}
		
		[fields appendString:field];
		
		if (_quoteFields) {
			[fields appendString:@"`"];
		}
		
		[fields appendString:@", "];
	}
	
	if ([fields hasSuffix:@", "]) {
		[fields setString:[fields substringToIndex:([fields length] - 2)]];
	}
	
	return fields;
}

/**
 * Builds the string representation of the query's constraints.
 */
- (NSString *)_buildConstraints
{
	NSMutableString *constraints = [NSMutableString string];
	
	if ([_parameters count] == 0) return constraints;
	
	for (QKQueryParameter *param in _parameters)
	{
		NSString *field = [[param field] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		[constraints appendString:field];
		[constraints appendFormat:@" %@ ", [QKQueryUtilities operatorRepresentationForType:[param operator]]];
		[constraints appendString:[[param value] description]];
		
		[constraints appendString:@" AND "];
	}
	
	if ([constraints hasSuffix:@" AND "]) {
		[constraints setString:[constraints substringToIndex:([constraints length] - 5)]];
	}
	
	return constraints;
}

#pragma mark -

- (NSString *)description
{
	return [self query];
}

#pragma mark -

- (void)dealloc
{
	if (_query) [_query release], _query = nil;
	
	[super dealloc];
}

@end
