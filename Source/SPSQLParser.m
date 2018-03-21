//
//  SPSQLParser.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 18, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
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

#import "SPSQLParser.h"
#import "RegexKitLite.h"

@interface SPSQLParser ()

- (unichar) _charAtIndex:(NSInteger)index;
- (void) _clearCharCache;

@end

/**
 * Define the length of the character cache to use when parsing instead of accessing
 * via characterAtIndex:.  There is a balance here between updating the cache very
 * often and access penalties; 1500 appears a reasonable compromise.
 */
#define CHARACTER_CACHE_LENGTH 1500

#define CHAR_SQUOTE '\''
#define CHAR_DQUOTE '"'
#define CHAR_BTICK '`'
#define CHAR_BS '\\'
#define CHAR_CR '\r'
#define CHAR_LF '\n'

#define STRING_SQUOTE @"'"
#define STRING_DQUOTE @"\""
#define STRING_BS @"\\"
#define STRING_LF @"\n"

/**
 * Please see the header files for a general description of the purpose of this class,
 * and increased overview detail for the functions below.
 */
@implementation SPSQLParser

#pragma mark -
#pragma mark Parser information

/**
 * Return whether any carriage returns have been encountered during
 * parsing; quoted strings are not included.  May be used to determine
 * whether text needs to be normalised.
 */
- (BOOL)containsCarriageReturns
{
	return containsCRs;
}

#pragma mark -
#pragma mark Parser behaviour setting

/**
 * Control whether comment strings should be skipped during parsing.
 */
- (void)setIgnoreCommentStrings:(BOOL)ignoringCommentStrings
{
	ignoreCommentStrings = ignoringCommentStrings;
}

/**
 * Control whether DELIMITER commands are recognised and used to override
 * supported characters.
 * When delimiter support is enabled, many string functions will start looking
 * for the delimiter *instead* of the supplied character, assuming that use
 * is looking for line endings.  This will be improved in future versions.
 */
- (void) setDelimiterSupport:(BOOL)shouldSupportDelimiters
{
	supportDelimiters = shouldSupportDelimiters;
}

- (void) setNoBackslashEscapes:(BOOL)ignoreBackslashEscapes
{
	noBackslashEscapes = ignoreBackslashEscapes;
}

#pragma mark -
#pragma mark SQL-aware utility methods

/**
 * Removes comments within the current string, trimming "#", "--[/s]", and "⁄* *⁄" style strings.
 */
- (void) deleteComments
{
	NSUInteger currentStringIndex, commentEndIndex, quotedStringEndIndex;
	unichar currentCharacter;
	NSUInteger stringLength = [string length];
	
	// Walk along the string, processing characters.
	for (currentStringIndex = 0; currentStringIndex < stringLength; currentStringIndex++) {
		currentCharacter = CFStringGetCharacterAtIndex((CFStringRef)string ,currentStringIndex);
		switch (currentCharacter) {

			// When quote characters are encountered walk to the end of the quoted string.
			case CHAR_SQUOTE:
			case CHAR_DQUOTE:
			case CHAR_BTICK:
				quotedStringEndIndex = [self endIndexOfStringQuotedByCharacter:currentCharacter startingAtIndex:currentStringIndex+1];
				if (quotedStringEndIndex == NSNotFound) {
					return;
				}
				currentStringIndex = quotedStringEndIndex;
				break;

			// For comments starting "--[\s]", ensure the start syntax is valid before proceeding.
			case '-':
				if (stringLength < currentStringIndex + 2) break;
				if (CFStringGetCharacterAtIndex((CFStringRef)string, currentStringIndex+1) != '-') break;
				if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)string, currentStringIndex+2)]) break;
				commentEndIndex = [self endIndexOfCommentOfType:SPDoubleDashComment startingAtIndex:currentStringIndex];
				
				// Remove the comment
				[self deleteCharactersInRange:NSMakeRange(currentStringIndex, commentEndIndex - currentStringIndex + 1)];
				stringLength -= commentEndIndex - currentStringIndex + 1;
				currentStringIndex--;
				break;

			case '#':
				commentEndIndex = [self endIndexOfCommentOfType:SPHashComment startingAtIndex:currentStringIndex];
				
				// Remove the comment
				[self deleteCharactersInRange:NSMakeRange(currentStringIndex, commentEndIndex - currentStringIndex + 1)];
				stringLength -= commentEndIndex - currentStringIndex + 1;
				currentStringIndex--;
				break;

			// For comments starting "/*", ensure the start syntax is valid before proceeding.
			case '/':
				if (stringLength < currentStringIndex + 1) break;
				if (CFStringGetCharacterAtIndex((CFStringRef)string, currentStringIndex+1) != '*') break;
				commentEndIndex = [self endIndexOfCommentOfType:SPCStyleComment startingAtIndex:currentStringIndex];
				
				// Remove the comment
				[self deleteCharactersInRange:NSMakeRange(currentStringIndex, commentEndIndex - currentStringIndex + 1)];
				stringLength -= commentEndIndex - currentStringIndex + 1;
				currentStringIndex--;
				break;
		}
	}
}

