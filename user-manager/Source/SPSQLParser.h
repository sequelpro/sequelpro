//
//  SPSQLParsing.h
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

#import <Cocoa/Cocoa.h>


/*
 * This class provides a string class intended for SQL parsing.  It extends NSMutableString,
 * with the intention that as a string is parsed the parsed content is removed.  This also
 * allows parsing to occur in "streaming" mode, with parseable content being pulled off the
 * start of the string as additional content is appended onto the end of the string, eg from
 * a file.
 *
 * While some methods may look similar to NSScanner methods, and others look like they could be
 * achieved with Regex libraries or other string parsing libraries, this class was written with
 * the following goals in mind:
 *  - SQL comments, in "/* ... * /", "#" and "--[\s]" form, are ignored automatically while parsing -
        *but* are left in the strings in question, to allow (for example) MySQL-version specific query
		support, eg /*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT * /
 *  - Support for quoted strings in most commands, allowing strings quoted with ", ', and ` characters -
        including support for \-escaping of the quote characters within "- and '-terminated strings.
 *  - Optional support for bracket capturing in most commands.  This can allow simpler parsing of strings
        which also contain subqueries, enums, definitions or groups.
 *  - Speed should remain high even on large strings due to specific context awareness (ie no reliance
 *      on complex lookaheads or lookbehinds to achieve the above).
 *
 * It is anticipated that characterAtIndex: is currently the parsing weak point, and that in future
 * this class could be further optimised by working with the underlying object/characters directly.
 * This class could also be improved by maintaining an internal parsedTo number to allow streaming
 * processing to occur without repetition.
 */

@interface SPSQLParser : NSMutableString
{
	id string;
}


typedef enum _SPCommentTypes {
	SPHashComment = 0,
	SPDoubleDashComment = 1,
	SPCStyleComment = 2
} SPCommentType;


/*
 * Removes comments within the current string, trimming "#", "--[/s]", and "/* * /" style strings.
 */
- (void) deleteComments;

/*
 * Removes quotes surrounding the string if present, and un-escapes internal occurrences of the quote character,
 * before returning the resulting string.
 * If no quotes surround the current string, return the entire string; if the current string contains several
 * quoted strings, the first will be returned.
 */
- (NSString *) unquotedString;

/*
 * Removes characters from the string up to the first occurrence of the supplied character.
 * "inclusively" controls whether the supplied character is also removed.
 * Quoted strings are automatically ignored when looking for the character.
 * SQL comments are automatically ignored when looking for the character.
 * Returns YES if this caused the string to be shortened, or NO if the character was not encountered.
 */
- (BOOL) trimToCharacter:(unichar)character inclusively:(BOOL)inclusive;

/* 
 * As trimToCharacter: ..., but allows control over whether characters within quoted strings
 * are ignored.
 */
- (BOOL) trimToCharacter:(unichar)character inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied character.
 * "inclusively" controls whether the supplied character is also returned.
 * Quoted strings are automatically ignored when looking for the character.
 * SQL comments are automatically ignored when looking for the character.
 * If the character is not found, nil is returned.
 */
- (NSString *) stringToCharacter:(unichar)character inclusively:(BOOL)inclusive;

/*
 * As stringToCharacter: ..., but allows control over whether characters within quoted strings
 * are ignored.
 */
- (NSString *) stringToCharacter:(unichar)character inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * Returns an NSString containing characters from the string up to the first occurrence of the supplied
 * character, also removing them from the string.  "trimmingInclusively" controls whether or not the
 * supplied character is removed from the string on a successful match, while "returningInclusively"
 * controls whether it is included in the returned string.
 * Quoted strings are automatically ignored when looking for the characters.
 * SQL comments are automatically ignored when looking for the characters.
 * If the character is not found, nil is returned.
 */
- (NSString *) trimAndReturnStringToCharacter:(unichar)character trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn;

