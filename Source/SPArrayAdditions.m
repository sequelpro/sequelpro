//
//  SPArrayAdditions.m
//  sequel-pro
//
//  Created by Jakob Egger on March 24, 2009.
//  Copyright (c) 2009 Jakob Egger. All rights reserved.
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

#import "SPArrayAdditions.h"

@implementation NSArray (SPArrayAdditions)

/*
 * This method quotes all elements with backticks and then joins them with
 * commas. Use it for field lists as in "SELECT (...) FROM somewhere"
 */
- (NSString *)componentsJoinedAndBacktickQuoted
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];
	
	for (NSString *component in self)
	{
		if ([result length])
			[result appendString: @", "];

		[result appendString:[component backtickQuotedString]];
	}
	return result;
}

- (NSString *)componentsJoinedByCommas
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];
	
	for (NSString *component in self)
	{
		if ([result length])
			[result appendString:@", "];

		[result appendString:component];
	}
	return result;
}

- (NSString *)componentsJoinedBySpacesAndQuoted
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];
	
	for (NSString *component in self)
	{
		if ([result length])
			[result appendString:@" "];

		[result appendFormat:@"\"%@\"", [component stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
	}
	return result;
}

- (NSString *)componentsJoinedByPeriodAndBacktickQuoted
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];
	
	for (NSString *component in self)
	{
		if ([result length])
			[result appendString: @"."];

		[result appendString:[component backtickQuotedString]];
	}
	return result;
}

- (NSString *)componentsJoinedByPeriodAndBacktickQuotedAndIgnoreFirst
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];
	BOOL notFirst = NO;
	for (NSString *component in self)
	{
		if ([result length])
			[result appendString: @"."];

		if (notFirst)
			[result appendString:[component backtickQuotedString]];

		notFirst = YES;
	}
	return result;
}

- (NSString *)componentsJoinedAsCSV
{
	NSMutableString *result = [NSMutableString string];
	[result setString:@""];

	for (NSString *component in self)
	{
		if ([result length])
			[result appendString: @","];
		[result appendFormat:@"\"%@\"", [[component description] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
	}
	return result;
}

- (NSArray *)subarrayWithIndexes:(NSIndexSet *)indexes
{
	NSMutableArray *subArray  = [NSMutableArray arrayWithCapacity:[indexes count]];
	NSUInteger count = [self count];

	[indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL * _Nonnull stop) {
		if ( index < count )
			[subArray addObject: [self objectAtIndex: index]];
	}];

	return subArray;
}

- (id)objectOrNilAtIndex:(NSUInteger)index
{
	if([self count] <= index)
		return nil;
	return [self objectAtIndex:index];
}

@end
