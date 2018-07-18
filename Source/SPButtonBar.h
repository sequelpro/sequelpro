//
//  SPButtonBar.h
//  sequel-pro
//
//  Created by Max Lohrmann on 16.07.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
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

/**
 * This view can be used as the background for button bars displayed at the bottom of the window
 * in various places.
 * On 10.14+ it will automatically adapt to the Dark UI mode.
 *
 * Since Apple's complete "documentation" of Dark mode resources consists of "Just use Asset
 * Catalogs. Oh btw, that'll only work in Xcode 10 and OS X 10.14.", I guess this will be the
 * alternative to using file formats that are ten times more volatile than the Mac hardware lineup.
 */
@interface SPButtonBar : NSView
{
	NSImage *lightImage;
	NSImage *darkImage;
}

- (instancetype)init NS_UNAVAILABLE;

@end
