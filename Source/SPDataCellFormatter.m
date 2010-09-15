//
//  $Id$
//
//  SPDataCellFormatter.m
//  sequel-pro
//
//  Created by Rowan Beentje on 11/02/2009.
//  Copyright 2009 Arboreal. All rights reserved.
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

#import "SPDataCellFormatter.h"
#import "SPTooltip.h"
#import "SPConstants.h"

@implementation SPDataCellFormatter

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
	@synthesize textLimit;
	@synthesize fieldType;
#else
	-(NSInteger)textLimit
	{
		return textLimit;
	}

	-(void)setTextLimit:(NSInteger)limit
	{
		textLimit = limit;
	}
#endif

- (NSString *)stringForObjectValue:(id)anObject
{

	// Truncate the string for speed purposes if it's very long - improves table scrolling speed.
	if ([(NSString *)anObject length] > 150) {
		return ([NSString stringWithFormat:@"%@...", [anObject substringToIndex:147]]);
	}

	return anObject;
}

// Always provide the full string when editing
- (NSString *)editingStringForObjectValue:(id)anObject
{
	return anObject;
}

- (BOOL) getObjectValue:(id*) object forString:(NSString*) string errorDescription:(NSString**) error
{
	*object = string;
	return YES;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
	return [[[NSAttributedString alloc] initWithString:[self stringForObjectValue:anObject] attributes:attributes] autorelease];
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error
{
	// No limit set or partialString is NULL value string allow editing
	if (textLimit == 0 || [partialString isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:SPNullValue]])
		return YES;

	// A single character over the length of the string - likely typed.  Prevent the change.
	if ([partialString length] == textLimit + 1) {
		[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %ld.", @"Maximum text length is set to %ld."), (long)textLimit]];
		return NO;
	}

	// If the string is considerably longer than the limit, likely pasted.  Accept but truncate.
	if ([partialString length] > textLimit) {
		[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %ld. Inserted text was truncated.", @"Maximum text length is set to %ld. Inserted text was truncated."), (long)textLimit]];
		*newString = [NSString stringWithString:[partialString substringToIndex:textLimit]];
		return NO;
	}

	// Check for BIT fields whether 1 or 0 are typed
	if(fieldType && [fieldType length] && [[fieldType uppercaseString] isEqualToString:@"BIT"]) {

		if([partialString rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"01"] invertedSet]].location != NSNotFound) {
				[SPTooltip showWithObject:NSLocalizedString(@"For BIT fields only “1” or “0” are allowed.", @"For BIT fields only “1” or “0” are allowed.")];
	    		return NO;
		}

		return YES;
	}

	return YES;
}

@end
