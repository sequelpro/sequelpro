//
//  ImageAndTextCell.m
//
//  Copyright (c) 2006, Apple. All rights reserved.
//
//  IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
//  consideration of your agreement to the following terms, and your use, installation, 
//  modification or redistribution of this Apple software constitutes acceptance of these 
//  terms.  If you do not agree with these terms, please do not use, install, modify or 
//  redistribute this Apple software.
//   
//  In consideration of your agreement to abide by the following terms, and subject to these 
//  terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in 
//  this original Apple software (the "Apple Software"), to use, reproduce, modify and 
//  redistribute the Apple Software, with or without modifications, in source and/or binary 
//  forms; provided that if you redistribute the Apple Software in its entirety and without 
//  modifications, you must retain this notice and the following text and disclaimers in all 
//  such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
//  or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
//  the Apple Software without specific prior written permission from Apple. Except as expressly
//  stated in this notice, no other rights or licenses, express or implied, are granted by Apple
//  herein, including but not limited to any patent rights that may be infringed by your 
//  derivative works or by other works in which the Apple Software may be incorporated.
//   
//  The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
//  EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
//  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
//  USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//   
//  IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
//  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
//  REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
//  WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
//  OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ImageAndTextCell.h"

@implementation ImageAndTextCell

- (id)init
{
	self = [super init];
	image = nil;

	return self;
}

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
		imageFrame.origin.y += ceilf((cellFrame.size.height - imageFrame.size.height) / 2);
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

		imageFrame.origin.y += ceilf((cellFrame.size.height - imageFrame.size.height) / 2) - 1;

		[image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:nil];
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

		imageFrame.origin.y += ceilf((cellFrame.size.height - imageFrame.size.height) / 2);

		[image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:nil];
	}

	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	
	cellSize.width += (image ? [image size].width : 0) + ((1 - MIN(1,INDENT_AMOUNT)) * 3) + (INDENT_AMOUNT * _indentationLevel) + 2;
	cellSize.height += image ? 2 : 8;
	
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
