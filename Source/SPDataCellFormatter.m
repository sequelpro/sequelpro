//
//  SPDataCell.m
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


@implementation SPDataCellFormatter

@synthesize textLimit;

- (NSString *)stringForObjectValue:(id)anObject
{

	// Truncate the string for speed purposes if it's very long - improves table scrolling speed.
	if ([anObject length] > 150) {
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
	// No limit set 
	if (textLimit == 0)
		return YES;
	
	if ([partialString length] > textLimit) {
		NSBeep();
		newString = [NSString stringWithCharacters:partialString length:textLimit];
	}
	
	return ([partialString length] <= textLimit);
}

@end
