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


//	Usage:
//	#import "SPTooltip.h"
//	
//	[SPTooltip showWithObject:@"<h1>Hello</h1>I am a <b>tooltip</b>" ofType:@"html" 
//			displayOptions:[NSDictionary dictionaryWithObjectsAndKeys:
//			@"Monaco", @"fontname", 
//			@"#EEEEEE", @"backgroundcolor", 
//			@"20", @"fontsize", 
//			@"transparent", @"transparent", nil]];
//	
//	[SPTooltip  showWithObject:(id)content 
//					atLocation:(NSPoint)point 
//						ofType:(NSString *)type 
//				displayOptions:(NSDictionary *)displayOptions]
//	
//			content: a NSString with the actual content
//			  point: n NSPoint where the tooltip should be shown
//			         if not given it will be shown under the current caret position or
//			         if no caret could be found in the upper left corner of the current window
//			   type: a NSString of: "text", or "html"; no type - 'text' is default
//	 displayOptions: a NSDictionary with the following keys (all values must be of type NSString):
//	                       fontname, fontsize, backgroundcolor (as #RRGGBB), transparent (any value)
//	                 if no displayOptions are passed or if a key doesn't exist the following default
//	                 are taken:
//	                       "Lucida Grande", "10", "#F9FBC5", NO
//	
//	See more possible syntaxa in SPTooltip to init a tooltip

#import "SPTooltip.h"
#import "SPTextViewAdditions.h"

static int spTooltipCounter = 0;

static float slow_in_out (float t)
{
	if(t < 1.0f)
		t = 1.0f / (1.0f + exp((-t*12.0f)+6.0f));
	if(t>1.0f) return 1.0f;
	return t;
}


@interface SPTooltip (Private)
- (void)setContent:(NSString *)content withOptions:(NSDictionary *)displayOptions;
- (void)runUntilUserActivity;
- (void)stopAnimation:(id)sender;
+ (NSPoint)caretPosition;
+ (void)setDisplayOptions:(NSDictionary *)aDict;
- (void)initMeWithOptions:(NSDictionary *)displayOptions;
@end

@interface WebView (LeopardOnly)
- (void)setDrawsBackground:(BOOL)drawsBackground;
@end

@implementation SPTooltip
// ==================
// = Setup/teardown =
// ==================

+ (void)showWithObject:(id)content atLocation:(NSPoint)point
{
	[self showWithObject:content atLocation:point ofType:@"text" displayOptions:[NSDictionary dictionary]];
}

+ (void)showWithObject:(id)content atLocation:(NSPoint)point ofType:(NSString *)type
{
	[self showWithObject:content atLocation:point ofType:type displayOptions:nil];
}

+ (void)showWithObject:(id)content
{
	[self showWithObject:content atLocation:[self caretPosition] ofType:@"text" displayOptions:nil];
}

+ (void)showWithObject:(id)content ofType:(NSString *)type
{
	[self showWithObject:content atLocation:[self caretPosition] ofType:type displayOptions:nil];
}

+ (void)showWithObject:(id)content ofType:(NSString *)type displayOptions:(NSDictionary *)options
{
	[self showWithObject:content atLocation:[self caretPosition] ofType:type displayOptions:options];
}

+ (void)showWithObject:(id)content atLocation:(NSPoint)point ofType:(NSString *)type displayOptions:(NSDictionary *)displayOptions
{

	spTooltipCounter++;
	
	SPTooltip* tip = [SPTooltip new];
	[tip initMeWithOptions:displayOptions];
	[tip setFrameTopLeftPoint:point];

	if([type isEqualToString:@"text"]) {
		NSString* html = nil;
		NSMutableString* text = [[(NSString*)content mutableCopy] autorelease];
		if(text)
		{
			[text replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [text length])];
			[text replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [text length])];
			[text insertString:[NSString stringWithFormat:@"<pre style=\"font-family:'%@';\">", 
				([displayOptions objectForKey:@"fontname"]) ? [displayOptions objectForKey:@"fontname"] : @"Lucida Grande"] 
				atIndex:0];
			[text appendString:@"</pre>"];
			html = text;
		}
		else
		{
			html = @"Error";
		}
		[tip setContent:html withOptions:displayOptions];
	}
	else if([type isEqualToString:@"html"]) {
		[tip setContent:(NSString*)content withOptions:displayOptions];
	}
	else {
		[tip setContent:(NSString*)content withOptions:displayOptions];
		NSBeep();
		NSLog(@"SPTooltip: Type '%@' is not supported. Please use 'text' or 'html'. Tooltip is displayed as type 'html'", type);
	}

}

