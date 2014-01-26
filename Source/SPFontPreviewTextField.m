//
//  SPFontPreviewTextField.m
//  sequel-pro
//
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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
