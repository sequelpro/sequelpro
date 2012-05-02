//
//  $Id$
//
//  SPMutableArrayAdditionsTest.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 2, 2011
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

#import "SPMutableArrayAdditionsTest.h"
#import "SPMutableArrayAdditions.h"

@implementation SPMutableArrayAdditionsTest

- (void)testReverse
{
	NSMutableArray *testArray = [NSMutableArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", nil];
	NSMutableArray *expectedArray = [NSMutableArray arrayWithObjects:@"5", @"4", @"3", @"2", @"1", nil];
	
	[testArray reverse];
	
	STAssertEqualObjects(testArray, expectedArray, @"The reversed array should look like: %@", expectedArray);
}

@end
