//
//  $Id$  
//
//  SPMenuAdditionsTests.m
//  sequel-pro
//
//  Created by Stuart Connolly on March 20, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPMenuAdditionsTests.h"
#import "SPMenuAdditions.h"

static NSString *SPTestMenuItemTitle = @"Menu Item";

@implementation SPMenuAdditionsTests

- (void)setUp
{
	NSUInteger num = 5;
	
	menu = [[NSMenu alloc] init];
	
	for (NSUInteger i = 0; i < num; i++)
	{
		[menu addItemWithTitle:[NSString stringWithFormat:@"%@ %d", SPTestMenuItemTitle, i] action:NULL keyEquivalent:@""];	
	}
}

- (void)tearDown
{
	[menu release], menu = nil;
}

- (void)testCompatibleRemoveAllItems
{
	[menu compatibleRemoveAllItems];
	
	STAssertFalse([menu numberOfItems], @"The menu should have no menu items.");
}

@end

