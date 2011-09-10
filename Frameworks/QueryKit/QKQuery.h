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

#import "QKQueryTypes.h"
#import "QKQueryOperators.h"
#import "QKQueryParameter.h"

/**
 * @class QKQuery QKQuery.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Main QueryKit query class.
 */
@interface QKQuery : NSObject 
{
	NSString *_database;
	NSString *_table;
	
	NSMutableString *_query;
	NSMutableArray *_parameters;
	NSMutableArray *_fields;
	NSMutableArray *_groupByFields;
	NSMutableArray *_orderByFields;
	
	QKQueryType _queryType;
	
	BOOL _quoteFields;
	BOOL _orderDescending;
}

/**
 * @property _database The database the query is to be run against (optional).
 */
@property (readwrite, retain, getter=database, setter=setDatabase:) NSString *_database;

/**
 * @property _table The table the query is to be run against.
 */
@property (readwrite, retain, getter=table, setter=setTable:) NSString *_table; 

/**
 * @property _parameters The parameters (constraints) of the query.
 */
@property (readwrite, retain, getter=parameters, setter=setParameters:) NSMutableArray *_parameters;

/**
 * @property _fields The fields of the query.
 */
@property (readwrite, retain, getter=fields, setter=setFields:) NSMutableArray *_fields;

/**
 * @property _queryType The type of query to be built.
 */
@property (readwrite, assign, getter=queryType, setter=setQueryType:) QKQueryType _queryType;

/**
 * @property _quoteFields Indicates whether or not the query's fields should be quoted.
 */
@property (readwrite, assign, getter=quoteFields, setter=setQuoteFields:) BOOL _quoteFields;

+ (QKQuery *)queryTable:(NSString *)table;
+ (QKQuery *)selectQueryFromTable:(NSString *)table;

- (id)initWithTable:(NSString *)table;

- (NSString *)query;

- (void)addField:(NSString *)field;
- (void)addFields:(NSArray *)fields;

- (void)addParameter:(QKQueryParameter *)parameter;
- (void)addParameter:(NSString *)field operator:(QKQueryOperator)operator value:(id)value;

- (void)groupByField:(NSString *)field;
- (void)groupByFields:(NSArray *)fields;

- (void)orderByField:(NSString *)field descending:(BOOL)descending;
- (void)orderByFields:(NSArray *)fields descending:(BOOL)descending;

@end
