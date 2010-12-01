//
//  $Id$
//
//  SPBundleHTMLOutputController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 22, 2010
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


#import "SPBundleHTMLOutputController.h"



@implementation SPBundleHTMLOutputController

@synthesize docTitle;
@synthesize initHTMLSourceString;
@synthesize windowUUID;

/**
 * Initialisation
 */
- (id)init
{

	if (self = [super initWithWindowNibName:@"BundleHTMLOutput"]) {

		[[self window] setReleasedWhenClosed:YES];

	}
	
	return self;

}

- (NSString *)windowNibName
{
	return @"BundleHTMLOutput";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];

	[webView setContinuousSpellCheckingEnabled:NO];
	[webView setGroupName:@"SequelProBundleHTMLOutput"];
	[webView setDrawsBackground:YES];
	[webView setEditable:NO];
	[webView setShouldCloseWithWindow:YES];
	[webView setShouldUpdateWhileOffscreen:NO];

}

- (void)displayHTMLContent:(NSString *)content withOptions:(NSDictionary *)displayOptions
{

	[[self window] orderFront:nil];

	NSString *fullContent = @"%@";
	fullContent = [NSString stringWithFormat:fullContent, content];
	[self setInitHTMLSourceString:fullContent];
	[[webView mainFrame] loadHTMLString:@"<html></html>" baseURL:nil];
	[[webView mainFrame] loadHTMLString:fullContent baseURL:nil];

}

- (void)displayURLString:(NSString *)url withOptions:(NSDictionary *)displayOptions
{

	[[self window] makeKeyAndOrderFront:nil];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];

}

- (id)webView
{
	return webView;
}

- (void)updateWindow
{
	if (docTitle != nil)
		[[webView window] setTitle:docTitle];
	else
		[[webView window] setTitle:@""];
}

- (BOOL)canMakeTextLarger
{
	return YES;
}

- (BOOL)canMakeTextSmaller
{
	return YES;
}

- (void)dealloc
{
	if(webView) [webView release];
	if(webPreferences) [webPreferences release];
	// [super dealloc];
}

- (void)keyDown:(NSEvent *)theEvent
{
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);

	NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	unichar insertedCharacter = [characters characterAtIndex:0];
	long curFlags = ([theEvent modifierFlags] & allFlags);

	if(curFlags & NSCommandKeyMask) {
		if([charactersIgnMod isEqualToString:@"+"] || [charactersIgnMod isEqualToString:@"="]) // increase text size by 1; ⌘+, ⌘=, and ⌘ numpad +
		{
			[webView makeTextLarger:nil];
			return;
		}
		if([charactersIgnMod isEqualToString:@"-"]) // decrease text size by 1; ⌘- and numpad -
		{
			[webView makeTextSmaller:nil];
			return;
		}
		if([theEvent keyCode] == 123) // goBack
		{
			if([webView canGoBack])
				[webView goBack:nil];
			else
				[[webView mainFrame] loadHTMLString:[self initHTMLSourceString] baseURL:nil];
			return;
		}
		if([theEvent keyCode] == 124) // goForward
		{
			[webView goForward:nil];
			return;
		}
	}

	[super keyDown: theEvent];

}

- (IBAction)printDocument:(id)sender
{
	[[[[webView mainFrame] frameView] documentView] print:sender];
}

#pragma mark -

- (void)windowWillClose:(NSNotification *)notification
{
	[[webView mainFrame] loadHTMLString:@"<html></html>" baseURL:nil];
	[webView close];
	[self setInitHTMLSourceString:@""];
	windowUUID = @"";
	// [[notification object] release];
}

#pragma mark -

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request
{
	if(request != nil) {
		SPBundleHTMLOutputController *c = [[SPBundleHTMLOutputController alloc] init];
		[c displayURLString:[[request URL] absoluteString] withOptions:nil];
		[[NSApp delegate] addHTMLOutputController:c];
		return [c webView];
	}
	return nil;
}

- (void)webViewShow:(WebView *)sender
{
	id newWebView = [[NSDocumentController sharedDocumentController] documentForWindow:[sender window]];
	[newWebView showWindows];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	NSInteger navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue];

	// sequelpro:// handler
	if([[[request URL] scheme] isEqualToString:@"sequelpro"] && navigationType == WebNavigationTypeLinkClicked) {
		[[NSApp delegate] handleEventWithURL:[request URL]];
		[listener ignore];
	} else {

		switch(navigationType) {
			case WebNavigationTypeLinkClicked:
			[[webView mainFrame] loadRequest:request];
			[listener use];
			break;
			case WebNavigationTypeReload:
			[[webView mainFrame] loadHTMLString:[self initHTMLSourceString] baseURL:nil];
			break;
			default:
			[listener use];
		}

	}

}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame]) {
		[self setDocTitle:title];
		[self updateWindow];
	}
}

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame;
{
	// Only report feedback for the main frame.
	if (frame == [sender mainFrame]) {
		[self updateWindow];
	}
}

#pragma mark -
#pragma mark multi-touch trackpad support

/**
 * Trackpad two-finger zooming gesture for in/decreasing the font size
 */
- (void)magnifyWithEvent:(NSEvent *)anEvent
{

	if([anEvent deltaZ]>2.0)
		[webView makeTextLarger:nil];
	else if([anEvent deltaZ]<-2.0)
		[webView makeTextSmaller:nil];

}

@end
