//
//  SPTooltip.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 11, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

#import <WebKit/WebKit.h>

@interface SPTooltip : NSWindow <WebFrameLoadDelegate>
{
	WebView*		webView;
	WebPreferences*	webPreferences;
	NSTimer*		animationTimer;
	NSDate*			animationStart;

	// ignore mouse moves for the next second
	NSDate*			didOpenAtDate;
	
	NSPoint			mousePositionWhenOpened;
	
	NSString* 		SPTooltipPreferencesIdentifier;
}

+ (void)showWithObject:(id)content atLocation:(NSPoint)point ofType:(NSString *)type displayOptions:(NSDictionary *)displayOptions;
+ (void)showWithObject:(id)content atLocation:(NSPoint)point ofType:(NSString *)type;
+ (void)showWithObject:(id)content atLocation:(NSPoint)point;
+ (void)showWithObject:(id)content ofType:(NSString *)type displayOptions:(NSDictionary *)displayOptions;
+ (void)showWithObject:(id)content ofType:(NSString *)type;
+ (void)showWithObject:(id)content;

- (void)animationTick:(id)sender;

@end