/**
 * Removes quotes surrounding the string if present, and un-escapes internal occurrences of the quote character before returning.
 */
- (NSString *) unquotedString
{
	NSMutableString *returnString;
	NSUInteger stringEndIndex;
	unichar quoteCharacter;

	if (![string length]) return nil;

	// If the first character is not a quote character, return the entire string.
	quoteCharacter = CFStringGetCharacterAtIndex((CFStringRef)string, 0);
	if (quoteCharacter != CHAR_BTICK && quoteCharacter != CHAR_DQUOTE && quoteCharacter != CHAR_SQUOTE) {
		return [NSString stringWithString:string];
	}

	// Get the end of the string
	stringEndIndex = [self endIndexOfStringQuotedByCharacter:quoteCharacter startingAtIndex:1];
	if (stringEndIndex == NSNotFound) {
		return [NSString stringWithString:string];
	}

	// Trim the string appropriately
	returnString = [NSMutableString stringWithString:[string substringWithRange:NSMakeRange(1, stringEndIndex-1)]];
	
	// Remove escaped characters and escaped strings as appropriate
	[returnString replaceOccurrencesOfString:[NSString stringWithFormat:@"%C%C", quoteCharacter, quoteCharacter] withString:[NSString stringWithFormat:@"%C", quoteCharacter] options:0 range:NSMakeRange(0, [returnString length])];

	if(!noBackslashEscapes) {
		if (quoteCharacter == CHAR_DQUOTE) {
			[returnString replaceOccurrencesOfString:(STRING_BS STRING_DQUOTE) withString:STRING_DQUOTE options:0 range:NSMakeRange(0, [returnString length])];
			[returnString replaceOccurrencesOfString:(STRING_BS STRING_BS) withString:STRING_BS options:0 range:NSMakeRange(0, [returnString length])];
		} else if (quoteCharacter == CHAR_SQUOTE) {
			[returnString replaceOccurrencesOfString:(STRING_BS STRING_SQUOTE) withString:STRING_SQUOTE options:0 range:NSMakeRange(0, [returnString length])];
			[returnString replaceOccurrencesOfString:(STRING_BS STRING_BS) withString:STRING_BS options:0 range:NSMakeRange(0, [returnString length])];
		}
	}

	return returnString;
}

/**
 * Normalise a string, readying it for queries - trims whitespace from both
 * ends, and ensures line endings which aren't in quotes are LF.
 */
+ (NSString *) normaliseQueryForExecution:(NSString *)queryString
{
	return [self normaliseQueryForExecution:queryString noBackslashEscapes:NO];
}

