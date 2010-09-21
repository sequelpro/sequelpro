//
//  $Id$
//
//  SPImageView.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Sat Sep 06 2003.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPImageView.h"

@implementation SPImageView

/**
 * On a drag and drop, read in dragged files and convert dragged images before passing
 * them to the delegate for further processing
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	id delegateForUse = nil;

	// If the delegate or the delegate's content instance doesn't implement processUpdatedImageData:,
	// return the super's implementation
	if (delegate) {
		if ([delegate respondsToSelector:@selector(processUpdatedImageData:)]) {
			delegateForUse = delegate;
		} else if ( [delegate valueForKey:@"tableContentInstance"]
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
			pngData = [draggedImage representationUsingType:NSPNGFileType properties:nil];
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
				pngData = [bitmapImageRep representationUsingType:NSPNGFileType properties:nil];
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
	id delegateForUse = nil;

	// If the delegate or the delegate's content instance doesn't implement processUpdatedImageData:,
	// return the super's implementation
	if (delegate) {
		if ([delegate respondsToSelector:@selector(processUpdatedImageData:)]) {
			delegateForUse = delegate;
		} else if ( [delegate valueForKey:@"tableContentInstance"]
					&& [[delegate valueForKey:@"tableContentInstance"] respondsToSelector:@selector(processUpdatedImageData:)] ) {
			delegateForUse = [delegate valueForKey:@"tableContentInstance"];
		}
	}
	if (delegateForUse)
		[delegateForUse processPasteImageData];
}

@end
