//
//  $Id$
//
//  FLXPostgresTypeDateTimeHandler.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 1, 2012.
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

#import "FLXPostgresTypeDateTimeHandler.h"
#import "FLXPostgresConnection.h"

static FLXPostgresOid FLXPostgresTypeDateTimeTypes[] = 
{ 
	FLXPostgresOidAbsTime,
	FLXPostgresOidDate,
	FLXPostgresOidTime,
	FLXPostgresOidTimeTZ,
	0 
};

@implementation FLXPostgresTypeDateTimeHandler

#pragma mark -
#pragma mark Protocol Implementation

- (FLXPostgresOid *)remoteTypes 
{
	return FLXPostgresTypeDateTimeTypes;
}

- (Class)nativeClass 
{
	return [NSDate class];
}

- (NSArray *)classAliases
{
	return nil;
}

- (NSData *)remoteDataFromObject:(id)object type:(FLXPostgresOid *)type 
{
	if (!object || !type || ![object isKindOfClass:[NSDate class]]) return nil;
	
	return nil;
}

- (id)objectFromRemoteData:(const void *)bytes length:(NSUInteger)length type:(FLXPostgresOid)type 
{
	if (!bytes || !type) return nil;
	
	// TODO: Imeplement me!
	return nil;
}

- (NSString *)quotedStringFromObject:(id)object 
{
	if (!object || ![object isKindOfClass:[NSString class]]) return nil;
	
	// TODO: Imeplement me!
	return nil;
}

@end