+ (NSString *) normaliseQueryForExecution:(NSString *)queryString noBackslashEscapes:(BOOL)noBackslashEscapes
{
	NSUInteger stringLength = [queryString length];
	NSCharacterSet *trimCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Check the ends of the string for whitespace, to determine if it needs removing
	NSUInteger whitespaceCharsAtStart = 0;
	NSUInteger whitespaceCharsAtEnd = 0;
	while (whitespaceCharsAtStart < stringLength && [trimCharset characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)queryString, whitespaceCharsAtStart)])
		whitespaceCharsAtStart++;
	while (whitespaceCharsAtEnd < stringLength && [trimCharset characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)queryString, stringLength - whitespaceCharsAtEnd - 1)])
		whitespaceCharsAtEnd++;

	// Trim if necessary
	if (whitespaceCharsAtStart || whitespaceCharsAtEnd) {
		stringLength -= whitespaceCharsAtStart + whitespaceCharsAtEnd;
		queryString = [queryString substringWithRange:NSMakeRange(whitespaceCharsAtStart, stringLength)];
	}

	// Check for carriage returns in the string
	NSMutableArray *carriageReturnPositions = [NSMutableArray array];
	for (NSUInteger currentStringIndex = 0; currentStringIndex < stringLength; currentStringIndex++) {
		unichar currentCharacter = CFStringGetCharacterAtIndex((CFStringRef)queryString, currentStringIndex);
		switch (currentCharacter) {

			// When quote characters are encountered walk to the end of the quoted string.
			case CHAR_SQUOTE:
			case CHAR_DQUOTE:
			case CHAR_BTICK:
			{
#warning duplicate code with -endIndexOfStringQuotedByCharacter:startingIndex:
				NSUInteger innerStringIndex;
				for (innerStringIndex = currentStringIndex + 1; innerStringIndex < stringLength; innerStringIndex++) {
					unichar innerCharacter = CFStringGetCharacterAtIndex((CFStringRef) queryString, innerStringIndex);

					// If the string end is a backtick and one has been encountered, treat it as end of string
					if (innerCharacter == CHAR_BTICK && currentCharacter == CHAR_BTICK) {

						// ...as long as the next character isn't also a backtick, in which case it's being quoted.  Skip both.
						if ((innerStringIndex + 1) < stringLength && CFStringGetCharacterAtIndex((CFStringRef) queryString, innerStringIndex + 1) == CHAR_BTICK) {
							innerStringIndex++;
							continue;
						}
						
						currentStringIndex = innerStringIndex;
						break;

					}
					// Otherwise, prepare to treat the string as ended when meeting the correct boundary character....
					else if (innerCharacter == currentCharacter) {

						// ...but only if the string end isn't escaped with an *odd* number of escaping characters...
						BOOL characterIsEscaped = NO;
						if (!noBackslashEscapes) {
							NSUInteger i = 1;
							NSUInteger quotedStringLength = innerStringIndex - 1;
							while ((quotedStringLength - i) > 0 && CFStringGetCharacterAtIndex((CFStringRef) queryString, innerStringIndex - i) == CHAR_BS) {
								characterIsEscaped = !characterIsEscaped;
								i++;
							}
						}

						// If an even number have been found, it may be the end of the string - as long as the subsequent character
						// isn't also the same character, in which case it's another form of escaping.
						if (!characterIsEscaped) {
							if ((innerStringIndex + 1) < stringLength && CFStringGetCharacterAtIndex((CFStringRef)queryString, innerStringIndex+1) == currentCharacter) {
								innerStringIndex++;
								continue;
							}

							// Really is the end of the string.
							currentStringIndex = innerStringIndex;
							break;
						}
					}
				}

				// The quoted string has been left open - end processing.
				currentStringIndex = innerStringIndex;
				break;
			}
			
			case CHAR_CR:
				[carriageReturnPositions addObject:@(currentStringIndex)];
				break;
		}
	}

	// If any CRs were found, iterate over them backwards, converting to LFs by replacing or subtracting as appropriate
	NSUInteger carriageReturnCount = [carriageReturnPositions count];
	if (carriageReturnCount) {
		NSMutableString *normalisedString = [NSMutableString stringWithString:queryString];
		while ( carriageReturnCount-- ) {
			NSUInteger CRLocation = [[carriageReturnPositions objectAtIndex:carriageReturnCount] unsignedIntegerValue];
			
			// Check whether it's a CRLF or just a CR
			BOOL isCRLF = NO;
			if ([normalisedString length] > CRLocation + 1 && CFStringGetCharacterAtIndex((CFStringRef)normalisedString, CRLocation + 1) == CHAR_LF) isCRLF = YES;

			// Normalise the line endings
			if (isCRLF) {
				[normalisedString deleteCharactersInRange:NSMakeRange(CRLocation, 1)];
			} else {
				[normalisedString replaceCharactersInRange:NSMakeRange(CRLocation, 1) withString:STRING_LF];
			}
		}
		queryString = normalisedString;
	}

	return queryString;
}

#pragma mark -
#pragma mark Trimming or retrieving strings from the front of the string

/**
 * Removes characters from the string up to the first occurrence of the supplied character.
 */
- (BOOL) trimToCharacter:(unichar)character inclusively:(BOOL)inclusive
{
	return [self trimToCharacter:character inclusively:inclusive ignoringQuotedStrings:YES];
}

/**
 * As trimToCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (BOOL) trimToCharacter:(unichar)character inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger stringIndex = -1;
	
	// Get the first occurrence of the specified character, returning NO if not found
	do {
		stringIndex = [self firstOccurrenceOfCharacter:character afterIndex:stringIndex ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && stringIndex != NSNotFound);
	if (stringIndex == NSNotFound) return NO;
	
	// If it has been found, trim the string appropriately and return YES
	[self deleteCharactersInRange:NSMakeRange(0, stringIndex + (inclusive?1:-delimiterLengthMinusOne))];
	return YES;
}

/**
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied character.
 */
- (NSString *) stringToCharacter:(unichar)character inclusively:(BOOL)inclusive
{
	return [self stringToCharacter:character inclusively:inclusive ignoringQuotedStrings:YES];
}

/**
 * As stringToCharacter: ..., but allows control over whether characters within quoted strings
 * are ignored.
 */
