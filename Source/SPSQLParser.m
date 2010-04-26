//
//  $Id$
//
//  SPSQLParsing.m
//  sequel-pro
//
//  Created by Rowan Beentje on 18/01/2009.
//  Copyright 2009 Rowan Beentje. All rights reserved.
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

#import "SPSQLParser.h"
#import "RegexKitLite.h"

/*
 * Include all the extern variables and prototypes required for flex (used for syntax highlighting)
 */
#import "SPSQLTokenizer.h"
extern NSInteger tolex();
extern NSInteger yyuoffset, yyuleng;
typedef struct to_buffer_state *TO_BUFFER_STATE;
void to_switch_to_buffer(TO_BUFFER_STATE);
TO_BUFFER_STATE to_scan_string (const char *);

/*
 * Please see the header files for a general description of the purpose of this class,
 * and increased overview detail for the functions below.
 */
@implementation SPSQLParser : NSMutableString

/*
 * Control whether comment strings should be skipped during parsing.
 */
- (void)setIgnoreCommentStrings:(BOOL)ignoringCommentStrings
{
	ignoreCommentStrings = ignoringCommentStrings;
}

/*
 * Control whether DELIMITER commands are recognised and used to override
 * supported characters.
 */
- (void) setDelimiterSupport:(BOOL)shouldSupportDelimiters
{
	supportDelimiters = shouldSupportDelimiters;
}


/*
 * Removes comments within the current string, trimming "#", "--[/s]", and "⁄* *⁄" style strings.
 */
- (void) deleteComments
{
	NSUInteger currentStringIndex, commentEndIndex, quotedStringEndIndex;
	unichar currentCharacter;
	NSUInteger stringLength = [string length];
	
	// Walk along the string, processing characters.
	for (currentStringIndex = 0; currentStringIndex < stringLength; currentStringIndex++) {
		currentCharacter = [string characterAtIndex:currentStringIndex];
		switch (currentCharacter) {

			// When quote characters are encountered walk to the end of the quoted string.
			case '\'':
			case '"':
			case '`':
				quotedStringEndIndex = [self endIndexOfStringQuotedByCharacter:currentCharacter startingAtIndex:currentStringIndex+1];
				if (quotedStringEndIndex == NSNotFound) {
					return;
				}
				currentStringIndex = quotedStringEndIndex;
				break;

			// For comments starting "--[\s]", ensure the start syntax is valid before proceeding.
			case '-':
				if (stringLength < currentStringIndex + 2) break;
				if ([string characterAtIndex:currentStringIndex+1] != '-') break;
				if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:[string characterAtIndex:currentStringIndex+2]]) break;
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
				if ([string characterAtIndex:currentStringIndex+1] != '*') break;
				commentEndIndex = [self endIndexOfCommentOfType:SPCStyleComment startingAtIndex:currentStringIndex];
				
				// Remove the comment
				[self deleteCharactersInRange:NSMakeRange(currentStringIndex, commentEndIndex - currentStringIndex + 1)];
				stringLength -= commentEndIndex - currentStringIndex + 1;
				currentStringIndex--;
				break;
		}
	}
}


/*
 * Removes quotes surrounding the string if present, and un-escapes internal occurrences of the quote character before returning.
 */
