//
//  $Id$
//
//  SPFontPreviewTextField.m
//  sequel-pro
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

#import "SPFontPreviewTextField.h"

@implementation SPFontPreviewTextField

/**
 * Add a method to set the font to use for the preview.  The font metrics
 * are applied to the textField, and the font name is displayed in the textField
 * for an easy preview.
 */
- (void)setFont:(NSFont *)theFont 
{

	// If no font was supplied, clear the preview
	if (!theFont) {
		[self setObjectValue:@""];
		return;
	}

	// Take the supplied font and apply all its traits except for a standardised
	// font size to the text field
	NSFont *displayFont = [[NSFontManager sharedFontManager] convertFont:theFont toSize:11.0f];
	[super setFont:displayFont];

	// Set up a paragraph style for display, setting bounds and display settings
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle new] autorelease];
	[paragraphStyle setAlignment:NSNaturalTextAlignment];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[paragraphStyle setMaximumLineHeight:NSHeight([self bounds]) + [displayFont descender]];

	// Set up the text to display - the font display name and the point size.
	NSMutableAttributedString *displayString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@, %.1f pt", [theFont displayName], [theFont pointSize]]];

	// Apply the paragraph style
	[displayString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [displayString length])];

	// Update the display
	[self setObjectValue:displayString];
}

@end