- (NSString *) stringToCharacter:(unichar)character inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings {
	NSUInteger stringIndex = -1;
	NSUInteger returnFromPosition;
	
	// Get the first occurrence of the specified character, returning nil if not found
	do {
		returnFromPosition = stringIndex + 1;
		stringIndex = [self firstOccurrenceOfCharacter:character afterIndex:stringIndex ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && stringIndex != NSNotFound);
	if (stringIndex == NSNotFound) return nil;
	
	// If it has been found, return the appropriate string range
	return [string substringWithRange:NSMakeRange(returnFromPosition, stringIndex + (inclusive?1:-delimiterLengthMinusOne) - returnFromPosition)];
}

/**
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied
 * character, also removing them from the string.
 */
- (NSString *) trimAndReturnStringToCharacter:(unichar)character trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn
{
	return [self trimAndReturnStringToCharacter:character trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn ignoringQuotedStrings:YES];
}

/**
 * As trimAndReturnStringToCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (NSString *) trimAndReturnStringToCharacter:(unichar)character trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger returnFromPosition;
	NSUInteger stringIndex = 0;
	NSString *resultString;

	if (character != parsedToChar) {
		parsedToChar = character;
		parsedToPosition = -1;
	}

	// Get the first occurrence of the specified character, returning nil if it could not be found
	do {
		returnFromPosition = stringIndex;
		stringIndex = [self firstOccurrenceOfCharacter:character afterIndex:parsedToPosition ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && stringIndex != NSNotFound);
	if (stringIndex == NSNotFound) return nil;

	// Select the appropriate string range, truncate the current string, and return the selected string
	resultString = [NSString stringWithString:[string substringWithRange:NSMakeRange(returnFromPosition, stringIndex + (inclusiveReturn?1:-delimiterLengthMinusOne) - returnFromPosition)]];
	[self deleteCharactersInRange:NSMakeRange(0, stringIndex + (inclusiveTrim?1:-delimiterLengthMinusOne))];
	return resultString;
}

#pragma mark -
#pragma mark Trimming or retrieving strings from one specified character to another

/**
 * Returns characters from the string up to and from the first occurrence of the supplied opening character
 * to the appropriate occurrence of the supplied closing character. "inclusively" controls whether the supplied
 * characters should also be returned.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:NO ignoringQuotedStrings:YES];
}

/**
 * As stringFromCharacter: toCharacter: ..., but allows control over whether to skip
 * over bracket-enclosed characters, as in subqueries, enums, definitions or groups
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive skippingBrackets:(BOOL)skipBrackets
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}

/**
 * As stringFromCharacter: toCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}

/**
 * As stringFromCharacter: toCharacter: ..., but allows control over both bracketing and quoting.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger toCharacterIndex, fromCharacterIndex = -1;

	// Look for the first occurrence of the from: character
	do {
		fromCharacterIndex = [self firstOccurrenceOfCharacter:fromCharacter afterIndex:fromCharacterIndex skippingBrackets:skipBrackets ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && fromCharacterIndex != NSNotFound);
	if (fromCharacterIndex == NSNotFound) return nil;
	
	// Look for the first/balancing occurrence of the to: character
	toCharacterIndex = fromCharacterIndex;
	do {
		toCharacterIndex = [self firstOccurrenceOfCharacter:toCharacter afterIndex:toCharacterIndex skippingBrackets:skipBrackets ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && toCharacterIndex != NSNotFound);
	if (toCharacterIndex == NSNotFound) return nil;
	
	// Return the correct part of the string.
	return [string substringWithRange:NSMakeRange(fromCharacterIndex + (inclusive?0:1), toCharacterIndex + (inclusive?1:-1) - fromCharacterIndex)];
}

/**
 * As stringFromCharacter: toCharacter: ..., but also trims the string up to the "to" character and
 * up to or including the "from" character, depending on whether "trimmingInclusively" is set.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:NO ignoringQuotedStrings:YES];
}

/**
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether to
 * skip over bracket-enclosed characters, as in subqueries, enums, definitions or groups.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn skippingBrackets:(BOOL)skipBrackets
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}


/**
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}


/**
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over both bracketing
 * and quoting.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger fromCharacterIndex = -1, toCharacterIndex;
	NSString *resultString;

	// Look for the first occurrence of the from: character
	do {
		fromCharacterIndex = [self firstOccurrenceOfCharacter:fromCharacter afterIndex:fromCharacterIndex skippingBrackets:skipBrackets ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && fromCharacterIndex != NSNotFound);
	if (fromCharacterIndex == NSNotFound) return nil;

	// Look for the first/balancing occurrence of the to: character
	toCharacterIndex = fromCharacterIndex;
	do {
		toCharacterIndex = [self firstOccurrenceOfCharacter:toCharacter afterIndex:toCharacterIndex skippingBrackets:skipBrackets ignoringQuotedStrings:ignoreQuotedStrings];
	} while (lastMatchIsDelimiter && toCharacterIndex != NSNotFound);
	if (toCharacterIndex == NSNotFound) return nil;
	
	// Select the correct part of the string, truncate the current string, and return the selected string.
	resultString = [string substringWithRange:NSMakeRange(fromCharacterIndex + (inclusiveReturn?0:1), toCharacterIndex + (inclusiveReturn?1:-1) - fromCharacterIndex)];
	[self deleteCharactersInRange:NSMakeRange(fromCharacterIndex + (inclusiveTrim?0:1), toCharacterIndex + (inclusiveTrim?1:-1) - fromCharacterIndex)];
	return resultString;
}

#pragma mark -
#pragma mark Splitting strings

/**
 * Split a string on the boundaries formed by the supplied character, returning an array of strings.
 */
- (NSArray *) splitStringByCharacter:(unichar)character
{
	return [self splitStringByCharacter:character skippingBrackets:NO ignoringQuotedStrings:YES];
}

/**
 * As splitStringByCharacter: ..., but allows control over whether to skip over bracket-enclosed
 * characters, as in subqueries, enums, definitions or groups.
 */
- (NSArray *) splitStringByCharacter:(unichar)character skippingBrackets:(BOOL)skipBrackets
{
	return [self splitStringByCharacter:character skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}

/**
 * As splitStringByCharacter:, but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSArray *) splitStringByCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self splitStringByCharacter:character skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}

/**
 * As splitStringByCharacter: ..., but allows control over both bracketing and quoting.
 */
- (NSArray *) splitStringByCharacter:(unichar)character skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSMutableArray *resultsArray = [NSMutableArray array];
	NSInteger stringIndex = -1;
	NSUInteger nextIndex = 0;
	NSInteger queryLength;

	IMP firstOccOfChar = [self methodForSelector:@selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:)];
	IMP subString = [string methodForSelector:@selector(substringWithRange:)];

	// Walk through the string finding the character to split by, and add all strings to the array.
	while (1) {
		nextIndex = (NSUInteger)(*firstOccOfChar)(self, @selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:), character, stringIndex, skipBrackets, ignoreQuotedStrings);
		while (lastMatchIsDelimiter && nextIndex != NSNotFound) {
			stringIndex = nextIndex;
			nextIndex = (NSUInteger)(*firstOccOfChar)(self, @selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:), character, stringIndex, skipBrackets, ignoreQuotedStrings);
		}
		if (nextIndex == NSNotFound)
			break;

		// Add queries to the result array if they have a length
		stringIndex++;
		queryLength = nextIndex - stringIndex - delimiterLengthMinusOne;
		if (queryLength > 0)
			CFArrayAppendValue((CFMutableArrayRef)resultsArray, (NSString *)(*subString)(string, @selector(substringWithRange:), NSMakeRange(stringIndex, queryLength)));

		stringIndex = nextIndex;
	}
	
	// Add the end of the string after the previously matched character where appropriate.
	if ((NSUInteger)(stringIndex + 1) < [string length]) {
		NSString *finalQuery = [[string substringFromIndex:stringIndex + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (supportDelimiters && [finalQuery isMatchedByRegex:@"(?i)^\\s*delimiter\\s+\\S+"])
			finalQuery = nil;
		if ([finalQuery length])
			[resultsArray addObject:finalQuery];
	}
	
	return resultsArray;
}

/**
 * As splitStringByCharacter:, but returning only the ranges of queries, stored as NSValues.
 */
- (NSArray *) splitStringIntoRangesByCharacter:(unichar)character
{
	NSMutableArray *resultsArray = [NSMutableArray array];
	NSInteger stringIndex = -1;
	NSUInteger nextIndex = 0;
	NSInteger queryLength;

	IMP firstOccOfChar = [self methodForSelector:@selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:)];

	// Walk through the string finding the character to split by, and add all ranges to the array.
	while (1) {
		nextIndex = (NSUInteger)(*firstOccOfChar)(self, @selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:), character, stringIndex, NO, YES);
		while (lastMatchIsDelimiter && nextIndex != NSNotFound) {
			stringIndex = nextIndex;
			nextIndex = (NSUInteger)(*firstOccOfChar)(self, @selector(firstOccurrenceOfCharacter:afterIndex:skippingBrackets:ignoringQuotedStrings:), character, stringIndex, NO, YES);
		}
		if (nextIndex == NSNotFound)
			break;

		// Add ranges to the result array if they have a length
		stringIndex++;
		queryLength = nextIndex - stringIndex - delimiterLengthMinusOne;
		if (queryLength > 0)
			CFArrayAppendValue((CFMutableArrayRef)resultsArray, [NSValue valueWithRange:NSMakeRange(stringIndex, queryLength)]);

		stringIndex = nextIndex;
	}
	
	// Add the end of the string after the previously matched character where appropriate.
	stringIndex++;
	if ((NSUInteger)stringIndex < [string length]) {
		NSString *finalQuery = [[string substringFromIndex:stringIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (supportDelimiters && [finalQuery isMatchedByRegex:@"(?i)^\\s*delimiter\\s+\\S+"])
			finalQuery = nil;
		if ([finalQuery length])
			[resultsArray addObject:[NSValue valueWithRange:NSMakeRange(stringIndex, [string length] - stringIndex)]];
	}

	return resultsArray;
}

#pragma mark -
#pragma mark SQL-aware character lookups (mostly for internal use)

/**
 * A shortcut method for looking up the first occurrence of a character in
 * the string.  Brackets aren't processed, quoted strings are processed according
 * to the supplied argument, and comments are processed according to the setting on
 * the object.
 */
- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self firstOccurrenceOfCharacter:character afterIndex:-1 skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}