/*
 * As trimAndReturnStringToCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (NSString *) trimAndReturnStringToCharacter:(unichar)character trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * Returns characters from the string up to and from the first occurrence of the supplied opening character
 * to the appropriate occurrence of the supplied closing character. "inclusively" controls whether the supplied
 * characters should also be returned.
 * Quoted strings are automatically ignored when looking for the characters.
 * SQL comments are automatically ignored when looking for the characters.
 * Returns nil if no valid matching string can be found.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive;

/*
 * As stringFromCharacter: toCharacter: ..., but allows control over whether to skip
 * over bracket-enclosed characters, as in subqueries, enums, definitions or groups
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive skippingBrackets:(BOOL)skipBrackets;

/*
 * As stringFromCharacter: toCharacter: ..., but allows control over whether characters within quoted
 * strings are ignored.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * As stringFromCharacter: toCharacter: ..., but allows control over both bracketing and quoting.
 */
- (NSString *) stringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter inclusively:(BOOL)inclusive skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * As stringFromCharacter: toCharacter: ..., but also trims the string up to the "to" character and
 * up to or including the "from" character, depending on whether "trimmingInclusively" is set.
 * "returningInclusively" controls whether the supplied characters should also be returned.
 * Returns nil if no valid matching string can be found.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn;

/*
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether to
 * skip over bracket-enclosed characters, as in subqueries, enums, definitions or groups.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn skippingBrackets:(BOOL)skipBrackets;

/*
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * As trimAndReturnStringFromCharacter: toCharacter: ..., but allows control over both bracketing
 * and quoting.
 */
- (NSString *) trimAndReturnStringFromCharacter:(unichar)fromCharacter toCharacter:(unichar)toCharacter trimmingInclusively:(BOOL)inclusiveTrim returningInclusively:(BOOL)inclusiveReturn skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * Split a string on the boundaries formed by the supplied character, returning an array of strings.
 * Quoted strings are automatically ignored when looking for the characters.
 * SQL comments are automatically ignored when looking for the characters.
 * Returns an array with one element containing the entire string if the supplied character is not found.
 */
- (NSArray *) splitStringByCharacter:(unichar)character;

/*
 * As splitStringByCharacter: ..., but allows control over whether to skip over bracket-enclosed
 * characters, as in subqueries, enums, definitions or groups.
 */
- (NSArray *) splitStringByCharacter:(unichar)character skippingBrackets:(BOOL)skipBrackets;

/*
 * As splitStringByCharacter:, but allows control over whether characters
 * within quoted strings are ignored.
 */
- (NSArray *) splitStringByCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * As splitStringByCharacter: ..., but allows control over both bracketing and quoting.
 */
- (NSArray *) splitStringByCharacter:(unichar)character skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;

/*
 * Methods used internally by this class to power the methods above:
 */
- (long) firstOccurrenceOfCharacter:(unichar)character ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;
- (long) firstOccurrenceOfCharacter:(unichar)character afterIndex:(long)startIndex ignoringQuotedStrings:(BOOL)ignoreQuotedStrings;
- (long) firstOccurrenceOfCharacter:(unichar)character afterIndex:(long)startIndex skippingBrackets:(BOOL)skipBrackets ignoringQuotedStrings:(BOOL)ignoreQuotedStrings ;
- (long) endIndexOfStringQuotedByCharacter:(unichar)quoteCharacter startingAtIndex:(long)index;
- (long) endIndexOfCommentOfType:(SPCommentType)commentType startingAtIndex:(long)index;


/* Required and primitive methods to allow subclassing class cluster */
#pragma mark -
- (id) init;
- (id) initWithBytes:(const void *)bytes length:(unsigned int)length encoding:(NSStringEncoding)encoding;
- (id) initWithBytesNoCopy:(void *)bytes length:(unsigned int)length encoding:(NSStringEncoding)encoding freeWhenDone:(BOOL)flag;
- (id) initWithCapacity:(unsigned int)capacity;
- (id) initWithCharactersNoCopy:(unichar *)chars length:(unsigned int)length freeWhenDone:(BOOL)flag;
- (id) initWithContentsOfFile:(id)path;
- (id) initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error;
- (id) initWithCString:(const char *)nullTerminatedCString encoding:(NSStringEncoding)encoding;
- (id) initWithFormat:(NSString *)format, ...;
- (id) initWithFormat:(NSString *)format arguments:(va_list)argList;
- (unsigned int) length;
- (unichar) characterAtIndex:(unsigned int)index;
- (id) description;
- (unsigned int) replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(unsigned)opts range:(NSRange)searchRange;
- (void) setString:(NSString *)string;
- (void) replaceCharactersInRange:(NSRange)range withString:(NSString *)string;
- (void) dealloc;
@end