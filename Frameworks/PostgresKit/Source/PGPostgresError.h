//
//  $Id: PGPostgresError.h 3800 2012-09-06 09:26:47Z stuart02 $
//
//  PGPostgresError.h
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 3, 2012.
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

@interface PGPostgresError : NSObject 
{
	NSString *_errorSeverity;
	NSString *_errorStateCode;
	NSString *_errorPrimaryMessage;
	NSString *_errorDetailMessage;
	NSString *_errorMessageHint;
	
	NSUInteger _errorStatementPosition;
}

/**
 * @property errorSeverity The severity of the error.
 */
@property (readonly) NSString *errorSeverity;

/**
 * @property errorStateCode The errors state code.
 */
@property (readonly) NSString *errorStateCode;

/**
 * @property errorPrimaryMessage The primary error message.
 */ 
@property (readonly) NSString *errorPrimaryMessage;

/**
 * @property errorDetailMessage The detailed error message.
 */
@property (readonly) NSString *errorDetailMessage;

/**
 * @property errorMessageHint The error message hint.
 */ 
@property (readonly) NSString *errorMessageHint;

/**
 * @property errorStatementPosition The position within the executed statement that caused the error.
 */ 
@property (readonly) NSUInteger errorStatementPosition;

- (id)initWithResult:(const void *)result;

@end