- (void)initMeWithOptions:(NSDictionary *)displayOptions
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

	webPreferences = [[WebPreferences alloc] initWithIdentifier:@"SequelPro Tooltip"];
	[webPreferences setJavaScriptEnabled:YES];

	NSString *fontName = ([displayOptions objectForKey:@"fontname"]) ? [displayOptions objectForKey:@"fontname"] : @"Lucida Grande";
	int fontSize = ([displayOptions objectForKey:@"fontsize"]) ? [[displayOptions objectForKey:@"fontsize"] intValue] : 10;
	if(fontSize < 5) fontSize = 5;
	
	NSFont* font = [NSFont fontWithName:fontName size:fontSize];
	[webPreferences setStandardFontFamily:[font familyName]];
	[webPreferences setDefaultFontSize:fontSize];
	[webPreferences setDefaultFixedFontSize:fontSize];

	webView = [[WebView alloc] initWithFrame:NSZeroRect];
	[webView setPreferencesIdentifier:@"SequelPro Tooltip"];
	[webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[webView setFrameLoadDelegate:self];
	if ([webView respondsToSelector:@selector(setDrawsBackground:)])
	    [webView setDrawsBackground:NO];

	[self setContentView:webView];
	
}

- (id)init;
{
	if(self = [self initWithContentRect:NSMakeRect(1,1,1,1) 
					styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		;
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

+ (void)setDisplayOptions:(NSDictionary *)aDict
{
	// displayOptions = [NSDictionary dictionaryWithDictionary:aDict];
}

+ (NSPoint)caretPosition
{
	NSPoint pos;
	id fr = [[NSApp keyWindow] firstResponder];

	//If first responder is a textview return the caret position
	if([fr respondsToSelector:@selector(getRangeForCurrentWord)] ) {
		NSRange range = NSMakeRange([fr selectedRange].location,0);
		NSRange glyphRange = [[fr layoutManager] glyphRangeForCharacterRange:range actualCharacterRange:NULL];
		NSRect boundingRect = [[fr layoutManager] boundingRectForGlyphRange:glyphRange inTextContainer:[fr textContainer]];
		boundingRect = [fr convertRect: boundingRect toView: NULL];
		pos = [[fr window] convertBaseToScreen: NSMakePoint(boundingRect.origin.x + boundingRect.size.width,boundingRect.origin.y + boundingRect.size.height)];
		NSFont* font = [fr font];
		pos.y -= [font pointSize]*1.3;
		return pos;
	// Otherwise return the upper left corner of the current keyWindow
	} else {
		pos = [[NSApp keyWindow] frame].origin;
		pos.x += 5;
		pos.y += [[NSApp keyWindow] frame].size.height - 23;
		return pos;
	}
}

// ===========
// = Webview =
// ===========
- (void)setContent:(NSString *)content withOptions:(NSDictionary *)displayOptions
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

	NSString *bgColor = ([displayOptions objectForKey:@"backgroundcolor"]) ? [displayOptions objectForKey:@"backgroundcolor"] : @"#F9FBC5";
	BOOL transparent = ([displayOptions objectForKey:@"transparent"]) ? YES : NO;


	fullContent = [NSString stringWithFormat:fullContent, transparent ? @"transparent" : bgColor, content];
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
	float ignorePeriod = 0.05f;
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

	float moveThreshold = 10;
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
	int eventType;
	while(event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES])
	{
		[NSApp sendEvent:event];
		eventType = [event type];
		if(eventType == NSKeyDown || eventType == NSLeftMouseDown || eventType == NSRightMouseDown || eventType == NSOtherMouseDown || eventType == NSScrollWheel)
			break;

		if(eventType == NSMouseMoved && [self shouldCloseForMousePosition:[NSEvent mouseLocation]])
			break;

		if(keyWindow != [NSApp keyWindow] || ![NSApp isActive])
			break;
		
		if(spTooltipCounter > 1)
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
	[self setValue:[NSTimer scheduledTimerWithTimeInterval:0.01f target:self selector:@selector(animationTick:) userInfo:nil repeats:YES] forKey:@"animationTimer"];
}

- (void)animationTick:(id)sender
{
	float alpha = 0.97f * (1.0f - 40*slow_in_out(-2.2 * [animationStart timeIntervalSinceNow]));

	if(alpha > 0.0f && spTooltipCounter==1)
	{
		[self setAlphaValue:alpha];
	}
	else
	{
		[super orderOut:self];
		[self stopAnimation:self];
		[self close];
		spTooltipCounter--;
		if(spTooltipCounter < 0) spTooltipCounter = 0;
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