- (NSString *) unquotedString
{
	NSMutableString *returnString;
	NSUInteger stringEndIndex;
	unichar quoteCharacter;

	if (![string length]) return nil;

	// If the first character is not a quote character, return the entire string.
	quoteCharacter = [string characterAtIndex:0];
	if (quoteCharacter != '`' && quoteCharacter != '"' && quoteCharacter != '\'') {
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
	if (quoteCharacter == '`' || quoteCharacter == '"' || quoteCharacter == '\'') {
		[returnString replaceOccurrencesOfString:[NSString stringWithFormat:@"%C%C", quoteCharacter, quoteCharacter] withString:[NSString stringWithFormat:@"%C", quoteCharacter] options:0 range:NSMakeRange(0, [returnString length])];
	}
	if (quoteCharacter == '"') {
		[returnString replaceOccurrencesOfString:@"\\\"" withString:@"\"" options:0 range:NSMakeRange(0, [returnString length])];
		[returnString replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:0 range:NSMakeRange(0, [returnString length])];
	} else	if (quoteCharacter == '\'') {
		[returnString replaceOccurrencesOfString:@"\\'" withString:@"'" options:0 range:NSMakeRange(0, [returnString length])];
		[returnString replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:0 range:NSMakeRange(0, [returnString length])];
	}

	return returnString;
}


/*
 * Removes characters from the string up to the first occurrence of the supplied character.
 */
- (BOOL) trimToCharacter:(unichar)character inclusively:(BOOL)inclusive
{
	return [self trimToCharacter:character inclusively:inclusive ignoringQuotedStrings:YES];
}


/*
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
	[self deleteCharactersInRange:NSMakeRange(0, stringIndex + (inclusive?1:0))];
	return YES;
}


/*
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied character.
 */
- (NSString *) stringToCharacter:(unichar)character inclusively:(BOOL)inclusive
{
	return [self stringToCharacter:character inclusively:inclusive ignoringQuotedStrings:YES];
}


/*
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
	return [string substringWithRange:NSMakeRange(returnFromPosition, stringIndex + (inclusive?1:0) - returnFromPosition)];
}


/*
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied
 * character, also removing them from the string.
 */
- (NSString *) trimAndReturnStringToCharacter:(unichar)character trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn
{
	return [self trimAndReturnStringToCharacter:character trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn ignoringQuotedStrings:YES];
}


/*
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
	resultString = [NSString stringWithString:[string substringWithRange:NSMakeRange(returnFromPosition, stringIndex + (inclusiveReturn?1:0) - returnFromPosition)]];
	[self deleteCharactersInRange:NSMakeRange(0, stringIndex + (inclusiveTrim?1:0))];
	return resultString;
}


/*
 * Returns characters from the string up to and from the first occurrence of the supplied opening character
 * to the appropriate occurrence of the supplied closing character. "inclusively" controls whether the supplied
 * characters should also be returned.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:NO ignoringQuotedStrings:YES];
}


/*
 * As stringFromCharacter: toCharacter: ..., but allows control over whether to skip
 * over bracket-enclosed characters, as in subqueries, enums, definitions or groups
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive skippingBrackets:(BOOL)skipBrackets
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}


/*
 * As stringFromCharacter: toCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self stringFromCharacter:fromCharacter toCharacter:toCharacter inclusively:inclusive skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}


/*
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


/*
 * As stringFromCharacter: toCharacter: ..., but also trims the string up to the "to" character and
 * up to or including the "from" character, depending on whether "trimmingInclusively" is set.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:NO ignoringQuotedStrings:YES];
}


/*
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether to
 * skip over bracket-enclosed characters, as in subqueries, enums, definitions or groups.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn skippingBrackets:(BOOL)skipBrackets
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}


/*
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self trimAndReturnStringFromCharacter:fromCharacter toCharacter:toCharacter trimmingInclusively:inclusiveTrim returningInclusively:inclusiveReturn skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}


/*
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

/*
 * Split a string on the boundaries formed by the supplied character, returning an array of strings.
 */
- (NSArray *) splitStringByCharacter:(unichar)character
{
	return [self splitStringByCharacter:character skippingBrackets:NO ignoringQuotedStrings:YES];
}

/*
 * As splitStringByCharacter: ..., but allows control over whether to skip over bracket-enclosed
 * characters, as in subqueries, enums, definitions or groups.
 */
- (NSArray *) splitStringByCharacter:(unichar)character skippingBrackets:(BOOL)skipBrackets
{
	return [self splitStringByCharacter:character skippingBrackets:skipBrackets ignoringQuotedStrings:YES];
}


/*
 * As splitStringByCharacter:, but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSArray *) splitStringByCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self splitStringByCharacter:character skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}

/*
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
	if (stringIndex + 1 < [string length]) {
		NSString *finalQuery = [[string substringFromIndex:stringIndex + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (supportDelimiters && [finalQuery isMatchedByRegex:@"(?i)^\\s*delimiter\\s+\\S+"])
			finalQuery = nil;
		if ([finalQuery length])
			[resultsArray addObject:finalQuery];
	}
	
	return resultsArray;
}


/*
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
	if (stringIndex < [string length]) {
		NSString *finalQuery = [[string substringFromIndex:stringIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (supportDelimiters && [finalQuery isMatchedByRegex:@"(?i)^\\s*delimiter\\s+\\S+"])
			finalQuery = nil;
		if ([finalQuery length])
			[resultsArray addObject:[NSValue valueWithRange:NSMakeRange(stringIndex, [string length] - stringIndex - delimiterLengthMinusOne)]];
	}

	return resultsArray;
}


/*
 * A method intended for use by the functions above.
 */
- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self firstOccurrenceOfCharacter:character afterIndex:-1 skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}


