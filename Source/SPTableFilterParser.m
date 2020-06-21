//
//  SPTableFilterParser.m
//  sequel-pro
//
//  Created by Max Lohrmann on 22.04.15.
//  Relocated from existing files. Previous copyright applies.
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

#import "SPTableFilterParser.h"
#import "RegexKitLite.h"

@interface SPTableFilterParser ()
+ (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause;
@end

@implementation SPTableFilterParser

@synthesize suppressLeadingTablePlaceholder = suppressLeadingTablePlaceholder;
@synthesize caseSensitive                   = caseSensitive;
@synthesize currentField                    = _currentField;
@synthesize argument                        = _argument;
@synthesize firstBetweenArgument            = _firstBetweenArgument;
@synthesize secondBetweenArgument           = _secondBetweenArgument;
@synthesize numberOfArguments               = numberOfArguments;
@synthesize clause                          = _clause;

- (id)initWithFilterClause:(NSString *)filter numberOfArguments:(NSUInteger)numArgs
{
	self = [super init];
	if (self) {
		numberOfArguments               = numArgs;
		_clause                         = [filter copy];
		caseSensitive                   = NO;
		suppressLeadingTablePlaceholder = NO;
	}
	return self;
}

- (void)dealloc
{
	SPClear(_clause);
	
	[self setCurrentField:nil];
	[self setArgument:nil];
	[self setFirstBetweenArgument:nil];
	[self setSecondBetweenArgument:nil];
	
	[super dealloc];
}

- (NSString *)filterString
{
	// argument if Filter requires only one argument
	NSMutableString *argument = [[NSMutableString alloc] initWithString:(_argument? _argument : @"")];

	// arguments if Filter requires two arguments
	NSMutableString *firstBetweenArgument  = [[NSMutableString alloc] initWithString:(_firstBetweenArgument? _firstBetweenArgument : @"")];
	NSMutableString *secondBetweenArgument = [[NSMutableString alloc] initWithString:(_secondBetweenArgument? _secondBetweenArgument : @"")];
	
	// Retrieve actual WHERE clause
	NSMutableString *clause = [[NSMutableString alloc] init];
	[clause setString:_clause];
	
	[clause replaceOccurrencesOfRegex:@"(?<!\\\\)\\$BINARY " withString:(caseSensitive) ? @"BINARY " : @""];
	[clause flushCachedRegexData];
	[clause replaceOccurrencesOfRegex:@"(?<!\\\\)\\$CURRENT_FIELD" withString:(_currentField) ? [_currentField backtickQuotedString] : @""];
	[clause flushCachedRegexData];
	
	// Escape % sign for format insertion ie if number of arguments is greater than 0
	if(numberOfArguments > 0) [clause replaceOccurrencesOfRegex:@"%" withString:@"%%"];
	[clause flushCachedRegexData];
	
	// Replace placeholder ${} by %@
	NSRange matchedRange;
	NSString *re = @"(?<!\\\\)\\$\\{.*?\\}";
	if([clause isMatchedByRegex:re]) {
		while([clause isMatchedByRegex:re]) {
			matchedRange = [clause rangeOfRegex:re];
			[clause replaceCharactersInRange:matchedRange withString:@"%@"];
			[clause flushCachedRegexData];
		}
	}
	
	// Check number of placeholders and given 'NumberOfArguments'
	if([clause replaceOccurrencesOfString:@"%@" withString:@"%@" options:NSLiteralSearch range:NSMakeRange(0, [clause length])] != numberOfArguments) {
		SPLog(@"Error while setting filter string. “NumberOfArguments” differs from the number of arguments specified in “Clause”.");
		NSBeep();
		[argument release];
		[firstBetweenArgument release];
		[secondBetweenArgument release];
		[clause release];
		return nil;
	}
	
	// Construct the filter string according the required number of arguments
	NSMutableString *filterString = [NSMutableString string];

	if(!suppressLeadingTablePlaceholder) {
		[filterString appendFormat:@"%@ ",[_currentField backtickQuotedString]];
	}

	NSUInteger numArgs = numberOfArguments;
	if(numArgs > 2) {
		SPLog(@"Filter with more than 2 arguments is not yet supported.");
		NSBeep();
		numArgs = 2;
	}

	if (numArgs == 2) {
		[filterString appendFormat:clause,
		                           [[self class] escapeFilterArgument:firstBetweenArgument againstClause:clause],
		                           [[self class] escapeFilterArgument:secondBetweenArgument againstClause:clause]];
	} else if (numArgs == 1) {
		[filterString appendFormat:clause, [[self class] escapeFilterArgument:argument againstClause:clause]];
	} else {
		[filterString appendString:clause];
	}
	
	[argument release];
	[firstBetweenArgument release];
	[secondBetweenArgument release];
	[clause release];
	
	// Return the filter string
	return filterString;
}

/**
 * Escape argument by looking for used quoting strings in a clause.  Attempt to
 * be smart - use a single escape for most clauses, doubling up for LIKE clauses.
 * Also attempt to not escape what look like common escape sequences - \n, \r, \t.
 *
 * @param argument The to be used filter argument which should be be escaped
 *
 * @param clause The entire WHERE filter clause
 *
 */
+ (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause
{
	BOOL clauseIsLike = [clause isMatchedByRegex:@"(?i)\\blike\\b.*?%(?!@)"];
	NSString *recognizedEscapeSequences, *escapeSequence, *regexTerm;
	NSMutableString *arg = [argument mutableCopy];
	
	// Determine the character set not to escape slashes before, and the escape depth
	if (clauseIsLike) {
		recognizedEscapeSequences = @"nrt_%";
		escapeSequence = @"\\\\\\\\\\\\\\\\";
	} else {
		recognizedEscapeSequences = @"nrt";
		escapeSequence = @"\\\\\\\\";
	}
	regexTerm = [NSString stringWithFormat:@"(\\\\)(?![%@])", recognizedEscapeSequences];
	
	// Escape slashes appropriately
	[arg replaceOccurrencesOfRegex:regexTerm withString:escapeSequence];
	[arg flushCachedRegexData];
	
	// Get quote sign for escaping - this should work for 99% of all cases
	NSString *quoteSign = [clause stringByMatching:@"([\"'])[^\\1]*?%@[^\\1]*?\\1" capture:1L];
	
	// Escape argument
	if(quoteSign != nil && [quoteSign length] == 1) {
		[arg replaceOccurrencesOfRegex:[NSString stringWithFormat:@"(%@)", quoteSign] withString:@"\\\\$1"];
		[arg flushCachedRegexData];
	}
	
	return [arg autorelease];
}


@end