/**
 * A shortcut method for looking up the first occurrence of a character in
 * the string after a specified start index.  Brackets aren't processed, quoted
 * strings are processed according to the supplied argument, and comments are
 * processed according to the setting on the object.
 */
- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character afterIndex:(NSInteger)startIndex ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self firstOccurrenceOfCharacter:character afterIndex:startIndex skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}

/**
 * Look for the first occurrence of a character, in SQL-aware form - with support
 * for skipping bracketed or quoted ranges.
 * Comments are also skipped depending on the setting for this object.
 * Mostly intended for internal use, but available externally.
 */
- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character afterIndex:(NSInteger)startIndex skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger currentStringIndex, quotedStringEndIndex;
	unichar currentCharacter;
	NSUInteger stringLength = [string length];
	NSInteger bracketingLevel = 0;
	lastMatchIsDelimiter = NO;

	// Cache frequently used selectors, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(_charAtIndex:)];
	SEL charAtIndexSEL = @selector(_charAtIndex:);
	IMP endIndex = [self methodForSelector:@selector(endIndexOfStringQuotedByCharacter:startingAtIndex:)];
	IMP substringWithRange = [self methodForSelector:@selector(substringWithRange:)];

	// Sanity check inputs
	if (startIndex < -1) startIndex = -1;

	// Walk along the string, processing characters
	for (currentStringIndex = startIndex + 1; currentStringIndex < stringLength; currentStringIndex++) {
		currentCharacter = (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex);

		// Check for the ending character, and if it has been found and quoting/brackets is valid, return.
		// If delimiter support is active and a delimiter is set, check for the delimiter
		if (supportDelimiters && delimiter) {
			if (currentStringIndex >= delimiterLengthMinusOne && [delimiter isEqualToString:(NSString *)(*substringWithRange)(self, @selector(substringWithRange:), NSMakeRange(currentStringIndex - delimiterLengthMinusOne, delimiterLengthMinusOne + 1))]) {
				if (!skipBrackets || bracketingLevel <= 0) {
					parsedToPosition = currentStringIndex;
					return currentStringIndex;
				}
			}
		} else if (currentCharacter == character) {
			if (!skipBrackets || bracketingLevel <= 0) {
				parsedToPosition = currentStringIndex;
				return currentStringIndex;
			}
		}

		// Process strings and comments as appropriate
		switch (currentCharacter) {

			// When quote characters are encountered and strings are not being ignored, walk to the end of the quoted string.
			case CHAR_SQUOTE:
			case CHAR_DQUOTE:
			case CHAR_BTICK:
				if (!ignoreQuotedStrings) break;
				quotedStringEndIndex = (NSUInteger)(*endIndex)(self, @selector(endIndexOfStringQuotedByCharacter:startingAtIndex:), currentCharacter, currentStringIndex+1);
				if (quotedStringEndIndex == NSNotFound) {
					parsedToPosition = stringLength - 1;
					return NSNotFound;
				}
				currentStringIndex = quotedStringEndIndex;
				break;

			// For opening brackets increment the bracket count
			case '(':
				bracketingLevel++;
				break;

			// For closing brackets decrement the bracket count
			case ')':
				bracketingLevel--;

			// For comments starting "--[\s]", ensure the start syntax is valid before proceeding.
			case '-':
				if (ignoreCommentStrings) break;
				if (stringLength < currentStringIndex + 2) break;
				if ((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+1) != '-') break;
				if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:(unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+2)]) break;
				currentStringIndex = [self endIndexOfCommentOfType:SPDoubleDashComment startingAtIndex:currentStringIndex];
				break;

			case '#':
				if (ignoreCommentStrings) break;
				currentStringIndex = [self endIndexOfCommentOfType:SPHashComment startingAtIndex:currentStringIndex];
				break;

			// For comments starting "/*", ensure the start syntax is valid before proceeding.
			case '/':
				if (ignoreCommentStrings) break;
				if (stringLength < currentStringIndex + 1) break;
				if ((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+1) != '*') break;
				currentStringIndex = [self endIndexOfCommentOfType:SPCStyleComment startingAtIndex:currentStringIndex];
				break;

			// Capture whether carriage returns are encountered
			case CHAR_CR:
				if (!containsCRs) containsCRs = YES;
				break;

			// Check for delimiter strings, by first checking letter-by-letter to "deli" for speed (as there's no default
			// commands which start with it), and then switching to regex for simplicty.
			case 'd':
			case 'D':

				// Only proceed if delimiter support is enabled and the remaining string is long enough,
				// and that the "d" is the start of a word
				if (supportDelimiters && stringLength >= currentStringIndex + 11
					&& (currentStringIndex == 0
						|| [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:(unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex-1)]))
				{
					switch((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+1)) {
						case 'e':
						case 'E':
						switch((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+2)) {
							case 'l':
							case 'L':
							switch((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+3)) {
								case 'i':
								case 'I':
									if([self isMatchedByRegex:@"^(delimiter[ \\t]+(\\S+))(?=\\s|\\Z)" 
													  options:RKLCaseless 
													  inRange:NSMakeRange(currentStringIndex, stringLength - currentStringIndex) 
														error:nil])
									{
										
										// Delimiter command found.  Extract the delimiter string itself
										NSArray *delimiterCommandParts = [[self arrayOfCaptureComponentsMatchedByRegex:@"(?i)^(delimiter[ \\t]+(\\S+))(?=\\s|\\Z)"
																			range:NSMakeRange(currentStringIndex, stringLength - currentStringIndex)] objectAtIndex:0];
										if (delimiter) [delimiter release];
										delimiter = [[NSString alloc] initWithString:[delimiterCommandParts objectAtIndex:2]];
										delimiterLengthMinusOne = [delimiter length] - 1;
										parsedToPosition = currentStringIndex + [(NSString*)[delimiterCommandParts objectAtIndex:1] length];
										
										// Drop back to standard non-delimiter mode if the delimiter has ended
										if ([delimiter isEqualToString:[NSString stringWithFormat:@"%C", character]]) {
											if (delimiter) SPClear(delimiter);
											delimiterLengthMinusOne = 0;
										}
										
										// With the internal state updated, return the match, clearly marked as a delimiter
										lastMatchIsDelimiter = YES;
										return parsedToPosition;
									}
								default: break;
							}
							default: break;
						}
					default: break;
				}
			}
		}
	}

	// If no matches have been made in this string, return NSNotFound.
	parsedToPosition = stringLength - 1;
	return NSNotFound;
}

