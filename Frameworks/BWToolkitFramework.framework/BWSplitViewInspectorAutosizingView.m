//
//  BWSplitViewInspectorAutosizingView.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSplitViewInspectorAutosizingView.h"
#import "BWSplitViewInspectorAutosizingButtonCell.h"

@implementation BWSplitViewInspectorAutosizingView

@synthesize splitView;

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect])
	{
		buttons = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)drawRect:(NSRect)aRect
{
	aRect = self.bounds;
	
	if ([[self subviews] count] > 0)
	{
		[[NSColor windowBackgroundColor] set];
		NSRectFill(aRect);
	}
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isVertical
{
	return [splitView isVertical];
}

- (void)layoutButtons
{
	// Remove existing buttons
	[buttons removeAllObjects];
	while ([[self subviews] count] > 0) 
	{
		[[[self subviews] objectAtIndex:0] removeFromSuperview];
	}
	
	// Create new buttons and draw them
	float x, y;
	int numberOfSubviews = [[splitView subviews] count];
	
	for (int i = 0; i < numberOfSubviews; i++)
	{		
		NSRect buttonRect = NSZeroRect;
		
		if ([splitView isVertical])
		{
			if (i != numberOfSubviews - 1)
				buttonRect = NSMakeRect(x, 0, floorf((self.bounds.size.width + numberOfSubviews) / numberOfSubviews), self.bounds.size.height);
			else
				buttonRect = NSMakeRect(x, 0, self.bounds.size.width - x, self.bounds.size.height);
		}
		
		if ([splitView isVertical] == NO)
		{
			if (i != numberOfSubviews - 1)
				buttonRect = NSMakeRect(0, y, self.bounds.size.width, floorf((self.bounds.size.height + numberOfSubviews) / numberOfSubviews));
			else
				buttonRect = NSMakeRect(0, y, self.bounds.size.width, self.bounds.size.height - y);
		}
		
		NSButton *subviewButton = [[[NSButton alloc] initWithFrame:buttonRect] autorelease];
		[subviewButton setCell:[[[BWSplitViewInspectorAutosizingButtonCell alloc] initTextCell:@""] autorelease]];
		[subviewButton setTarget:self];
		[subviewButton setAction:@selector(updateValues:)];
		[subviewButton setTag:i];
		
		// Make the new buttons represent whether the subviews are set to resize or not
		if ([splitView isVertical])
		{
			if ([[[splitView subviews] objectAtIndex:i] autoresizingMask] & NSViewWidthSizable)
				[subviewButton setIntValue:1];
		}
		else
		{
			if ([[[splitView subviews] objectAtIndex:i] autoresizingMask] & NSViewHeightSizable)
				[subviewButton setIntValue:1];
		}
		
		if ([splitView isVertical] && numberOfSubviews < 6 || ![splitView isVertical] && numberOfSubviews < 4)
			[self addSubview:subviewButton];
		
		[buttons addObject:subviewButton];
		
		x += buttonRect.size.width - 1;
		y += buttonRect.size.height - 1;
	}
	
	// At least 1 subview must be resizable, so if none of the subviews are set to resize, then we'll set all subviews to resize (which will make it the default state)
	BOOL resizableViewExists = NO;
	for (NSButton *button in buttons)
	{
		if ([button intValue] == 1)
			resizableViewExists = YES;
	}
	
	if (resizableViewExists == NO)
	{
		for (NSButton *button in buttons)
		{
			[button setIntValue:1];
			
			NSView *subviewForButton = [[splitView subviews] objectAtIndex:[button tag]];
			int mask = [subviewForButton autoresizingMask];
			
			if ([splitView isVertical])
				[subviewForButton setAutoresizingMask:(mask | NSViewWidthSizable)];
			else
				[subviewForButton setAutoresizingMask:(mask | NSViewHeightSizable)];
		}
	}
}

- (void)updateValues:(id)sender
{
	// Make sure there is always at least one resizable view
	NSView *subviewForSender = [[splitView subviews] objectAtIndex:[sender tag]];
	
	BOOL resizableViewExists = NO;
	for (NSButton *button in buttons)
	{
		if ([button intValue] == 1)
			resizableViewExists = YES;
	}
	
	if (resizableViewExists == NO)
		[sender setIntValue:1];
	
	// Set the autorezising mask on the subview according to the button state
	int mask = [subviewForSender autoresizingMask];
	
	if ([splitView isVertical])
	{
		if ([sender intValue] == 1)
			[subviewForSender setAutoresizingMask:(mask | NSViewWidthSizable)];
		else
			[subviewForSender setAutoresizingMask:(mask & ~NSViewWidthSizable)];
	}
	else
	{
		if ([sender intValue] == 1)
			[subviewForSender setAutoresizingMask:(mask | NSViewHeightSizable)];
		else
			[subviewForSender setAutoresizingMask:(mask & ~NSViewHeightSizable)];
	}
}

- (void)dealloc
{
	[buttons release];
	[super dealloc];
}

@end