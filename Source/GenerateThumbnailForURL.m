//
//  GenerateThumbnailForURL.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 4, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail);
OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maximumSize);

/**
 * Generate a thumbnail for file.
 *
 * This function's job is to create thumbnail for designated file as fast as possible.
 */
void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
	// Implement only if supported
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maximumSize)
{
	// The following code is meant as example maybe for the future
#if 0
	@autoreleasepool {
		NSData *thumbnailData = [NSData dataWithContentsOfFile:@"appIcon.icns"];
		if ( thumbnailData == nil || [thumbnailData length] == 0 ) {
			// Nothing Found. Don't care.
			[pool release];
			return noErr;
		}

		NSSize canvasSize = NSMakeSize((NSInteger)(maximumSize.height/1.3f), maximumSize.height);

		// Thumbnail will be drawn with maximum resolution for desired thumbnail request
		// Here we create a graphics context to draw the Quick Look Thumbnail in.
		CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&canvasSize, true, NULL);
		if(cgContext) {
			NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:YES];
			if(context) {
				//These two lines of code are just good safe programming...
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:context];

				// [context setCompositingOperation:NSCompositeSourceOver];
				// CGContextSetAlpha(cgContext, 0.5);

				NSBitmapImageRep *thumbnailBitmap = [NSBitmapImageRep imageRepWithData:thumbnailData];
				[thumbnailBitmap drawInRect:NSMakeRect(10,10,200,200)];

				//This line sets the context back to what it was when we're done
				[NSGraphicsContext restoreGraphicsState];
			}

			// When we are done with our drawing code QLThumbnailRequestFlushContext() is called to flush the context
			QLThumbnailRequestFlushContext(thumbnail, cgContext);

			CFRelease(cgContext);
		}
	}
#endif
	return noErr;
}