/**
 * Walk along the string and locate the end of a quoted string, taking
 * into account the various forms of SQL escaping.
 * A method intended for use by the functions above.
 */
- (NSUInteger) endIndexOfStringQuotedByCharacter:(unichar)quoteCharacter startingAtIndex:(NSInteger)startIndex
{
	// Cache the charAtIndex selector, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(_charAtIndex:)];
	SEL charAtIndexSEL = @selector(_charAtIndex:);

	NSInteger stringLength = [string length];

	// Walk the string looking for the string end
	for (NSInteger currentStringIndex = startIndex; currentStringIndex < stringLength; currentStringIndex++) {
		unichar currentCharacter = (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex);

		// If the string end is a backtick and one has been encountered, treat it as end of string
		if (quoteCharacter == CHAR_BTICK && currentCharacter == CHAR_BTICK) {
		
			// ...as long as the next character isn't also a backtick, in which case it's being quoted.  Skip both.
			if ((currentStringIndex + 1) < stringLength && (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+1) == CHAR_BTICK) {
				currentStringIndex++;
				continue;
			}

			// Note: backslash+backtick is not an escape sequence inside a backtick string!
			//       i.e. »select `abc\`;« is a syntactically valid query. Some versions of the mysql CLI client
			//       have a bug though and will interpret \` as an escaped backtick.
			
			return currentStringIndex;
		}
		// Otherwise, prepare to treat the string as ended when meeting the correct boundary character....
		else if (currentCharacter == quoteCharacter) {

			// ...but only if the string end isn't escaped with an *odd* number of escaping characters...
			BOOL characterIsEscaped = NO;
			if(!noBackslashEscapes) {
				NSUInteger i = 1;
				NSUInteger quotedStringLength = currentStringIndex - 1;
				while ((quotedStringLength - i) > 0 && (unichar) (long) (*charAtIndex)(self, charAtIndexSEL, currentStringIndex - i) == CHAR_BS) {
					characterIsEscaped = !characterIsEscaped;
					i++;
				}
			}

			// If an even number have been found, it may be the end of the string - as long as the subsequent character
			// isn't also the same character, in which case it's another form of escaping.
			if (!characterIsEscaped) {
				if ((currentStringIndex + 1) < stringLength && (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, currentStringIndex+1) == quoteCharacter) {
					currentStringIndex++;
					continue;
				}

				// Really is the end of the string.
				return currentStringIndex;
			}
		}
	}

	return NSNotFound;
}

