//
//  $Id$
//
//  GenerateThumbnailForURL.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Aug 04, 2010
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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>


/* -----------------------------------------------------------------------------
Generate a thumbnail for file

This function's job is to create thumbnail for designated file as fast as possible
----------------------------------------------------------------------------- */


void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
	// implement only if supported
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)

{
	return noErr;

	// The following code is meant as example maybe for the future

	// NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	// 
	// NSData *thumbnailData = [NSData dataWithContentsOfFile:@"appicon.icns"];
	// if ( thumbnailData == nil || [thumbnailData length] == 0 ) {
	// 	// Nothing Found. Don't care.
	// 	[pool release];
	// 	return noErr;
	// }
	// 
	// NSSize canvasSize = NSMakeSize((NSInteger)(maxSize.height/1.3f), maxSize.height);
	// 
	// // Thumbnail will be drawn with maximum resolution for desired thumbnail request
	// // Here we create a graphics context to draw the Quick Look Thumbnail in.
	// CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&canvasSize, true, NULL);
	// if(cgContext) {
	// 	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:YES];
	// 	if(context) {
	// 		//These two lines of code are just good safe programming...
	// 		[NSGraphicsContext saveGraphicsState];
	// 		[NSGraphicsContext setCurrentContext:context];
	// 
	// 		// [context setCompositingOperation:NSCompositeSourceOver];
	// 		// CGContextSetAlpha(cgContext, 0.5);
	// 
	// 		NSBitmapImageRep *thumbnailBitmap = [NSBitmapImageRep imageRepWithData:thumbnailData];
	// 		[thumbnailBitmap drawInRect:NSMakeRect(10,10,200,200)];
	// 
	// 		//This line sets the context back to what it was when we're done
	// 		[NSGraphicsContext restoreGraphicsState];
	// 	}
	// 
	// 	// When we are done with our drawing code QLThumbnailRequestFlushContext() is called to flush the context
	// 	QLThumbnailRequestFlushContext(thumbnail, cgContext);
	// 
	// 	CFRelease(cgContext);
	// }
	// 
	// [pool release];
	// return noErr;

}