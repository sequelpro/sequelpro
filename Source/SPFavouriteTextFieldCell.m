//
//  SPFavouriteTextFieldCell.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 29, 2008
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

#import "SPFavouriteTextFieldCell.h"

#define FAVORITE_NAME_FONT_SIZE 12.0

@interface SPFavouriteTextFieldCell (PrivateAPI)

- (NSAttributedString *)constructSubStringAttributedString;
- (NSAttributedString *)attributedStringForFavouriteName;
- (NSDictionary *)mainStringAttributedStringAttributes;
- (NSDictionary *)subStringAttributedStringAttributes;

@end

@implementation SPFavouriteTextFieldCell

// -------------------------------------------------------------------------------
// init
// -------------------------------------------------------------------------------
- (id)init
{
	if ((self = [super init])) {
		mainStringColor = [NSColor blackColor];
		subStringColor = [NSColor grayColor];
	}
	
	return self;
}

// -------------------------------------------------------------------------------
// copyWithZone:
// -------------------------------------------------------------------------------
- (id)copyWithZone:(NSZone *)zone 
{
    SPFavouriteTextFieldCell *cell = (SPFavouriteTextFieldCell *)[super copyWithZone:zone];
	
	cell->favouriteName = nil;
	
    cell->favouriteName = [favouriteName retain];
    
	return cell;
}

// -------------------------------------------------------------------------------
// favouriteName
//
// Get the cell's favourite name.
// -------------------------------------------------------------------------------
- (NSString *)favouriteName
{
	return favouriteName;
}

// -------------------------------------------------------------------------------
// setFavouriteName:
//
// Set the cell's favourite name to the supplied name.
// -------------------------------------------------------------------------------
- (void)setFavouriteName:(NSString *)name
{
	if (favouriteName != name) {
		[favouriteName release];
		favouriteName = [name retain];
	}
}

// -------------------------------------------------------------------------------
// favouriteHost
//
// Get the cell's favourite host.
// -------------------------------------------------------------------------------
- (NSString *)favouriteHost
{
	return favouriteHost;
}

// -------------------------------------------------------------------------------
// setFavouriteHost:
//
// Set the cell's favourite host to the supplied name.
// -------------------------------------------------------------------------------
- (void)setFavouriteHost:(NSString *)host
{
	if (favouriteHost != host) {
		[favouriteHost release];
		favouriteHost = [host retain];
	}
}

// -------------------------------------------------------------------------------
// drawInteriorWithFrame:inView:
//
// Draws the actual cell.
// -------------------------------------------------------------------------------
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{		
	(([self isHighlighted]) && (![[self highlightColorWithFrame:cellFrame inView:controlView] isEqualTo:[NSColor secondarySelectedControlColor]])) ? [self invertFontColors] : [self restoreFontColors];
	
	// Construct and get the sub text attributed string
	NSAttributedString *mainString = [[self attributedStringForFavouriteName] autorelease];
	NSAttributedString *subString = [[self constructSubStringAttributedString] autorelease];
	
	NSRect subFrame = NSMakeRect(0.0, 0.0, [subString size].width, [subString size].height);
	
	// Total height of both strings with a 2 pixel separation space
	float totalHeight = [mainString size].height + [subString size].height + 1.0;
	
    cellFrame.origin.y += (cellFrame.size.height - totalHeight) / 2.0;
	cellFrame.origin.x += 10.0; // Indent main string from image
	
	// Position the sub text's frame rect
	subFrame.origin.y = [mainString size].height + cellFrame.origin.y + 1.0;
	subFrame.origin.x = cellFrame.origin.x;
	
    cellFrame.size.height = totalHeight;
	
	int i;
	float maxWidth = cellFrame.size.width;
	float mainStringWidth = [mainString size].width;
	float subStringWidth = [subString size].width;
	
	if (maxWidth < mainStringWidth) {
		for (i = 0; i <= [mainString length]; i++) {
			if ([[mainString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth) {	
				mainString = [[[NSMutableAttributedString alloc] initWithString:[[[mainString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self mainStringAttributedStringAttributes]] autorelease];
			}
		}
	}
	
	if (maxWidth < subStringWidth) {
		for (i = 0; i <= [subString length]; i++) {
			if ([[subString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth) {	
				subString = [[[NSMutableAttributedString alloc] initWithString:[[[subString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self subStringAttributedStringAttributes]] autorelease];
			}
		}
	}
	
	[mainString drawInRect:cellFrame];
	[subString drawInRect:subFrame];
}

// -------------------------------------------------------------------------------
// invertFontColors
//
// Inverts the displayed font colors when the cell is selected.
// -------------------------------------------------------------------------------
- (void)invertFontColors
{
	mainStringColor = [NSColor whiteColor];
	subStringColor = [NSColor whiteColor];
}

// -------------------------------------------------------------------------------
// restoreFontColors
//
// Restores the displayed font colors once the cell is no longer selected.
// -------------------------------------------------------------------------------
- (void)restoreFontColors
{
	mainStringColor = [NSColor blackColor];
	subStringColor = [NSColor grayColor];
}

// -------------------------------------------------------------------------------
// dealloc
// -------------------------------------------------------------------------------
- (void)dealloc 
{	
    [favouriteName release], favouriteName = nil;
	
    [super dealloc];
}

@end

@implementation SPFavouriteTextFieldCell (PrivateAPI)

// -------------------------------------------------------------------------------
// constructSubStringAttributedString
//
// Constructs the attributed string to be used as the cell's substring.
// -------------------------------------------------------------------------------
- (NSAttributedString *)constructSubStringAttributedString
{
	return [[NSAttributedString alloc] initWithString:favouriteHost attributes:[self subStringAttributedStringAttributes]];
}

// -------------------------------------------------------------------------------
// attributedStringForFavouriteName
//
// Constructs the attributed string for the cell's favourite name.
// -------------------------------------------------------------------------------
- (NSAttributedString *)attributedStringForFavouriteName
{	
	return [[NSAttributedString alloc] initWithString:favouriteName attributes:[self mainStringAttributedStringAttributes]];
}

// -------------------------------------------------------------------------------
// mainStringAttributedStringAttributes
//
// Returns the attributes of the cell's main string.
// -------------------------------------------------------------------------------
- (NSDictionary *)mainStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:mainStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:FAVORITE_NAME_FONT_SIZE], NSFontAttributeName, nil];
}

// -------------------------------------------------------------------------------
// subStringAttributedStringAttributes
//
// Returns the attributes of the cell's sub string.
// -------------------------------------------------------------------------------
- (NSDictionary *)subStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:subStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName, nil];
}

@end
