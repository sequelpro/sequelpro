/*
	ImageAndTextCell.m
	Copyright © 2006, Apple Computer, Inc., all rights reserved.

	Subclass of NSTextFieldCell which can display text and an image simultaneously.
*/

#import "ImageAndTextCell.h"

@implementation ImageAndTextCell

- (void)dealloc {
	[image release];
	image = nil;
	[super dealloc];
}

- copyWithZone:(NSZone *)zone
{
	ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
	cell->image = nil;
	if (image) cell->image = [image copyWithZone:zone];
	return cell;
}

- (void)setImage:(NSImage *)anImage
{
	if (anImage != image)
	{
		[image release];
		image = [anImage retain];
	}
}

- (NSImage *)image
{
	return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
	if (image != nil)
	{
		NSRect imageFrame;
		imageFrame.size = [image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += ((1 - MIN(1,INDENT_AMOUNT)) * 3) + (INDENT_AMOUNT * _indentationLevel);
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		return imageFrame;
	}
	else
		return NSZeroRect;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
	if (_indentationLevel != 0) {
		NSRect indentationFrame;
		NSDivideRect(aRect, &indentationFrame, &aRect, (INDENT_AMOUNT * _indentationLevel), NSMinXEdge);
	}
	
	if (image != nil) {
		NSRect imageFrame;
		NSDivideRect (aRect, &imageFrame, &aRect, 3 + [image size].width, NSMinXEdge);
	}
	
	[super editWithFrame:aRect inView: controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	if (_indentationLevel != 0) {
		NSRect indentationFrame;
		NSDivideRect(aRect, &indentationFrame, &aRect, (INDENT_AMOUNT * _indentationLevel), NSMinXEdge);
	}
	
	if (image != nil) {
		NSRect imageFrame;
		NSDivideRect (aRect, &imageFrame, &aRect, 3 + [image size].width, NSMinXEdge);
	}
	
	[super selectWithFrame:aRect inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithExpansionFrame:(NSRect)cellFrame inView:(NSView *)view
{
	if (_indentationLevel != 0)
	{
		NSRect indentationFrame;
		NSDivideRect(cellFrame, &indentationFrame, &cellFrame, (INDENT_AMOUNT * _indentationLevel), NSMinXEdge);
	}
		
	if (image != nil)
	{
		NSSize	imageSize;
		NSRect	imageFrame;

		imageSize = [image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;

		imageFrame.size = imageSize;

		if ([view isFlipped])
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

		imageFrame.origin.y -= 1;

		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	} else
		if (_indentationLevel == 0)
			cellFrame.size.height = [view frame].size.height+2;

	[super drawWithExpansionFrame:cellFrame inView:view];

}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if (_indentationLevel != 0)
	{
		NSRect indentationFrame;
		NSDivideRect(cellFrame, &indentationFrame, &cellFrame, (INDENT_AMOUNT * _indentationLevel), NSMinXEdge);
	}
		
	if (image != nil)
	{
		NSSize	imageSize;
		NSRect	imageFrame;

		imageSize = [image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground])
		{
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;

		if ([controlView isFlipped])
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}

	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (image ? [image size].width : 0) + ((1 - MIN(1,INDENT_AMOUNT)) * 3) + (INDENT_AMOUNT * _indentationLevel) + 2;
	// TODO : this has to be generalized yet
	if (image != nil)
		cellSize.height += 2;
	else
		cellSize.height += 8;
	return cellSize;
}

- (void)setIndentationLevel:(NSInteger)level
{
	_indentationLevel = MAX(0,level);
}

- (NSInteger)IndentationLevel
{
	return _indentationLevel;
}

@end
