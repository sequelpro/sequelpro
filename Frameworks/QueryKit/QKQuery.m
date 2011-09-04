//
//  $Id$
//
//  QKQuery.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "QKQuery.h"

static NSString *QKNoQueryTypeException = @"QKNoQueryType";

@interface QKQuery ()

- (NSString *)_buildQuery;
- (NSString *)_buildFieldList;

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
- (void)addParameter:(NSString *)field operator:(QKQueryOperator *)op value:(id)value
{
	
}

#pragma mark -
#pragma mark Private API

/**
 * Builds the actual query.
 */
- (NSString *)_buildQuery
{
	if (_queryType == -1) {
		[NSException raise:QKNoQueryTypeException format:@"Attempt to build query with no query type specified."];
	}
	
	if (_queryType == QKSelectQuery) {
		[_query appendString:@"SELECT "];
	}
	
	[_query appendString:[self _buildFieldList]];
	
	return _query;
}

/**
 * Builds the string representation of the field list.
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
