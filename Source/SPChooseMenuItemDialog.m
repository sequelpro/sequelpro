//
//  $Id: SPChooseMenuItemDialog.m 744 2009-05-22 20:00:00Z bibiko $
//
//  SPChooseMenuItemDialog.m
//  sequel-pro
//
//  Created by Hans-J. Bibiko on Dec 03, 2010.
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

#import "SPChooseMenuItemDialog.h"


@implementation SPChooseMenuItemDialog

@synthesize contextMenu;

- (id)init;
{
	if(self = [self initWithContentRect:NSMakeRect(10,10,10,10) 
					styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		;
	}
	return self;
}

- (void)dealloc
{
	[tv release];
	[super dealloc];
}

- (void)initMeWithOptions:(NSDictionary *)displayOptions
{
	[self setReleasedWhenClosed:YES];
	[self setLevel:NSNormalWindowLevel];
	[self setHidesOnDeactivate:YES];
	[self setHasShadow:YES];
	[self setAlphaValue:0.9];
	tv = [[NSTextView alloc] initWithFrame:NSMakeRect(10,10,10,10)];
	[self setContentView:tv];
	[tv setDelegate:self];
	[tv setEditable:YES];
}

+ (void)displayMenu:(NSMenu*)theMenu atPosition:(NSPoint)location
{

	SPChooseMenuItemDialog *dialog = [SPChooseMenuItemDialog new];
	[dialog initMeWithOptions:nil];

	NSMenuItem *returnItem = nil;

	[dialog setContextMenu:theMenu];
	[dialog setFrameTopLeftPoint:location];

	[dialog orderFront:nil];
	NSEvent *theEvent = [NSEvent
	        mouseEventWithType:NSRightMouseDown
	        location:NSMakePoint(1,1)
	        modifierFlags:0
	        timestamp:1
	        windowNumber:[dialog windowNumber]
	        context:[NSGraphicsContext currentContext]
	        eventNumber:1
	        clickCount:1
	        pressure:0.0];

	[[NSApplication sharedApplication] postEvent:theEvent atStart:NO];

}

- (NSMenu *)menuForEvent:(NSEvent *)event 
{
	NSLog(@"asdasdasd");
	return contextMenu;
}

@end
