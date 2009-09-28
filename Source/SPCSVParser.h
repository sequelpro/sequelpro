//
//  $Id$
//
//  SPCSVParser.h
//  sequel-pro
//
//  Created by Rowan Beentje on 16/09/2009.
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
 * This class provides a string class intended for CSV parsing.  Unlike SPSQLParser, this
 * does not extend NSMutableString and instead provides only a subset of similar methods.
 * Internally, an approach similar to NSScanner is used to support multi-character strings.
 * The methods are designed with the intention that as a string is parsed the parsed content
 * is removed.  This also allows parsing to occur in "streaming" mode, with parseable content
 * being pulled off the start of the string as additional content is appended onto the end of
 * the string, eg from a file.
 *
 * Supports:
 *  - Control of field terminator, line terminator, string enclosures and escape characters.
 *  - Multi-character field terminator, line terminator, string enclosures, and escape strings.
 *  - Stream-based processing (recommended that strings split by \n or \r are used when streaming
 *    to minimise multibyte issues)
 *  - Correct treatment of line terminators within quoted strings and proper escape support
 *    including escape characters matching the quote characters in Excel style
 *
 * The internal usage of string range finding, similar to the NSScanner approach, means this
 * could be significantly sped up for single-character terminators.
 */

#define SPCSVPARSER_TRIM_ENACT_LENGTH 250000

@interface SPCSVParser : NSObject
{
	NSMutableString *csvString;

	long trimPosition;
	long parserPosition;
	long totalLengthParsed;
	long csvStringLength;
	int fieldCount;

	NSString *nullReplacementString;
	NSString *fieldEndString;
	NSString *lineEndString;
	NSString *fieldQuoteString;
	NSString *escapeString;
	NSString *escapedFieldEndString;
	NSString *escapedLineEndString;
	NSString *escapedFieldQuoteString;
	NSString *escapedEscapeString;
	int fieldEndLength;
	int lineEndLength;
	int fieldQuoteLength;
	int escapeLength;
	NSCharacterSet *skipCharacterSet;
	NSScanner *csvScanner;

	BOOL escapeStringIsFieldQuoteString;
}

/* Retrieving data from the CSV string */
- (NSArray *) array;
- (NSArray *) getRowAsArray;
- (NSArray *) getRowAsArrayAndTrimString:(BOOL)trimString stringIsComplete:(BOOL)stringComplete;

/* Adding new data to the string */
- (void) appendString:(NSString *)aString;
- (void) setString:(NSString *)aString;

/* Basic information */
- (NSUInteger) length;
- (NSString *) string;
- (long) parserPosition;
- (long) totalLengthParsed;

/* Setting the terminator, quote, escape and null character replacement strings */
- (void) setFieldTerminatorString:(NSString *)theString convertDisplayStrings:(BOOL)convertString;
- (void) setLineTerminatorString:(NSString *)theString convertDisplayStrings:(BOOL)convertString;
- (void) setFieldQuoteString:(NSString *)theString convertDisplayStrings:(BOOL)convertString;
- (void) setEscapeString:(NSString *)theString convertDisplayStrings:(BOOL)convertString;
- (void) setNullReplacementString:(NSString *)nullString;

/* Init and internal update methods */
- (void) _initialiseCSVParserDefaults;
- (void) _moveParserPastSkippableCharacters;
- (long) _getDistanceToString:(NSString *)theString;
- (void) _updateState;
- (NSString *) _convertDisplayString:(NSString *)theString;
- (void) _updateSkipCharacterSet;

/* Initialisation and teardown */
#pragma mark -
- (id) init;
- (id) initWithString:(NSString *)aString;
- (id) initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error;
- (void) dealloc;

@end
