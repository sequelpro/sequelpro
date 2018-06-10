//
//  SPFillView.m
//  sequel-pro
//
//  Created by Max Lohrmann on 09.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
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

#import "SPFillView.h"

@implementation SPFillView

- (void)setSystemColorOfName:(NSString *)name
{
	//TODO: xibs after 10.6 support storing colors as user defined attributes so we don't need the detour via strings anymore
	NSColorList *scl = [NSColorList colorListNamed:@"System"];
	NSColor *color = [scl colorWithKey:name];
	if(color) {
		[color retain];
		[currentColor release];
		currentColor = color;
		[self setNeedsDisplay:YES];
	}
}

- (void)drawRect:(NSRect)dirtyRect {
	if(currentColor) {
		[currentColor set];
		NSRectFill(dirtyRect);
	}
}

- (void)dealloc
{
	[currentColor release];
	[super dealloc];
}

@end
