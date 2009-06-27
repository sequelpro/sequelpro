//
//  BWSplitViewInspector.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSplitViewInspector.h"
#import "NSView+BWAdditions.h"

@interface BWSplitViewInspector (BWSVIPrivate)
- (void)updateControls;
- (BOOL)toggleDividerCheckboxVisibilityWithAnimation:(BOOL)shouldAnimate;
- (void)updateSizeLabels;
@end

@implementation BWSplitViewInspector

@synthesize subviewPopupSelection, subviewPopupContent, collapsiblePopupSelection, collapsiblePopupContent, minUnitPopupSelection, maxUnitPopupSelection, splitView, dividerCheckboxCollapsed;

- (NSString *)viewNibName 
{
    return @"BWSplitViewInspector";
}

- (void)awakeFromNib
{
	[minField setDelegate:self];
	[maxField setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(dividerThicknessChanged:)
												 name:@"BWSplitViewDividerThicknessChanged"
											   object:splitView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(orientationChanged:)
												 name:@"BWSplitViewOrientationChanged"
											   object:splitView];
}

- (void)dividerThicknessChanged:(NSNotification *)notification
{
	[self toggleDividerCheckboxVisibilityWithAnimation:YES];
}

- (void)updateSizeLabels
{
	if ([splitView isVertical])
	{
		[maxLabel setStringValue:@"Max Width"];
		[minLabel setStringValue:@"Min Width"];
	}
	else
	{
		[maxLabel setStringValue:@"Max Height"];
		[minLabel setStringValue:@"Min Height"];
	}
}

- (void)orientationChanged:(NSNotification *)notification
{
	[self updateSizeLabels];
	[self toggleDividerCheckboxVisibilityWithAnimation:YES];
}

- (void)setCollapsiblePopupSelection:(int)index
{
	collapsiblePopupSelection = index;
	
	[splitView setCollapsiblePopupSelection:index];
	[self toggleDividerCheckboxVisibilityWithAnimation:YES];
}

- (void)setSplitView:(BWSplitView *)aSplitView
{
    if (splitView != aSplitView) 
	{
        [splitView release];
        splitView = [aSplitView retain];
		
		[self toggleDividerCheckboxVisibilityWithAnimation:NO];
    }
}

- (void)setDividerCheckboxWantsLayer:(NSString *)flag
{
	if ([flag isEqualToString:@"YES"])
		[dividerCheckbox setWantsLayer:YES];
	else
		[dividerCheckbox setWantsLayer:NO];
}

- (BOOL)toggleDividerCheckboxVisibilityWithAnimation:(BOOL)shouldAnimate
{
	// Conditions that must be met for a visibility switch to take place. If any of them fail, we return early.
	if (dividerCheckboxCollapsed && [splitView dividerThickness] > 1.01 && [splitView collapsiblePopupSelection] != 0) {
	}
	else if (!dividerCheckboxCollapsed && ([splitView dividerThickness] < 1.01 || [splitView collapsiblePopupSelection] == 0)) {
	}
	else
		return NO;
	
	float duration = 0.1, alpha;
	NSRect targetFrame = NSZeroRect;
	
	if (dividerCheckboxCollapsed)
	{
		targetFrame = NSMakeRect([[self view] frame].origin.x, [[self view] frame].origin.y, [[self view] frame].size.width, [[self view] frame].size.height + 20);
		alpha = 1.0;
	}
	else
	{
		targetFrame = NSMakeRect([[self view] frame].origin.x, [[self view] frame].origin.y, [[self view] frame].size.width, [[self view] frame].size.height - 20);
		alpha = 0.0;
	}
		
	[self performSelector:@selector(setDividerCheckboxWantsLayer:) withObject:@"YES" afterDelay:0];
	
	if (shouldAnimate)
	{
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:duration];
		[[dividerCheckbox animator] setAlphaValue:alpha];
		[[[self view] animator] setFrame:targetFrame];
		[NSAnimationContext endGrouping];
		
		if (dividerCheckboxCollapsed)
			[self performSelector:@selector(setDividerCheckboxWantsLayer:) withObject:@"NO" afterDelay:duration];
	}
	else
	{
		[dividerCheckbox setAlphaValue:alpha];
		[[self view] setFrame:targetFrame];
		
		if (dividerCheckboxCollapsed)
			[self performSelector:@selector(setDividerCheckboxWantsLayer:) withObject:@"NO" afterDelay:0];
	}
	
	dividerCheckboxCollapsed = !dividerCheckboxCollapsed;

	return YES;
}

