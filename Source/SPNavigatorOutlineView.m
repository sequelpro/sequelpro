//
//  $Id$
//
//  SPNavigatorOutlineView.m
//  sequel-pro
//
//  Created by H.-J. Bibiko on 3/23/10.
//  Copyright 2010. All rights reserved.
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

#import "SPNavigatorOutlineView.h"
#import "SPNavigatorController.h"

@implementation SPNavigatorOutlineView

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	// Enter or Return selects in active document the chosen item
	if ([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {
		[[self delegate] selectInActiveDocumentItem:[self itemAtRow:[self selectedRow]] fromView:self];
		return;
	}

	[super keyDown:theEvent];
}

/*
 * Return the data source item of the selected row, if no or multiple selections
 * return nil
 */
- (id)selectedItem
{
	if([self numberOfSelectedRows] == 1)
		return [self itemAtRow:[self selectedRow]];
	
	return nil;
}

@end
