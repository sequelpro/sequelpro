//
//  $Id: PGPostgresError.m 3837 2012-09-09 12:25:03Z stuart02 $
//
//  PGPostgresError.m
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

#import "PGPostgresError.h"
#import "PGPostgresException.h"

@interface PGPostgresError ()

- (void)_extractErrorDetailsFromResult:(const PGresult *)result;
- (NSString *)_extractErrorField:(int)field fromResult:(const PGresult *)result;

@end

@implementation PGPostgresError

@synthesize errorSeverity = _errorSeverity;
@synthesize errorStateCode = _errorStateCode;
@synthesize errorPrimaryMessage = _errorPrimaryMessage;
@synthesize errorDetailMessage = _errorDetailMessage;
@synthesize errorMessageHint = _errorMessageHint;
@synthesize errorStatementPosition = _errorStatementPosition;

#pragma mark -

- (id)init
{
	[PGPostgresException raise:NSInternalInconsistencyException 
						 reason:@"%@ shouldn't be init'd directly; use initWithResult: instead.", [self className]];
	
	return nil;
}

- (id)initWithResult:(const void *)result
{
	if ((self = [super init])) {
		
		_errorSeverity = nil;
		_errorStateCode = nil;
		_errorPrimaryMessage = nil;
		_errorDetailMessage = nil;
		_errorMessageHint = nil;
		_errorStatementPosition = -1;
		
		if (result) [self _extractErrorDetailsFromResult:(const PGresult *)result];
	}
	
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: Sev %@ (%@): %@>", [self className], _errorSeverity, _errorStateCode, _errorPrimaryMessage];
}

#pragma mark -
#pragma mark Private API

/**
 * Extracts all the error information from the supplied result.
 *
 * @param result The Postgres result to extract the information from.
 */
- (void)_extractErrorDetailsFromResult:(const PGresult *)result
{
	// Note that we don't expose all the fields that are available.
	// The ones we don't mostly include information internal to Postgres 
	// that generally isn't useful to end users.
	_errorSeverity = [self _extractErrorField:PG_DIAG_SEVERITY fromResult:result];
	_errorStateCode = [self _extractErrorField:PG_DIAG_SQLSTATE fromResult:result];
	_errorPrimaryMessage = [self _extractErrorField:PG_DIAG_MESSAGE_PRIMARY fromResult:result];
	_errorDetailMessage = [self _extractErrorField:PG_DIAG_MESSAGE_DETAIL fromResult:result];
	_errorMessageHint = [self _extractErrorField:PG_DIAG_MESSAGE_HINT fromResult:result];
	_errorStatementPosition = [[self _extractErrorField:PG_DIAG_STATEMENT_POSITION fromResult:result] integerValue];
}

/**
 * Extracts the supplied error field from the supplied Postgres result.
 *
 * @param field The error field to extract.
 * @param result The Postgres result to extract the field from.
 *
 * @return A string representing the error value. The caller is responsible for freeing the associated memory.
 */
- (NSString *)_extractErrorField:(int)field fromResult:(const PGresult *)result
{	
	const char *error = PQresultErrorField(result, field);
	
	return error ? [[[NSString alloc] initWithUTF8String:error] autorelease] : nil;
}

#pragma mark -

- (void)dealloc
{
	if (_errorSeverity) [_errorSeverity release], _errorSeverity = nil;
	if (_errorStateCode) [_errorStateCode release], _errorStateCode = nil;
	if (_errorPrimaryMessage) [_errorPrimaryMessage release], _errorPrimaryMessage = nil;
	if (_errorDetailMessage) [_errorDetailMessage release], _errorDetailMessage = nil;
	if (_errorMessageHint) [_errorMessageHint release], _errorMessageHint = nil;
	
	[super dealloc];
}

@end