- (void)refresh 
{
	[super refresh];

	if ([[self inspectedObjects] count] > 0)
	{
		[self setSplitView:[[self inspectedObjects] objectAtIndex:0]];
		
		// Populate the subview popup button
		NSMutableArray *content = [[NSMutableArray alloc] init];
		
		for (NSView *subview in [splitView subviews])
		{
			int index = [[splitView subviews] indexOfObject:subview];
			NSString *label = [NSString stringWithFormat:@"Subview %d",index];
			
			if (![[subview className] isEqualToString:@"NSView"])
				label = [label stringByAppendingString:[NSString stringWithFormat:@" - %@",[subview className]]];
			
			[content addObject:label];
		}
		
		[self setSubviewPopupContent:content];
		
		// Populate the collapsible popup button
		if ([splitView isVertical])
			[self setCollapsiblePopupContent:[NSMutableArray arrayWithObjects:@"None", @"Left Pane", @"Right Pane",nil]];
		else
			[self setCollapsiblePopupContent:[NSMutableArray arrayWithObjects:@"None", @"Top Pane", @"Bottom Pane",nil]];
	}
	
	// Refresh autosizing view
	[autosizingView setSplitView:splitView];
	[autosizingView layoutButtons];
	
	[self updateSizeLabels];
	[self updateControls];
}

+ (BOOL)supportsMultipleObjectInspection
{
	return NO;
}

- (void)setMinUnitPopupSelection:(int)index
{
	minUnitPopupSelection = index;
	
	NSNumber *minUnit = [NSNumber numberWithInt:index];
	
	NSMutableDictionary *tempMinUnits = [[[splitView minUnits] mutableCopy] autorelease];
	[tempMinUnits setObject:minUnit forKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
	[splitView setMinUnits:tempMinUnits];
}

- (void)setMaxUnitPopupSelection:(int)index
{
	maxUnitPopupSelection = index;

	NSNumber *maxUnit = [NSNumber numberWithInt:index];
	
	NSMutableDictionary *tempMaxUnits = [[[splitView maxUnits] mutableCopy] autorelease];
	[tempMaxUnits setObject:maxUnit forKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
	[splitView setMaxUnits:tempMaxUnits];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == minField)
	{
		if ([minField stringValue] != nil && [[minField stringValue] isEqualToString:@""] == NO && [[minField stringValue] isEqualToString:@" "] == NO)
		{
			NSNumber *minValue = [NSNumber numberWithInt:[minField intValue]];
			NSMutableDictionary *tempMinValues = [[splitView minValues] mutableCopy];
			[tempMinValues setObject:minValue forKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
			[splitView setMinValues:tempMinValues];
		}
		else
		{
			NSMutableDictionary *tempMinValues = [[splitView minValues] mutableCopy];
			[tempMinValues removeObjectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
			[splitView setMinValues:tempMinValues];
		}
	}
	else if ([aNotification object] == maxField)
	{
		if ([maxField stringValue] != nil && [[maxField stringValue] isEqualToString:@""] == NO && [[maxField stringValue] isEqualToString:@" "] == NO)
		{
			NSNumber *maxValue = [NSNumber numberWithInt:[maxField intValue]];
			NSMutableDictionary *tempMaxValues = [[splitView maxValues] mutableCopy];
			[tempMaxValues setObject:maxValue forKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
			[splitView setMaxValues:tempMaxValues];
		}
		else
		{
			NSMutableDictionary *tempMaxValues = [[splitView maxValues] mutableCopy];
			[tempMaxValues removeObjectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]];
			[splitView setMaxValues:tempMaxValues];
		}
	}
}

- (int)collapsiblePopupSelection
{
	return [splitView collapsiblePopupSelection];
}

- (void)setSubviewPopupSelection:(int)index
{
	subviewPopupSelection = index;
	
	[self updateControls];
}

- (void)updateControls
{
	[minField setObjectValue:[[splitView minValues] objectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]]];
	[maxField setObjectValue:[[splitView maxValues] objectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]]];
	
	[self setMinUnitPopupSelection:[[[splitView minUnits] objectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]] intValue]];
	[self setMaxUnitPopupSelection:[[[splitView maxUnits] objectForKey:[NSNumber numberWithInt:[self subviewPopupSelection]]] intValue]];
}

@end
