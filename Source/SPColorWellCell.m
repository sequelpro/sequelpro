//
//  $Id$
//
//  SPColorWellCell.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 17, 2010
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

#import "SPColorWellCell.h"


@implementation SPColorWellCell

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect square = NSInsetRect (cellFrame, 0.5, 0.5);

	if (square.size.height < square.size.width) {
		square.size.width = square.size.height;
		square.origin.x = square.origin.x + (cellFrame.size.width -
			square.size.width) / 2.0;
	} else {
		square.size.height = square.size.width;
		square.origin.y = square.origin.y + (cellFrame.size.height -
			square.size.height) / 2.0;
	}

	[[NSColor blackColor] set];
	[NSBezierPath strokeRect: square];

	[(NSColor*) [self objectValue] set];
	[NSBezierPath fillRect: NSInsetRect (square, 2.0, 2.0)];
}

@end
