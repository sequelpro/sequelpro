//
//  SPViewCopy.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 3, 2012.
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
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPViewCopy.h"

#import <SPMySQL/SPMySQL.h>

@interface SPViewCopy ()

- (NSString *)_createViewStatementFor:(NSString *)view inDatabase:(NSString *)sourceDatabase;

@end

@implementation SPViewCopy

- (BOOL)moveView:(NSString *)view from:(NSString *)sourceDatabase to:(NSString *)targetDatabase
{
	NSMutableString *createStatement = [[NSMutableString alloc] initWithString:[self _createViewStatementFor:view inDatabase:sourceDatabase]];
	
	NSString *search = [NSString stringWithFormat:@"VIEW %@", [view backtickQuotedString]];

	NSRange range = [createStatement rangeOfString:search];
	
	if (range.location != NSNotFound) {
		
		NSUInteger replaced = [createStatement replaceOccurrencesOfString:search withString:[NSString stringWithFormat:@"VIEW %@.%@", [targetDatabase backtickQuotedString], [view backtickQuotedString]] options:0 range:range];
		
		if (replaced != 1) {
			[createStatement release];

			return NO;
		}
	
		// Replace all occurrences of the old database name
		[createStatement replaceOccurrencesOfString:[sourceDatabase backtickQuotedString]
										 withString:[targetDatabase backtickQuotedString]
											options:0
											  range:NSMakeRange(0, [createStatement length])];
		
		[connection queryString:createStatement];		
		
		[createStatement release];
				
		return ![connection queryErrored];
	}
	
	[createStatement release];
	
	return NO;
}

#pragma mark -
#pragma mark Private API

- (NSString *)_createViewStatementFor:(NSString *)view inDatabase:(NSString *)sourceDatabase 
{
	NSString *createStatement = [NSString stringWithFormat:@"SHOW CREATE VIEW %@.%@", [sourceDatabase backtickQuotedString], [view backtickQuotedString]];
	
	SPMySQLResult *theResult = [connection queryString:createStatement];
	
	return [theResult numberOfRows] > 0 ? [[theResult getRowAsArray] objectAtIndex:1] : @"";
}

@end