/*
 * A method intended for use by the functions above.
 */
- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character afterIndex:(NSInteger)startIndex ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	return [self firstOccurrenceOfCharacter:character afterIndex:startIndex skippingBrackets:NO ignoringQuotedStrings:ignoreQuotedStrings];
}


- (NSUInteger) firstOccurrenceOfCharacter:(unichar)character afterIndex:(NSInteger)startIndex skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings
{
	NSUInteger currentStringIndex, quotedStringEndIndex;
	unichar currentCharacter;
	NSUInteger stringLength = [string length];
	NSInteger bracketingLevel = 0;
	lastMatchIsDelimiter = NO;

	// Cache frequently used selectors, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(charAtIndex:)];
	IMP endIndex = [self methodForSelector:@selector(endIndexOfStringQuotedByCharacter:startingAtIndex:)];
	IMP substringWithRange = [self methodForSelector:@selector(substringWithRange:)];

	// Sanity check inputs
	if (startIndex < -1) startIndex = -1;

	// Walk along the string, processing characters
	for (currentStringIndex = startIndex + 1; currentStringIndex < stringLength; currentStringIndex++) {
		currentCharacter = (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex);

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
			case '\'':
			case '"':
			case '`':
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
				if (stringLength < currentStringIndex + 2) break;
				if ((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+1) != '-') break;
				if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:(unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+2)]) break;
				currentStringIndex = [self endIndexOfCommentOfType:SPDoubleDashComment startingAtIndex:currentStringIndex];
				break;

			case '#':
				if(ignoreCommentStrings) break;
				currentStringIndex = [self endIndexOfCommentOfType:SPHashComment startingAtIndex:currentStringIndex];
				break;

			// For comments starting "/*", ensure the start syntax is valid before proceeding.
			case '/':
				if(ignoreCommentStrings) break;
				if (stringLength < currentStringIndex + 1) break;
				if ((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+1) != '*') break;
				currentStringIndex = [self endIndexOfCommentOfType:SPCStyleComment startingAtIndex:currentStringIndex];
				break;

			// Check for delimiter strings, by first checking letter-by-letter to "deli" for speed (as there's no default
			// commands which start with it), and then switching to regex for simplicty.
			case 'd':
			case 'D':

				// Only proceed if delimiter support is enabled and the remaining string is long enough,
				// and that the "d" is the start of a word
				if (supportDelimiters && stringLength >= currentStringIndex + 11
					&& (currentStringIndex == 0
						|| [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:(unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex-1)]))
				{
					switch((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+1)) {
						case 'e':
						case 'E':
						switch((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+2)) {
							case 'l':
							case 'L':
							switch((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+3)) {
								case 'i':
								case 'I':
									if([self isMatchedByRegex:@"^(delimiter[ \\t]+(\\S+))(?=\\s)" 
													  options:RKLCaseless 
													  inRange:NSMakeRange(currentStringIndex, stringLength - currentStringIndex) 
														error:nil])
									{
										
										// Delimiter command found.  Extract the delimiter string itself
										NSArray *delimiterCommandParts = [[self arrayOfCaptureComponentsMatchedByRegex:@"(?i)^(delimiter[ \\t]+(\\S+))(?=\\s)"
																			range:NSMakeRange(currentStringIndex, stringLength - currentStringIndex)] objectAtIndex:0];
										delimiter = [delimiterCommandParts objectAtIndex:2];
										delimiterLengthMinusOne = [delimiter length] - 1;
										parsedToPosition = currentStringIndex + [[delimiterCommandParts objectAtIndex:1] length];
										
										// Drop back to standard non-delimiter mode if the delimiter has ended
										if ([delimiter isEqualToString:[NSString stringWithFormat:@"%C", character]]) {
											delimiter = nil;
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


/*
 * A method intended for use by the functions above.
 */
- (NSUInteger) endIndexOfStringQuotedByCharacter:(unichar)quoteCharacter startingAtIndex:(NSInteger)index
{
	NSInteger currentStringIndex;
	NSUInteger stringLength, i, quotedStringLength;
	BOOL characterIsEscaped;
	unichar currentCharacter;

	// Cache the charAtIndex selector, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(charAtIndex:)];

	stringLength = [string length];

	// Walk the string looking for the string end
	for ( currentStringIndex = index; currentStringIndex < stringLength; currentStringIndex++) {
		currentCharacter = (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex);

		// If the string end is a backtick and one has been encountered, treat it as end of string
		if (quoteCharacter == '`' && currentCharacter == '`') {
		
			// ...as long as the next character isn't also a backtick, in which case it's being quoted.  Skip both.
			if ((currentStringIndex + 1) < stringLength && (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+1) == '`') {
				currentStringIndex++;
				continue;
			}
			
			return currentStringIndex;

		// Otherwise, prepare to treat the string as ended when meeting the correct boundary character....
		} else if (currentCharacter == quoteCharacter) {

			// ...but only if the string end isn't escaped with an *odd* number of escaping characters...
			characterIsEscaped = NO;
			i = 1;
			quotedStringLength = currentStringIndex - 1;
			while ((quotedStringLength - i) > 0 && (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex - i) == '\\') {
				characterIsEscaped = !characterIsEscaped;
				i++;
			}

			// If an even number have been found, it may be the end of the string - as long as the subsequent character
			// isn't also the same character, in which case it's another form of escaping.
			if (!characterIsEscaped) {
				if ((currentStringIndex + 1) < stringLength && (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), currentStringIndex+1) == quoteCharacter) {
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

/*
 * A method intended for use by the functions above.
 */
- (NSUInteger) endIndexOfCommentOfType:(SPCommentType)commentType startingAtIndex:(NSInteger)index
{
	NSUInteger stringLength = [string length];
	unichar currentCharacter;

	// Cache the charAtIndex selector, avoiding dynamic binding overhead
	IMP charAtIndex = [self methodForSelector:@selector(charAtIndex:)];

	switch (commentType) {
	
		// For comments of type "--[\s]", start the comment processing two characters in to match the start syntax,
		// then flow into the Hash comment handling (looking for first newline).
		case SPDoubleDashComment:
			index = index+2;
		
		// For comments starting "--[\s]" and "#", continue until the first newline.
		case SPHashComment:
			index++;
			for ( ; index < stringLength; index++ ) {
				currentCharacter = (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), index);
				if (currentCharacter == '\r' || currentCharacter == '\n') {
					return index-1;
				}
			}
			break;

		// For comments starting "/*", start the comment processing one character in to match the start syntax, then
		// continue until the first matching "*/".
		case SPCStyleComment:
			index = index+2;
			for ( ; index < stringLength; index++ ) {
				if ((unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), index) == '*') {
					if ((stringLength > index + 1) && (unichar)(long)(*charAtIndex)(self, @selector(charAtIndex:), index+1) == '/') {
						return (index+1);
					}
				}
			}
	}
	
	// If no match has been found, the comment must continue until the very end of the string.
	return (stringLength-1);
}

/*
 * Provide a method to retrieve a character from the local cache.
 * Does no bounds checking on the underlying string, and so is kept
 * separate for characterAtIndex:.
 */
- (unichar) charAtIndex:(NSInteger)index
{

	// If the current cache doesn't include the current character, update it.
	if (index > charCacheEnd || index < charCacheStart) {
		if (charCacheEnd > -1) {
			free(stringCharCache);
		}
		NSUInteger remainingStringLength = [string length] - index;
		NSUInteger newcachelength = (CHARACTER_CACHE_LENGTH < remainingStringLength)?CHARACTER_CACHE_LENGTH:remainingStringLength;
		stringCharCache = (unichar *)calloc(newcachelength, sizeof(unichar));
		[string getCharacters:stringCharCache range:NSMakeRange(index, newcachelength)];
		charCacheEnd = index + newcachelength - 1;
		charCacheStart = index;
	}
	return stringCharCache[index - charCacheStart];
}

/*
 * Provide a method to cleat the cache, and use it when updating the string.
 */
- (void) clearCharCache
{
	if (charCacheEnd > -1) {
		free(stringCharCache);
	}
	charCacheEnd = -1;
	charCacheStart = 0;
	parsedToChar = '\0';
	parsedToPosition = -1;
}
- (void) deleteCharactersInRange:(NSRange)aRange
{
	[super deleteCharactersInRange:aRange];
	[self clearCharCache];
}
- (void) insertString:(NSString *)aString atIndex:(NSUInteger)anIndex
{
	[super insertString:aString atIndex:anIndex];
	[self clearCharCache];
}

/* Required and primitive methods to allow subclassing class cluster */
#pragma mark -
- (id) init {

	if (self = [super init]) {
		string = [[NSMutableString string] retain];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithBytes:(const void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding {
	if (self = [super init]) {
		string = [[NSMutableString alloc] initWithBytes:bytes length:length encoding:encoding];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding freeWhenDone:(BOOL)flag {
	if (self = [super init]) {
		string = [[NSMutableString alloc] initWithBytesNoCopy:bytes length:length encoding:encoding freeWhenDone:flag];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCapacity:(NSUInteger)capacity {
	if (self = [super init]) {
		string = [[NSMutableString stringWithCapacity:capacity] retain];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCharactersNoCopy:(unichar *)characters length:(NSUInteger)length freeWhenDone:(BOOL)flag {
	if (self = [super init]) {
		string = [[NSMutableString alloc] initWithCharactersNoCopy:characters length:length freeWhenDone:flag];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithContentsOfFile:(id)path {
	return [self initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}
- (id) initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding error:(NSError **)error {
	if (self = [super init]) {
		string = [[NSMutableString alloc] initWithContentsOfFile:path encoding:encoding error:error];
	}
	[self initSQLExtensions];
	return self;
}
- (id) initWithCString:(const char *)nullTerminatedCString encoding:(NSStringEncoding)encoding {
	if (self = [super init]) {
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
	if (self = [super init]) {
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
	
}
- (NSUInteger) length {
	return [string length];
}
- (unichar) characterAtIndex:(NSUInteger)index {
	return [string characterAtIndex:index];
}
- (id) description {
	return [string description];
}
- (NSUInteger) replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSUInteger)options range:(NSRange)searchRange {
	return [string replaceOccurrencesOfString:target withString:replacement options:options range:searchRange];
	[self clearCharCache];
}
- (void) setString:(NSString *)aString {
	[string setString:aString];
	delimiter = nil;
	delimiterLengthMinusOne = 0;
	lastMatchIsDelimiter = NO;
	[self clearCharCache];
}
- (void) replaceCharactersInRange:(NSRange)range withString:(NSString *)aString {
	[string replaceCharactersInRange:range withString:aString];
	[self clearCharCache];
}
- (void) dealloc {
	[string release];
	if (charCacheEnd != -1) free(stringCharCache);
	[super dealloc];
}

@end
