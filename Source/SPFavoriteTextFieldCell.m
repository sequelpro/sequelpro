//
//  $Id$
//
//  SPFavoriteTextFieldCell.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 29, 2008
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
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

#import "SPFavoriteTextFieldCell.h"

#define FAVORITE_NAME_FONT_SIZE 12.0

@interface SPFavoriteTextFieldCell (PrivateAPI)

- (NSAttributedString *)constructSubStringAttributedString;
- (NSAttributedString *)attributedStringForFavoriteName;
- (NSDictionary *)mainStringAttributedStringAttributes;
- (NSDictionary *)subStringAttributedStringAttributes;

@end

@implementation SPFavoriteTextFieldCell

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		mainStringColor = [NSColor blackColor];
		subStringColor = [NSColor grayColor];
		favoriteName = nil;
		favoriteHost = nil;
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone 
{
    SPFavoriteTextFieldCell *cell = (SPFavoriteTextFieldCell *)[super copyWithZone:zone];
	
	cell->favoriteName = nil;
    if (favoriteName) cell->favoriteName = [favoriteName copyWithZone:zone];

    cell->favoriteHost = nil;
    if (favoriteHost) cell->favoriteHost = [favoriteHost copyWithZone:zone];
    
	return cell;
}

/**
 * Get the cell's favorite name.
 */
- (NSString *)favoriteName
{
	return favoriteName;
}

/**
 * Set the cell's favorite name to the supplied name.
 */
- (void)setFavoriteName:(NSString *)name
{
	if (favoriteName != name) {
		[favoriteName release];
		favoriteName = [name retain];
	}
}

/**
 * Get the cell's favorite host.
 */
- (NSString *)favoriteHost
{
	return favoriteHost;
}

/**
 * Set the cell's favorite host to the supplied name.
 */
- (void)setFavoriteHost:(NSString *)host
{
	if (favoriteHost != host) {
		[favoriteHost release];
		favoriteHost = [host retain];
	}
}

/**
 * Draws the actual cell.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{		
	(([self isHighlighted]) && (![[self highlightColorWithFrame:cellFrame inView:controlView] isEqualTo:[NSColor secondarySelectedControlColor]])) ? [self invertFontColors] : [self restoreFontColors];
	
	// Construct and get the sub text attributed string
	NSAttributedString *mainString = [self attributedStringForFavoriteName];
	NSAttributedString *subString = [self constructSubStringAttributedString];
	
	NSRect subFrame = NSMakeRect(0.0, 0.0, [subString size].width, [subString size].height);
	
	// Total height of both strings with a 2 pixel separation space
	CGFloat totalHeight = [mainString size].height + [subString size].height + 1.0;
	
	cellFrame.origin.y += (cellFrame.size.height - totalHeight) / 2.0;
	cellFrame.origin.x += 10.0; // Indent main string from image
	
	// Position the sub text's frame rect
	subFrame.origin.y = [mainString size].height + cellFrame.origin.y + 1.0;
	subFrame.origin.x = cellFrame.origin.x;
	
	cellFrame.size.height = totalHeight;
	
	NSInteger i;
	CGFloat maxWidth = cellFrame.size.width;
	CGFloat mainStringWidth = [mainString size].width;
	CGFloat subStringWidth = [subString size].width;

	// Set a right-padding
	maxWidth -= 10;

	if (maxWidth < mainStringWidth) {
		for (i = 0; i <= [mainString length]; i++) {
			if ([[mainString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth && i >= 3) {
				mainString = [[[NSMutableAttributedString alloc] initWithString:[[[mainString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self mainStringAttributedStringAttributes]] autorelease];
			}
		}
	}
	
	if (maxWidth < subStringWidth) {
		for (i = 0; i <= [subString length]; i++) {
			if ([[subString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth && i >= 3) {
				subString = [[[NSMutableAttributedString alloc] initWithString:[[[subString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self subStringAttributedStringAttributes]] autorelease];
			}
		}
	}
	
	[mainString drawInRect:cellFrame];
	[subString drawInRect:subFrame];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	NSAttributedString *mainString = [self attributedStringForFavoriteName];
	NSAttributedString *subString = [self constructSubStringAttributedString];

	// 15 := indention 10 from image to string plus 5 px padding
	CGFloat theWidth = MAX([mainString size].width, [subString size].width) + (([self image] != nil) ? [[self image] size].width : 0) + 15;

	CGFloat totalHeight = [mainString size].height + [subString size].height + 1.0;

	cellSize.width = theWidth;
	cellSize.height = totalHeight + 13.0;
	return cellSize;
}

/**
 * Inverts the displayed font colors when the cell is selected.
 */
- (void)invertFontColors
{
	mainStringColor = [NSColor whiteColor];
	subStringColor = [NSColor whiteColor];
}

/**
 * Restores the displayed font colors once the cell is no longer selected.
 */
- (void)restoreFontColors
{
	mainStringColor = [NSColor blackColor];
	subStringColor = [NSColor grayColor];
}

/**
 * Dealloc.
 */
- (void)dealloc 
{	
    [favoriteName release], favoriteName = nil;
    [favoriteHost release], favoriteHost = nil;
	
    [super dealloc];
}

@end

@implementation SPFavoriteTextFieldCell (PrivateAPI)

/**
 * Constructs the attributed string to be used as the cell's substring.
 */
- (NSAttributedString *)constructSubStringAttributedString
{
	return [[[NSAttributedString alloc] initWithString:favoriteHost attributes:[self subStringAttributedStringAttributes]] autorelease];
}

/**
 * Constructs the attributed string for the cell's favorite name.
 */
- (NSAttributedString *)attributedStringForFavoriteName
{	
	return [[[NSAttributedString alloc] initWithString:favoriteName attributes:[self mainStringAttributedStringAttributes]] autorelease];
}

/**
 * Returns the attributes of the cell's main string.
 */
- (NSDictionary *)mainStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:mainStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:FAVORITE_NAME_FONT_SIZE], NSFontAttributeName, nil];
}

/**
 * Returns the attributes of the cell's sub string.
 */
- (NSDictionary *)subStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:subStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName, nil];
}

@end