/**
 * A method intended for use by the functions above.
 */
- (NSUInteger) endIndexOfCommentOfType:(SPCommentType)commentType startingAtIndex:(NSInteger)anIndex
{
	NSInteger stringLength = [string length];
	unichar currentCharacter;

	// Cache the charAtIndex selector, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(_charAtIndex:)];
	SEL charAtIndexSEL = @selector(_charAtIndex:);

	switch (commentType) {
	
		// For comments of type "--[\s]", start the comment processing two characters in to match the start syntax,
		// then flow into the Hash comment handling (looking for first newline).
		case SPDoubleDashComment:
			anIndex = anIndex+2;
		
		// For comments starting "--[\s]" and "#", continue until the first newline.
		case SPHashComment:
			anIndex++;
			for ( ; anIndex < stringLength; anIndex++ ) {
				currentCharacter = (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, anIndex);
				if (currentCharacter == CHAR_CR) containsCRs = YES;
				if (currentCharacter == CHAR_CR || currentCharacter == CHAR_LF) {
					return anIndex-1;
				}
			}
			break;

		// For comments starting "/*", start the comment processing one character in to match the start syntax, then
		// continue until the first matching "*/".
		case SPCStyleComment:
			anIndex = anIndex+2;
			for ( ; anIndex < stringLength; anIndex++ ) {
				if ((unichar)(long)(*charAtIndex)(self, charAtIndexSEL, anIndex) == '*') {
					if ((stringLength > anIndex + 1) && (unichar)(long)(*charAtIndex)(self, charAtIndexSEL, anIndex+1) == '/') {
						return (anIndex+1);
					}
				}
			}
	}
	
	// If no match has been found, the comment must continue until the very end of the string.
	return (stringLength-1);
}

