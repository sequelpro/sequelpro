//
//  $Id$
//
//  SPTableFieldValidation.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 28, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPTableFieldValidation.h"

@interface SPTableFieldValidation (PrivateAPI)

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
	
	return (([fieldTypes indexOfObject:type] > 17) && ([fieldTypes indexOfObject:type] < 32));
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

/**
 * Dealloc.
 */
- (void)dealloc
{
	[fieldTypes release], fieldTypes = nil;
	
	[super dealloc];
}

@end
