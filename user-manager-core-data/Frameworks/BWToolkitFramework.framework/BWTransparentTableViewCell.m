//
//  BWTransparentTableViewCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentTableViewCell.h"

@implementation BWTransparentTableViewCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if (![[self title] isEqualToString:@""])
	{
		NSColor *textColor;
		
		if (!self.isHighlighted)
			textColor = [NSColor colorWithCalibratedWhite:(198.0f / 255.0f) alpha:1];
		else
			textColor = [NSColor whiteColor];
		
		NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
		[attributes addEntriesFromDictionary:[[self attributedStringValue] attributesAtIndex:0 effectiveRange:NULL]];
		[attributes setObject:textColor forKey:NSForegroundColorAttributeName];
		[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
		
		NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:[self title] attributes:attributes] autorelease];
		[self setAttributedStringValue:string];
	}
	
	cellFrame.size.width -= 1;
	cellFrame.origin.x += 1;
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

#pragma mark RSVerticallyCenteredTextFieldCell
// RSVerticallyCenteredTextFieldCell courtesy of Daniel Jalkut
// http://www.red-sweater.com/blog/148/what-a-difference-a-cell-makes

- (NSRect)drawingRectForBounds:(NSRect)theRect
{
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds:theRect];
	
	// When the text field is being 
	// edited or selected, we have to turn off the magic because it screws up 
	// the configuration of the field editor.  We sneak around this by 
	// intercepting selectWithFrame and editWithFrame and sneaking a 
	// reduced, centered rect in at the last minute.
	if (mIsEditingOrSelecting == NO)
	{
		// Get our ideal size for current text
		NSSize textSize = [self cellSizeForBounds:theRect];
		
		// Center that in the proposed rect
		float heightDelta = newRect.size.height - textSize.height;	
		if (heightDelta > 0)
		{
			newRect.size.height -= heightDelta;
			newRect.origin.y += (heightDelta / 2);
		}
	}
	
	return newRect;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	aRect = [self drawingRectForBounds:aRect];
	mIsEditingOrSelecting = YES;	
	[super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
	mIsEditingOrSelecting = NO;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{	
	aRect = [self drawingRectForBounds:aRect];
	mIsEditingOrSelecting = YES;
	[super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
	mIsEditingOrSelecting = NO;
}

@end
