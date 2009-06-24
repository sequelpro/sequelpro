//
//  BWTransparentCheckboxCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentCheckboxCell.h"
#import "BWTransparentTableView.h"
#import "NSApplication+BWAdditions.h"

static NSImage *checkboxOffN, *checkboxOffP, *checkboxOnN, *checkboxOnP;

@implementation BWTransparentCheckboxCell

+ (void)initialize;
{
	NSBundle *bundle = [NSBundle bundleForClass:[BWTransparentCheckboxCell class]];
	
	checkboxOffN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentCheckboxOffN.tiff"]];
	checkboxOffP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentCheckboxOffP.tiff"]];
	checkboxOnN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentCheckboxOnN.tiff"]];
	checkboxOnP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentCheckboxOnP.tiff"]];
	
	[checkboxOffN setFlipped:YES];
	[checkboxOffP setFlipped:YES];
	[checkboxOnN setFlipped:YES];
	[checkboxOnP setFlipped:YES];
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
	if ([[self controlView] isMemberOfClass:[BWTransparentTableView class]])
	{
		frame.origin.x += 4;
		return [super drawTitle:title withFrame:frame inView:controlView];
	}
	
	return [super drawTitle:title withFrame:frame inView:controlView];
}

- (void)drawImage:(NSImage*)image withFrame:(NSRect)frame inView:(NSView*)controlView
{
	if ([[self controlView] isMemberOfClass:[BWTransparentTableView class]])
		frame.origin.x += 4;
	
	CGFloat y = NSMaxY(frame) - (frame.size.height - checkboxOffN.size.height) / 2.0 - 15;
	CGFloat x = frame.origin.x + 1;
	NSPoint point = NSMakePoint(x, roundf(y));
	
	CGFloat alpha = 1.0;
	
	if (![self isEnabled])
		alpha = 0.6;
	
	if ([self isHighlighted] && [self intValue])
		[checkboxOnP drawAtPoint:point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha];
	else if (![self isHighlighted] && [self intValue])
		[checkboxOnN drawAtPoint:point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha];
	else if (![self isHighlighted] && ![self intValue])
		[checkboxOffN drawAtPoint:point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha];
	else if ([self isHighlighted] && ![self intValue])
		[checkboxOffP drawAtPoint:point fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha];

	if (![[self title] isEqualToString:@""])
	{
		// Style the text differently if the cell is in a table view
		if ([[self controlView] isMemberOfClass:[BWTransparentTableView class]])
		{
			NSColor *textColor;
			
			// Make the text white if the row is selected
			if ([self backgroundStyle] != 1)
				textColor = [NSColor colorWithCalibratedWhite:(198.0f / 255.0f) alpha:1];
			else
				textColor = [NSColor whiteColor];
			
			NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
			[attributes addEntriesFromDictionary:[[self attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
			[attributes setObject:textColor forKey:NSForegroundColorAttributeName];
			[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
			
			NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:[self title] attributes:attributes] autorelease];
			[self setAttributedTitle:string];			
		}
		else
		{
			NSColor *textColor;
			if ([self isEnabled])
				textColor = [NSColor whiteColor];
			else
				textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1];
			
			NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
			[attributes addEntriesFromDictionary:[[self attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
			[attributes setObject:textColor forKey:NSForegroundColorAttributeName];
			
			if ([NSApplication isOnLeopard])
				[attributes setObject:[NSFont boldSystemFontOfSize:11] forKey:NSFontAttributeName];
			else
				[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
			
			NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
			[shadow setShadowOffset:NSMakeSize(0,-1)];
			[attributes setObject:shadow forKey:NSShadowAttributeName];
			
			NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:[self title] attributes:attributes] autorelease];
			[self setAttributedTitle:string];
		}
	}
}

- (NSControlSize)controlSize
{
	return NSSmallControlSize;
}

- (void)setControlSize:(NSControlSize)size
{
	
}

@end
