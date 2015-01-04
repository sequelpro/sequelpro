//
//  SPTableFieldValidation.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 28, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPTableFieldValidation.h"

@interface SPTableFieldValidation ()

- (NSString *)_formatType:(NSString *)type;

@end

@implementation SPTableFieldValidation

@synthesize fieldTypes;

#pragma mark -
#pragma mark Public API

/**
 * Returns whether or not the supplied field type is numeric according to it's position within the currnet
 * field types array.
 *
 * @param fieldType The field type to test
 */
- (BOOL)isFieldTypeNumeric:(NSString *)fieldType
{
	NSString *type = [self _formatType:fieldType];
	
	if (![fieldTypes containsObject:type]) return YES;
	
	return ([fieldTypes indexOfObject:type] < 17);
}

/**
 * Returns whether or not the supplied field type is a date according to it's position within the currnet
 * field types array.
 *
 * @param fieldType The field type to test
 */
- (BOOL)isFieldTypeDate:(NSString *)fieldType
{
	NSString *type = [self _formatType:fieldType];
	
	if (![fieldTypes containsObject:type]) return YES;
	
	return (([fieldTypes indexOfObject:type] > 32) && ([fieldTypes indexOfObject:type] < 38));
}

/**
 * Returns whether or not the supplied field type is geometry according to it's position within the currnet
 * field types array.
 *
 * @param fieldType The field type to test
 */
- (BOOL)isFieldTypeGeometry:(NSString *)fieldType
{
	NSString *type = [self _formatType:fieldType];
	
	if (![fieldTypes containsObject:type]) return YES;
	
	return ([fieldTypes indexOfObject:type] > 38);
}

/**
 * Returns whether or not the supplied field type is a string according to it's position within the currnet
 * field types array.
 *
 * @param fieldType The field type to test
 */
- (BOOL)isFieldTypeString:(NSString *)fieldType
{
	NSString *type = [self _formatType:fieldType];
	
	if (![fieldTypes containsObject:type]) return YES;
	
	return (((([fieldTypes indexOfObject:type] > 17) && ([fieldTypes indexOfObject:type] < 24)) || (([fieldTypes indexOfObject:type] > 29) && ([fieldTypes indexOfObject:type] < 32))));
}

/**
 * Returns whether or not the supplied field type allows binary according to it's position within the currnet
 * field types array.
 *
 * @param fieldType The field type to test
 */
- (BOOL)isFieldTypeAllowBinary:(NSString *)fieldType
{
	NSString *type = [self _formatType:fieldType];
	
	if (![fieldTypes containsObject:type]) return YES;
	
	return (([fieldTypes indexOfObject:type] > 17) && ([fieldTypes indexOfObject:type] < 24));
}

#pragma mark -
#pragma mark Private API

/**
 * Formats, i.e. removes whitespace and newlines as well as uppercases the supplied field type string.
 *
 * @param type The field type string to format
 */
- (NSString *)_formatType:(NSString *)type
{
	return [[type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
}

#pragma mark -
#pragma mark Other

- (void)dealloc
{
	SPClear(fieldTypes);
	
	[super dealloc];
}

@end
