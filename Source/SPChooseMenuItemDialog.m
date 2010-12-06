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

@interface SPChooseMenuItemDialogTextView : NSTextView
{
}

- (IBAction)menuItemHandler:(id)sender;

@end

@implementation SPChooseMenuItemDialogTextView
{
}
- (id)init;
{
	if(self = [super initWithFrame:NSMakeRect(1,1,2,2)])
	{
		;
	}
	return self;
}

- (IBAction)menuItemHandler:(id)sender
{
	[[self delegate] setSelectedItemIndex:[sender tag]];
	[[self delegate] setWaitForChoice:NO];
}

- (NSMenu *)menuForEvent:(NSEvent *)event 
{
	return [[self delegate] contextMenu];
}

@end

@implementation SPChooseMenuItemDialog

@synthesize contextMenu;
@synthesize selectedItemIndex;
@synthesize waitForChoice;

- (id)init;
{
	if(self = [super initWithContentRect:NSMakeRect(1,1,2,2) 
					styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		waitForChoice = YES;
		selectedItemIndex = -1;
	}
	return self;
}

- (void)dealloc
{
	[dummyTextView release];
	[super dealloc];
}

- (void)initDialog
{
	[self setReleasedWhenClosed:YES];
	[self setLevel:NSNormalWindowLevel];
	[self setHidesOnDeactivate:YES];
	[self setHasShadow:YES];
	[self setAlphaValue:0.0];

	dummyTextView = [[SPChooseMenuItemDialogTextView alloc] init];
	[dummyTextView setDelegate:self];

	[self setContentView:dummyTextView];

}

+ (NSInteger)withItems:(NSArray*)theList atPosition:(NSPoint)location
{

	if(!theList || ![theList count]) return -1;

	SPChooseMenuItemDialog *dialog = [SPChooseMenuItemDialog new];

	[dialog initDialog];
	
	NSMenu *theMenu = [[[NSMenu alloc] init] autorelease];
	NSInteger cnt = 0;
	for(id item in theList) {
		NSMenuItem *aMenuItem;
		if([item isKindOfClass:[NSString class]])
			aMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector(menuItemHandler:) keyEquivalent:@""];
		else if([item isKindOfClass:[NSDictionary class]]) {
			NSString *title = ([item objectForKey:@"title"]) ?: @"";
			SEL action = ([item objectForKey:@"action"]) ? NSSelectorFromString([item objectForKey:@"action"]) : @selector(menuItemHandler:);
			NSString *keyEquivalent = ([item objectForKey:@"key"]) ?: @"";
			aMenuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
			if([item objectForKey:@"tooltip"])
				[aMenuItem setToolTip:[item objectForKey:@"tooltip"]];
		}
		[aMenuItem setTag:cnt++];
		[theMenu addItem:aMenuItem];
		[aMenuItem release];
	}
	[dialog setContextMenu:theMenu];

	[dialog setFrameTopLeftPoint:location];

	[dialog makeKeyAndOrderFront:nil];

	// Send a right-click to order front the context menu
	NSEvent *theEvent = [NSEvent
	        mouseEventWithType:NSRightMouseDown
	        location:NSMakePoint(1,1)
	        modifierFlags:0
	        timestamp:1
	        windowNumber:[dialog windowNumber]
	        context:[NSGraphicsContext currentContext]
	        eventNumber:0
	        clickCount:1
	        pressure:0.0];

	[[NSApplication sharedApplication] sendEvent:theEvent];

	while([dialog waitForChoice] && [[[NSApp keyWindow] firstResponder] isKindOfClass:[SPChooseMenuItemDialogTextView class]]) {

		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                          untilDate:[NSDate distantFuture]
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES];

		if(!event) continue;

		[NSApp sendEvent:event];

		usleep(1000);

	}

	[dialog performSelector:@selector(close) withObject:nil afterDelay:0.01];

	return [dialog selectedItemIndex];
}

@end
