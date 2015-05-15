//
//  SPChooseMenuItemDialog.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on December 3, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPChooseMenuItemDialog.h"

@interface SPChooseMenuItemDialogTextView : NSTextView

- (IBAction)menuItemHandler:(id)sender;

@end

@implementation SPChooseMenuItemDialogTextView

- (id)init;
{
	return [super initWithFrame:NSMakeRect(1, 1, 2, 2)];
}

- (IBAction)menuItemHandler:(id)sender
{
	[(SPChooseMenuItemDialog *)[self delegate] setSelectedItemIndex:[sender tag]];
	[(SPChooseMenuItemDialog *)[self delegate] setWaitForChoice:NO];
}

- (NSMenu *)menuForEvent:(NSEvent *)event 
{
	return [(SPChooseMenuItemDialog *)[self delegate] contextMenu];
}

@end

@implementation SPChooseMenuItemDialog

@synthesize contextMenu;
@synthesize selectedItemIndex;
@synthesize waitForChoice;

- (id)init;
{
	if ((self = [super initWithContentRect:NSMakeRect(1, 1, 2, 2) 
								styleMask:NSBorderlessWindowMask 
								  backing:NSBackingStoreBuffered 
									defer:NO]))
	{
		waitForChoice = YES;
		selectedItemIndex = -1;
	}
	
	return self;
}

- (void)initDialog
{
	[self setReleasedWhenClosed:YES];
	[self setLevel:NSNormalWindowLevel];
	[self setHidesOnDeactivate:YES];
	[self setHasShadow:YES];
	[self setAlphaValue:0.0f];

	dummyTextView = [[SPChooseMenuItemDialogTextView alloc] init];
	
	[dummyTextView setDelegate:self];

	[self setContentView:dummyTextView];
}

+ (NSInteger)withItems:(NSArray*)theList atPosition:(NSPoint)location
{
	if (!theList || ![theList count]) return -1;

	SPChooseMenuItemDialog *dialog = [SPChooseMenuItemDialog new];

	[dialog initDialog];
	
	NSInteger cnt = 0;
	NSMenu *theMenu = [[[NSMenu alloc] init] autorelease];
	
	for (id item in theList) 
	{
		NSMenuItem *aMenuItem = nil;
		
		if ([item isKindOfClass:[NSString class]]) {
			aMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector(menuItemHandler:) keyEquivalent:@""];
		}
		else if([item isKindOfClass:[NSDictionary class]]) {
			NSString *title = ([item objectForKey:@"title"]) ?: @"";
			
			SEL action = ([item objectForKey:@"action"]) ? NSSelectorFromString([item objectForKey:@"action"]) : @selector(menuItemHandler:);
			
			NSString *keyEquivalent = ([item objectForKey:@"key"]) ?: @"";
			
			aMenuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
			
			if ([item objectForKey:@"tooltip"]) {
				[aMenuItem setToolTip:[item objectForKey:@"tooltip"]];
			}
		}

        if (aMenuItem) {
            [aMenuItem setTag:cnt++];
            [theMenu addItem:aMenuItem];
            [aMenuItem release];
        }
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
	        pressure:0.0f];

	[NSApp sendEvent:theEvent];

	while ([dialog waitForChoice] && [[[NSApp keyWindow] firstResponder] isKindOfClass:[SPChooseMenuItemDialogTextView class]]) 
	{
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

#pragma mark -

- (void)dealloc
{
	SPClear(dummyTextView);
	
	[super dealloc];
}

@end
