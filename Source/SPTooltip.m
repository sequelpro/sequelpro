//
//  $Id$
//
//  SPTooltip.m
//  sequel-pro
//
//  Created by Hans-J. Bibiko on August 11, 2009.
//
//  This class is based on TextMate's TMDHTMLTip implementation
//  (Dialog plugin) written by Ciarán Walsh and Allan Odgaard.
//   see license: http://svn.textmate.org/trunk/LICENSE
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

#import "SPTooltip.h"



static float slow_in_out (float t)
{
	if(t < 1.0f)
		t = 1.0f / (1.0f + exp((-t*12.0f)+6.0f));
	if(t>1.0f) return 1.0f;
	return t;
}


@interface SPTooltip (Private)
- (void)setContent:(NSString *)content transparent:(BOOL)transparent;
- (void)runUntilUserActivity;
- (void)stopAnimation:(id)sender;
@end

@interface WebView (LeopardOnly)
- (void)setDrawsBackground:(BOOL)drawsBackground;
@end

@implementation SPTooltip
// ==================
// = Setup/teardown =
// ==================
+ (void)showWithObject:(id)content ofType:(NSString *)type transparent:(BOOL)transparent
{
	SPTooltip* tip = [SPTooltip new];
	[tip setFrameTopLeftPoint:[NSEvent mouseLocation]];
	// The tooltip will show itself automatically when the HTML is loaded
	if([type isEqualToString:@"text"]) {
		NSString* html = nil;
		NSMutableString* text = [[(NSString*)content mutableCopy] autorelease];
		if(text)
		{
			[text replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [text length])];
			[text replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [text length])];
			[text insertString:@"<pre>" atIndex:0];
			[text appendString:@"</pre>"];
			html = text;
		}
		else
		{
			html = @"Error";
		}
		[tip setContent:html transparent:transparent];
	}
	else if([type isEqualToString:@"html"])
		[tip setContent:(NSString*)content transparent:transparent];
		
}

+ (void)showWithObject:(id)content atLocation:(NSPoint)point ofType:(NSString *)type transparent:(BOOL)transparent
{
	SPTooltip* tip = [SPTooltip new];
	[tip setFrameTopLeftPoint:point];
	// The tooltip will show itself automatically when the HTML is loaded
	if([type isEqualToString:@"text"]) {
		NSString* html = nil;
		NSMutableString* text = [[(NSString*)content mutableCopy] autorelease];
		if(text)
		{
			[text replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [text length])];
			[text replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [text length])];
			[text insertString:@"<pre>" atIndex:0];
			[text appendString:@"</pre>"];
			html = text;
		}
		else
		{
			html = @"Error";
		}
		[tip setContent:html transparent:transparent];
	}
	else if([type isEqualToString:@"html"])
		[tip setContent:(NSString*)content transparent:transparent];
}

