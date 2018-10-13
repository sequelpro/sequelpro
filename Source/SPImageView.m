//
//  SPImageView.m
//  sequel-pro
//
//  Created by Lorenz textor (lorenz@textor.ch) on Sat September 6, 2003.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPImageView.h"

@implementation SPImageView

/**
 * On a drag and drop, read in dragged files and convert dragged images before passing
 * them to the delegate for further processing
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	id<SPImageViewDelegate> delegateForUse = nil;

	// If the delegate or the delegate's content instance doesn't implement processUpdatedImageData:,
	// return the super's implementation
	if (delegate) {
		if ([delegate respondsToSelector:@selector(processUpdatedImageData:)]) {
			delegateForUse = delegate;
		}
#warning Private ivar accessed from outside (#2978)
		else if ( [delegate valueForKey:@"tableContentInstance"]
					&& [[delegate valueForKey:@"tableContentInstance"] respondsToSelector:@selector(processUpdatedImageData:)] ) {
			delegateForUse = [delegate valueForKey:@"tableContentInstance"];
		}
	}
	if (!delegateForUse) {
		return [super performDragOperation:sender];
	}

	// If a filename is available, attempt to read it and pass it to the delegate
	if ([[[sender draggingPasteboard] propertyListForType:@"NSFilenamesPboardType"] count]) {
		[delegateForUse processUpdatedImageData:[NSData dataWithContentsOfFile:[[[sender draggingPasteboard] propertyListForType:@"NSFilenamesPboardType"] objectAtIndex:0]]];
		return [super performDragOperation:sender];
	}

	// Otherwise, see if a dragged image is available via file contents or TIFF and pass to delegate
	if ([[sender draggingPasteboard] dataForType:@"NSFileContentsPboardType"]) {
		[delegateForUse processUpdatedImageData:[[sender draggingPasteboard] dataForType:@"NSFileContentsPboardType"]];
		return [super performDragOperation:sender];
	}

	// For dragged image representations (in TIFF format), convert to PNG data for compatibility
	if ([[sender draggingPasteboard] dataForType:@"NSTIFFPboardType"]) {
		NSData *pngData = nil;
		NSBitmapImageRep *draggedImage = [[NSBitmapImageRep alloc] initWithData:[[sender draggingPasteboard] dataForType:@"NSTIFFPboardType"]];
		if (draggedImage) {
			pngData = [draggedImage representationUsingType:NSPNGFileType properties:@{}];
			[draggedImage release];
		}
		if (pngData) {
			[delegateForUse processUpdatedImageData:pngData];
			return [super performDragOperation:sender];
		}
	}
	
	// For dragged image representations (in PICT format), convert to PNG data for compatibility
	if ([[sender draggingPasteboard] dataForType:@"NSPICTPboardType"]) {
		NSData *pngData = nil;
		NSPICTImageRep *draggedImage = [[NSPICTImageRep alloc] initWithData:[[sender draggingPasteboard] dataForType:@"NSPICTPboardType"]];
		if (draggedImage) {
			NSImage *convertImage = [[NSImage alloc] initWithSize:[draggedImage size]];
			[convertImage lockFocus];
			[draggedImage drawInRect:[draggedImage boundingBox]];
			NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[draggedImage boundingBox]];
			if (bitmapImageRep) {
				pngData = [bitmapImageRep representationUsingType:NSPNGFileType properties:@{}];
				[bitmapImageRep release];
			}
			[convertImage unlockFocus];
			[convertImage release];
			[draggedImage release];
		}
		if (pngData) {
			[delegateForUse processUpdatedImageData:pngData];
			return [super performDragOperation:sender];
		}
	}

	// The image was not processed - return failure and clear image representation.
	[delegateForUse processUpdatedImageData:nil];
	[self setImage:nil];
	return NO;
}

- (void)paste:(id)sender
{
	// [super paste:sender];
	id<SPImageViewDelegate> delegateForUse = nil;

	// If the delegate or the delegate's content instance doesn't implement processUpdatedImageData:,
	// return the super's implementation
	if (delegate) {
		if ([delegate respondsToSelector:@selector(processUpdatedImageData:)]) {
			delegateForUse = delegate;
		}
#warning Private ivar accessed from outside (#2978)
		else if ( [delegate valueForKey:@"tableContentInstance"]
					&& [[delegate valueForKey:@"tableContentInstance"] respondsToSelector:@selector(processUpdatedImageData:)] ) {
			delegateForUse = [delegate valueForKey:@"tableContentInstance"];
		}
	}
	if (delegateForUse) {
		[delegateForUse processPasteImageData];
	}
}

@end