#pragma mark -
#pragma mark Required and primitive methods to allow subclassing the class cluster

- (id) init {

	if ((self = [super init])) {
		string = [[NSMutableString string] retain];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithBytes:(const void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithBytes:bytes length:length encoding:encoding];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding freeWhenDone:(BOOL)flag {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithBytesNoCopy:bytes length:length encoding:encoding freeWhenDone:flag];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCapacity:(NSUInteger)capacity {
	if ((self = [super init])) {
		string = [[NSMutableString stringWithCapacity:capacity] retain];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(BOOL)flag {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithCharactersNoCopy:characters length:length freeWhenDone:flag];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithContentsOfFile:(id)path {
	return [self initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}
- (id) initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding error:(NSError **)error {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithContentsOfFile:path encoding:encoding error:error];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCString:(const char *)nullTerminatedCString encoding:(NSStringEncoding)encoding {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithCString:nullTerminatedCString encoding:encoding];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithFormat:(NSString *)format, ... {
	va_list argList;
	va_start(argList, format);
	id str = [self initWithFormat:format arguments:argList];
	va_end(argList);
	[self initSQLExtensions];
	return str;
}
- (id) initWithFormat:(NSString *)format arguments:(va_list)argList {
	if ((self = [super init])) {
		string = [[NSMutableString alloc] initWithFormat:format arguments:argList];
	}
	[self initSQLExtensions];
	return self;
}
- (void) initSQLExtensions {
	parsedToChar = '\0';
	parsedToPosition = -1;
	charCacheEnd = -1;
	ignoreCommentStrings = NO;
	supportDelimiters = NO;
	delimiter = nil;
	delimiterLengthMinusOne = 0;
	lastMatchIsDelimiter = NO;
	containsCRs = NO;
	noBackslashEscapes = NO;
}
- (NSUInteger) length {
	return [string length];
}
- (unichar) characterAtIndex:(NSUInteger)anIndex {
	return CFStringGetCharacterAtIndex((CFStringRef)string, anIndex);
}
- (id) description {
	return [string description];
}
- (NSUInteger) replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSUInteger)options range:(NSRange)searchRange {
	return [string replaceOccurrencesOfString:target withString:replacement options:options range:searchRange];
	[self _clearCharCache];
}
- (void) setString:(NSString *)aString {
	[string setString:aString];
	if (delimiter) SPClear(delimiter);
	delimiterLengthMinusOne = 0;
	lastMatchIsDelimiter = NO;
	[self _clearCharCache];
}
- (void) replaceCharactersInRange:(NSRange)range withString:(NSString *)aString {
	[string replaceCharactersInRange:range withString:aString];
	[self _clearCharCache];
}
- (void) deleteCharactersInRange:(NSRange)aRange {
	[super deleteCharactersInRange:aRange];
	[self _clearCharCache];
}
- (void) insertString:(NSString *)aString atIndex:(NSUInteger)anIndex {
	[super insertString:aString atIndex:anIndex];
	[self _clearCharCache];
}
- (void) dealloc {
	SPClear(string);
	if (delimiter) SPClear(delimiter);
	if (charCacheEnd != -1) free(stringCharCache);
	[super dealloc];
}

#pragma mark - Private API

/**
 * Provide a method to retrieve a character from the local cache.
 * Does no bounds checking on the underlying string, and so is kept
 * separate from characterAtIndex:.
 */
- (unichar) _charAtIndex:(NSInteger)anIndex
{

	// If the current cache doesn't include the current character, update it.
	if (anIndex > charCacheEnd || anIndex < charCacheStart) {
		if (charCacheEnd > -1) {
			free(stringCharCache);
		}
		NSUInteger remainingStringLength = [string length] - anIndex;
		NSUInteger newcachelength = (CHARACTER_CACHE_LENGTH < remainingStringLength)?CHARACTER_CACHE_LENGTH:remainingStringLength;
		stringCharCache = (unichar *)calloc(newcachelength, sizeof(unichar));
		CFStringGetCharacters((CFStringRef)string, CFRangeMake(anIndex, newcachelength), stringCharCache);
		charCacheEnd = anIndex + newcachelength - 1;
		charCacheStart = anIndex;
	}
	return stringCharCache[anIndex - charCacheStart];
}

/**
 * Provide a method to clear the cache, which should be used whenever
 * the underlying string is updated.
 */
- (void) _clearCharCache
{
	if (charCacheEnd > -1) {
		free(stringCharCache);
	}
	charCacheEnd = -1;
	charCacheStart = 0;
	parsedToChar = '\0';
	parsedToPosition = -1;
}

@end
