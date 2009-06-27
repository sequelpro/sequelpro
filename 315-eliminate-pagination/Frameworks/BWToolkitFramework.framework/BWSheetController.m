//
//  BWSheetController.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSheetController.h"
#import "NSWindow-NSTimeMachineSupport.h"

@implementation BWSheetController

@synthesize parentWindow, sheet, delegate;

- (void)awakeFromNib
{
	// Hack so the sheet doesn't appear at launch in Cocoa Simulator (or in the actual app if "Visible at Launch" is checked)
	[sheet setAlphaValue:0];
	[sheet performSelector:@selector(orderOut:) withObject:nil afterDelay:0];
	
	// If the sheet has a toolbar or a bottom bar, make sure those elements can't move the window (private API)
	if ([sheet respondsToSelector:@selector(setMovable:)])
		[sheet setMovable:NO];
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super init]) != nil)
	{
		NSWindowController *tempSheetController = [decoder decodeObjectForKey:@"BWSCSheet"];
		NSWindowController *tempParentWindowController = [decoder decodeObjectForKey:@"BWSCParentWindow"];
		
		sheet = [tempSheetController window];
		parentWindow = [tempParentWindowController window];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{	
	NSWindowController *tempSheetController = [[[NSWindowController alloc] initWithWindow:sheet] autorelease];
	NSWindowController *tempParentWindowController = [[[NSWindowController alloc] initWithWindow:parentWindow] autorelease];
	
	[coder encodeObject:tempSheetController forKey:@"BWSCSheet"];
	[coder encodeObject:tempParentWindowController forKey:@"BWSCParentWindow"];
}

- (IBAction)openSheet:(id)sender
{
	[sheet setAlphaValue:1];
	[NSApp beginSheet:sheet modalForWindow:parentWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction)closeSheet:(id)sender
{
	[sheet orderOut:nil];
	[NSApp endSheet:sheet];
}

- (IBAction)messageDelegateAndCloseSheet:(id)sender
{
	if (delegate != nil && [delegate respondsToSelector:@selector(shouldCloseSheet:)])
	{	
		if ([delegate performSelector:@selector(shouldCloseSheet:) withObject:sender])	
			[self closeSheet:self];
	}
	else
	{
		[self closeSheet:self];
	}
}


@end
