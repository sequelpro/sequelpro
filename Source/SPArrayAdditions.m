//
//  $Id$
//
//  SPArrayAdditions.m
//  sequel-pro
//
//  Created by Jakob Egger on March 24, 2009
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

#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"

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


- (NSArray *)subarrayWithIndexes:(NSIndexSet *)indexes
{
	NSMutableArray *subArray  = [NSMutableArray arrayWithCapacity:[indexes count]];
	NSUInteger count = [self count];

	NSUInteger index = [indexes firstIndex];
	while ( index != NSNotFound )
	{
		if ( index < count )
			[subArray addObject: [self objectAtIndex: index]];

		index = [indexes indexGreaterThanIndex: index];
	}

	return subArray;
}

@end