- (id)init;
{
	if(self = [self initWithContentRect:NSMakeRect(1,1,1,1) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		[self setReleasedWhenClosed:YES];
		[self setAlphaValue:0.97f];
		[self setOpaque:NO];
		[self setBackgroundColor:[NSColor colorWithDeviceRed:1.0f green:0.96f blue:0.76f alpha:1.0f]];
		[self setBackgroundColor:[NSColor clearColor]];
		[self setHasShadow:YES];
		[self setLevel:NSStatusWindowLevel];
		[self setHidesOnDeactivate:YES];
		[self setIgnoresMouseEvents:YES];

		SPTooltipPreferencesIdentifier = @"SequelPro Tooltip";

		webPreferences = [[WebPreferences alloc] initWithIdentifier:SPTooltipPreferencesIdentifier];
		[webPreferences setJavaScriptEnabled:YES];
		NSString *fontName = @"Monaco";
		int fontSize = 12;
		NSFont* font = [NSFont fontWithName:fontName size:fontSize];
		[webPreferences setStandardFontFamily:[font familyName]];
		[webPreferences setDefaultFontSize:fontSize];
		[webPreferences setDefaultFixedFontSize:fontSize];

		webView = [[WebView alloc] initWithFrame:NSZeroRect];
		[webView setPreferencesIdentifier:SPTooltipPreferencesIdentifier];
		[webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[webView setFrameLoadDelegate:self];
		if ([webView respondsToSelector:@selector(setDrawsBackground:)])
		    [webView setDrawsBackground:NO];

		[self setContentView:webView];
	}
	return self;
}

- (void)dealloc
{
	[didOpenAtDate release];
	[webView release];
	[webPreferences release];
	[super dealloc];
}

// ===========
// = Webview =
// ===========
- (void)setContent:(NSString *)content transparent:(BOOL)transparent
{
	NSString *fullContent =	@"<html>"
				@"<head>"
				@"  <style type='text/css' media='screen'>"
				@"      body {"
				@"          background: %@;"
				@"          margin: 0;"
				@"          padding: 2px;"
				@"          overflow: hidden;"
				@"          display: table-cell;"
				@"          max-width: 800px;"
				@"      }"
				@"      pre { white-space: pre-wrap; }"
				@"  </style>"
				@"</head>"
				@"<body>%@</body>"
				@"</html>";

	fullContent = [NSString stringWithFormat:fullContent, transparent ? @"transparent" : @"#F6EDC3", content];
	[[webView mainFrame] loadHTMLString:fullContent baseURL:nil];
}

- (void)sizeToContent
{
	// Current tooltip position
	NSPoint pos = NSMakePoint([self frame].origin.x, [self frame].origin.y + [self frame].size.height);

	// Find the screen which we are displaying on
	NSRect screenFrame = [[NSScreen mainScreen] frame];
	NSScreen* candidate;
	for(candidate in [NSScreen screens])
	{
		if(NSMinX([candidate frame]) < pos.x && NSMinX([candidate frame]) > NSMinX(screenFrame))
			screenFrame = [candidate frame];
	}

	// The webview is set to a large initial size and then sized down to fit the content
	[self setContentSize:NSMakeSize(screenFrame.size.width - screenFrame.size.width / 3.0f , screenFrame.size.height)];

	int height  = [[[webView windowScriptObject] evaluateWebScript:@"document.body.offsetHeight + document.body.offsetTop;"] intValue];
	int width   = [[[webView windowScriptObject] evaluateWebScript:@"document.body.offsetWidth + document.body.offsetLeft;"] intValue];
	
	[webView setFrameSize:NSMakeSize(width, height)];

	NSRect frame      = [self frameRectForContentRect:[webView frame]];
	frame.size.width  = MIN(NSWidth(frame), NSWidth(screenFrame));
	frame.size.height = MIN(NSHeight(frame), NSHeight(screenFrame));

	
	[self setFrame:frame display:NO];

	pos.x = MAX(NSMinX(screenFrame), MIN(pos.x, NSMaxX(screenFrame)-NSWidth(frame)));
	pos.y = MIN(MAX(NSMinY(screenFrame)+NSHeight(frame), pos.y), NSMaxY(screenFrame));

	[self setFrameTopLeftPoint:pos];
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame;
{
	[self sizeToContent];
	[self orderFront:self];
	[self performSelector:@selector(runUntilUserActivity) withObject:nil afterDelay:0];
}

// ==================
// = Event handling =
// ==================
- (BOOL)shouldCloseForMousePosition:(NSPoint)aPoint
{
	float ignorePeriod = [[NSUserDefaults standardUserDefaults] floatForKey:@"OakToolTipMouseMoveIgnorePeriod"];
	if(-[didOpenAtDate timeIntervalSinceNow] < ignorePeriod)
		return NO;

	if(NSEqualPoints(mousePositionWhenOpened, NSZeroPoint))
	{
		mousePositionWhenOpened = aPoint;
		return NO;
	}

	NSPoint p = mousePositionWhenOpened;
	float deltaX = p.x - aPoint.x;
	float deltaY = p.y - aPoint.y;
	float dist = sqrtf(deltaX * deltaX + deltaY * deltaY);

	float moveThreshold = 2;
	return dist > moveThreshold;
}

- (void)runUntilUserActivity
{
	[self setValue:[NSDate date] forKey:@"didOpenAtDate"];
	mousePositionWhenOpened = NSZeroPoint;

	NSWindow* keyWindow = [[NSApp keyWindow] retain];
	BOOL didAcceptMouseMovedEvents = [keyWindow acceptsMouseMovedEvents];
	[keyWindow setAcceptsMouseMovedEvents:YES];
	NSEvent* event;
	while(event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES])
	{
		[NSApp sendEvent:event];

		if([event type] == NSLeftMouseDown || [event type] == NSRightMouseDown || [event type] == NSOtherMouseDown || [event type] == NSKeyDown || [event type] == NSScrollWheel)
			break;

		if([event type] == NSMouseMoved && [self shouldCloseForMousePosition:[NSEvent mouseLocation]])
			break;

		if(keyWindow != [NSApp keyWindow] || ![NSApp isActive])
			break;
	}

	[keyWindow setAcceptsMouseMovedEvents:didAcceptMouseMovedEvents];
	[keyWindow release];

	[self orderOut:self];
}

// =============
// = Animation =
// =============
- (void)orderOut:(id)sender
{
	if(![self isVisible] || animationTimer)
		return;

	[self stopAnimation:self];
	[self setValue:[NSDate date] forKey:@"animationStart"];
	[self setValue:[NSTimer scheduledTimerWithTimeInterval:0.02f target:self selector:@selector(animationTick:) userInfo:nil repeats:YES] forKey:@"animationTimer"];
}

- (void)animationTick:(id)sender
{
	float alpha = 0.97f * (1.0f - slow_in_out(-1.5 * [animationStart timeIntervalSinceNow]));
	if(alpha > 0.0f)
	{
		[self setAlphaValue:alpha];
	}
	else
	{
		[super orderOut:self];
		[self stopAnimation:self];
		[self close];
	}
}

- (void)stopAnimation:(id)sender;
{
	if(animationTimer)
	{
		[[self retain] autorelease];
		[animationTimer invalidate];
		[self setValue:nil forKey:@"animationTimer"];
		[self setValue:nil forKey:@"animationStart"];
		[self setAlphaValue:0.97f];
	}
}
@end
