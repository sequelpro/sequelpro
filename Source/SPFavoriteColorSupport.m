//
//  SPFavoriteColorSupport.m
//  sequel-pro
//
//  Created by Max Lohrmann on 2013-10-20
//  Copyright (c) 2013 Max Lohrmann. All rights reserved.
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

#import "SPFavoriteColorSupport.h"

@implementation SPFavoriteColorSupport

static SPFavoriteColorSupport *_colorSupport = nil;

- (id)init
{
    if ((self = [super init])) {
        prefs = [NSUserDefaults standardUserDefaults];
    }

    return self;
}

+ (SPFavoriteColorSupport *)sharedInstance
{
	if (!_colorSupport) {
		_colorSupport = [[self allocWithZone:NULL] init];
	}
	
	return _colorSupport;
}


+ (NSArray *)defaultColorList
{
	return [NSArray arrayWithObjects:
			[NSColor colorWithDeviceRed:228.0 / 255.0 green: 116.0 / 255.0 blue:102.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:237.0 / 255.0 green: 174.0 / 255.0 blue:107.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:227.0 / 255.0 green: 213.0 / 255.0 blue:119.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:175.0 / 255.0 green: 215.0 / 255.0 blue:119.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:118.0 / 255.0 green: 185.0 / 255.0 blue:232.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:202.0 / 255.0 green: 152.0 / 255.0 blue:224.0 / 255.0 alpha:1.0],
			[NSColor colorWithDeviceRed:182.0 / 255.0 green: 182.0 / 255.0 blue:182.0 / 255.0 alpha:1.0],
			nil];
}

- (NSColor *)colorForIndex:(NSInteger)colorIndex
{
	NSArray *colorList = [self userColorList];

	// Check bounds
	if (colorIndex < 0 || (NSUInteger)colorIndex >= [colorList count]) {
		return nil;
	}

	return [colorList objectAtIndex:colorIndex];
}

- (NSArray *)userColorList
{
	if (@available(macOS 10.13, *)) {
		return @[
			[NSColor colorNamed:@"favoriteRed"],
			[NSColor colorNamed:@"favoriteOrange"],
			[NSColor colorNamed:@"favoriteYellow"],
			[NSColor colorNamed:@"favoriteGreen"],
			[NSColor colorNamed:@"favoriteBlue"],
			[NSColor colorNamed:@"favoritePurple"],
			[NSColor colorNamed:@"favoriteGraphite"]
		];
	}
	
	NSArray *archivedColors = [prefs objectForKey:SPFavoriteColorList];
	NSMutableArray *colorList = [NSMutableArray arrayWithCapacity:[archivedColors count]];

	for (NSData *archivedColor in archivedColors)
	{
		NSColor *color = [NSUnarchiver unarchiveObjectWithData:archivedColor];

		[colorList addObject:color];
	}
	
	return [[colorList copy] autorelease];
}

@end
