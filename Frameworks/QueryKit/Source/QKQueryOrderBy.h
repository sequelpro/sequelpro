//
//  $Id$
//
//  QKQueryOrderBy.h
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 15, 2012
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "QKQueryConstruct.h"

/**
 * @class QKQueryOrderBy QKQueryOrderBy.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * QueryKit SELECT query ORDER BY class.
 */
@interface QKQueryOrderBy : QKQueryConstruct 
{
	NSString *_orderByField;
	BOOL _orderByDescending;
}

/**
 * @property orderByField
 */
@property(readwrite, retain) NSString *orderByField;

/**
 * @property orderByDescending
 */
@property(readwrite, assign) BOOL orderByDescending;

+ (QKQueryOrderBy *)orderByField:(NSString *)field descending:(BOOL)descending;

- (id)initWithField:(NSString *)field descending:(BOOL)descending;

@end
