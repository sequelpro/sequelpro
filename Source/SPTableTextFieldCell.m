//
//  $Id$
//
//  SPTableTextFieldCell.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 1, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPTableTextFieldCell.h"

@implementation SPTableTextFieldCell

/**
 * Implements nicer cell truncating by appending '...' to the table name, before asking super to draw it.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{			
	// Construct and get the sub text attributed string
	NSAttributedString *string = [self attributedStringValue];
	
	int i;
	float maxWidth = cellFrame.size.width;
	float stringWidth = [string size].width;
			
	// Set a right padding
	maxWidth -= 5;
		
	if (maxWidth < stringWidth) {
		for (i = 0; i <= [string length]; i++) {
			if (([[string attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth) && (i >= 3)) {	
				string = [[[NSMutableAttributedString alloc] initWithString:[[[string attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[string attributesAtIndex:0 effectiveRange:NULL]] autorelease];
			}
		}
	}
	
	[self setAttributedStringValue:string];
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
