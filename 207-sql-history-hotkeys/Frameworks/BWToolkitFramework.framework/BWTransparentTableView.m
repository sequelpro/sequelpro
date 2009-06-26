//
//  BWTransparentTableView.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentTableView.h"
#import "BWTransparentTableViewCell.h"
#import "BWTransparentCheckboxCell.h"

static NSColor *rowColor, *altRowColor, *highlightColor;

@interface BWTransparentTableView (BWTTVPrivate)
- (void)addObject:(id)object toParent:(id)parent;
- (void)removeObject:(id)object;
@end

@implementation BWTransparentTableView

+ (void)initialize;
{
    rowColor			= [[NSColor colorWithCalibratedWhite:0.13 alpha:0.855] retain];
    altRowColor			= [[NSColor colorWithCalibratedWhite:0.16 alpha:0.855] retain];
	highlightColor		= [[NSColor colorWithCalibratedWhite:(75.0 / 255.0) alpha:0.855] retain];
}

- (void)addTableColumn:(NSTableColumn *)aColumn
{
	[super addTableColumn:aColumn];
	
	if ([[[aColumn dataCell] className] isEqualToString:@"NSTextFieldCell"])
	{
		BWTransparentTableViewCell *cell = [[BWTransparentTableViewCell alloc] init];

		[self removeObject:[aColumn dataCell]];
		[aColumn setDataCell:cell];
		[self addObject:cell toParent:aColumn];
	}
}

+ (Class)cellClass
{
	return [BWTransparentTableViewCell class];
}

// We make this a no-op when there are no alt rows so that the background color is not drawn on top of the window
- (void)drawBackgroundInClipRect:(NSRect)clipRect
{
	if ([self usesAlternatingRowBackgroundColors])
		[super drawBackgroundInClipRect:clipRect];
}

// Color shown when a cell is edited
- (NSColor *)backgroundColor
{
	return rowColor;
}

- (NSArray *)_alternatingRowBackgroundColors
{
	NSArray *colors = [NSArray arrayWithObjects:rowColor,altRowColor,nil];
	
	return colors;
}

- (NSColor *)_highlightColorForCell:(NSCell *)cell
{
	return nil;
}

- (void)highlightSelectionInClipRect:(NSRect)theClipRect
{
	NSRange			aVisibleRowIndexes = [self rowsInRect:theClipRect];
	NSIndexSet *	aSelectedRowIndexes = [self selectedRowIndexes];
	int				aRow = aVisibleRowIndexes.location;
	int				anEndRow = aRow + aVisibleRowIndexes.length;

    for (aRow; aRow < anEndRow; aRow++)
    {
		if([aSelectedRowIndexes containsIndex:aRow])
		{
			NSRect aRowRect = [self rectOfRow:aRow];
			aRowRect.size.height--;

			[NSGraphicsContext saveGraphicsState];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeCopy];
			
			NSColor *startColor = [NSColor colorWithCalibratedWhite:(85.0 / 255.0) alpha:0.855];
			NSColor *endColor = [NSColor colorWithCalibratedWhite:(70.0 / 255.0) alpha:0.855];
			
			NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor] autorelease];
			
			[gradient drawInRect:aRowRect angle:90];
			
			[NSGraphicsContext restoreGraphicsState];
		}
	}
}

@end
