//
//  $Id$
//
//  QKQuery.h
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

#import "QKQueryTypes.h"
#import "QKQueryOperators.h"

@interface QKQuery : NSObject 
{
	NSString *_database;
	NSString *_table;
	
	NSMutableString *_query;
	NSMutableArray *_parameters;
	NSMutableArray *_fields;
	
	QKQueryType _queryType;
	
	BOOL _quoteFields;
}

/**
 *
 */
@property (readwrite, retain, getter=database, setter=setDatabase:) NSString *_database;

/**
 *
 */
@property (readwrite, retain, getter=table, setter=setTable:) NSString *_table; 

/**
 *
 */
@property (readwrite, retain, getter=parameters, setter=setParameters:) NSMutableArray *_parameters;

/**
 *
 */
@property (readwrite, retain, getter=fields, setter=setFields:) NSMutableArray *_fields;

/**
 *
 */
@property (readwrite, assign, getter=queryType, setter=setQueryType:) QKQueryType _queryType;

/**
 *
 */
@property (readwrite, assign, getter=quoteFields, setter=setQuoteFields:) BOOL _quoteFields;

+ (QKQuery *)queryTable:(NSString *)table;
+ (QKQuery *)selectQueryFromTable:(NSString *)table;

- (id)initWithTable:(NSString *)table;

- (NSString *)query;

- (void)addField:(NSString *)field;
- (void)addParameter:(NSString *)field operator:(QKQueryOperator *)op value:(id)value;

@end
