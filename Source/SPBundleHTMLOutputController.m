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
#import "SPAlertSheets.h"
#import "SPPrintAccessory.h"
#import "SPAppController.h"

@class WebScriptCallFrame;

#pragma mark -

@interface WebView (WebViewPrivate)
- (void) setScriptDebugDelegate:(id) delegate;
@end

@interface WebScriptCallFrame : NSObject
- (id)userInfo;
- (WebScriptCallFrame *)caller;
- (NSString *)functionName;
- (id)exception;
@end

#pragma mark -

@implementation SPBundleHTMLOutputController

@synthesize docTitle;
@synthesize initHTMLSourceString;
@synthesize windowUUID;
@synthesize docUUID;
@synthesize suppressExceptionAlert;

/**
 * Initialisation
 */
- (id)init
{

	if ((self = [super initWithWindowNibName:@"BundleHTMLOutput"])) {

		[[self window] setReleasedWhenClosed:YES];

		[webView setContinuousSpellCheckingEnabled:NO];
		[webView setGroupName:@"SequelProBundleHTMLOutput"];
		[webView setDrawsBackground:YES];
		[webView setEditable:NO];
		[webView setShouldCloseWithWindow:YES];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
		[webView setShouldUpdateWhileOffscreen:NO];
#endif
		suppressExceptionAlert = NO;

	}
	
	return self;

}

- (NSString *)windowNibName
{
	return @"BundleHTMLOutput";
}

- (void)displayHTMLContent:(NSString *)content withOptions:(NSDictionary *)displayOptions
{

	[[self window] orderFront:nil];
	[self setInitHTMLSourceString:content];
	[[webView mainFrame] loadHTMLString:content baseURL:nil];

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
	if(webPreferences) [webPreferences release];
}

- (void)keyDown:(NSEvent *)theEvent
{
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
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

/**
 * Sheet did end method
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

	if([contextInfo isEqualToString:@"saveDocument"]) {
		if (returnCode == NSOKButton) {
			NSString *sourceCode = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('html')[0].outerHTML"];
			NSError *err = nil;
			[sourceCode writeToFile:[sheet filename]
						atomically:YES
						encoding:NSUTF8StringEncoding
						error:&err];
			if(err != nil) {
				SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
								  [NSString stringWithFormat:@"%@", [err localizedDescription]]);
			}
			
		}
	}
}

- (IBAction)printDocument:(id)sender
{

	NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];

	NSSize paperSize = [printInfo paperSize];
	NSRect printableRect = [printInfo imageablePageBounds];

	// Calculate page margins
	CGFloat marginL = printableRect.origin.x;
	CGFloat marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
	CGFloat marginB = printableRect.origin.y;
	CGFloat marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);

	// Make sure margins are symetric and positive
	CGFloat marginLR = MAX(0, MAX(marginL, marginR));
	CGFloat marginTB = MAX(0, MAX(marginT, marginB));

	// Set the margins
	[printInfo setLeftMargin:marginLR];
	[printInfo setRightMargin:marginLR];
	[printInfo setTopMargin:marginTB];
	[printInfo setBottomMargin:marginTB];

	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSFitPagination];
	[printInfo setVerticallyCentered:NO];

	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[webView mainFrame] frameView] documentView] printInfo:printInfo];

	// Perform the print operation on a background thread
	[op setCanSpawnSeparateThread:YES];

	// Add the ability to select the orientation to print panel
	NSPrintPanel *printPanel = [op printPanel];

	[printPanel setOptions:[printPanel options] + NSPrintPanelShowsOrientation + NSPrintPanelShowsScaling + NSPrintPanelShowsPaperSize];

	[op setPrintPanel:printPanel];

	SPPrintAccessory *printAccessory = [[SPPrintAccessory alloc] initWithNibName:@"PrintAccessory" bundle:nil];

	[printAccessory setPrintView:webView];
	[printPanel addAccessoryController:printAccessory];

	[[NSPageLayout pageLayout] addAccessoryController:printAccessory];
	[printAccessory release];

	[op runOperationModalForWindow:[self window]
		delegate:self
		didRunSelector:nil
		contextInfo:nil];

}

- (void)showSourceCode
{
	NSString *sourceCode = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('html')[0].outerHTML"];
	SPBundleHTMLOutputController *c = [[SPBundleHTMLOutputController alloc] init];
	[c displayHTMLContent:[NSString stringWithFormat:@"<pre>%@</pre>", [sourceCode HTMLEscapeString]] withOptions:nil];
	[[NSApp delegate] addHTMLOutputController:c];
}

- (void)saveDocument
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:@"html"];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:@"output" modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"saveDocument"];
}


#pragma mark -

- (void)windowWillClose:(NSNotification *)notification
{
	[[webView mainFrame] loadHTMLString:@"<html></html>" baseURL:nil];
	[webView close];
	[self setInitHTMLSourceString:@""];
	windowUUID = @"";
	docUUID = @"";
	[self release];
}

#pragma mark -

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *webViewMenuItems = [[defaultMenuItems mutableCopy] autorelease];

	[webViewMenuItems addObject:[NSMenuItem separatorItem]];

	NSMenuItem *anItem;
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View Source", @"view html source code menu item title") action:@selector(showSourceCode) keyEquivalent:@""];
	[anItem setEnabled:YES];
	[anItem setTarget:self];
	[webViewMenuItems addObject:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Save Page As…", @"save page as menu item title") action:@selector(saveDocument) keyEquivalent:@""];
	[anItem setEnabled:YES];
	[anItem setTarget:self];
	[webViewMenuItems addObject:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Print Page…", @"print page menu item title") action:@selector(printDocument:) keyEquivalent:@""];
	[anItem setEnabled:YES];
	[anItem setTarget:self];
	[webViewMenuItems addObject:anItem];
	[anItem release];

	return webViewMenuItems;
}

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

- (void)webView:(WebView *)aWebView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{

	NSInteger navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue];

	// sequelpro:// handler
	if([[[request URL] scheme] isEqualToString:@"sequelpro"] && navigationType == WebNavigationTypeLinkClicked) {
		[[NSApp delegate] handleEventWithURL:[request URL]];
		[listener ignore];
	}
	// sp-reveal-file://a_file_path reveals the file in Finder
	else if([[[request URL] scheme] isEqualToString:@"sp-reveal-file"] && navigationType == WebNavigationTypeLinkClicked) {
		[[NSWorkspace sharedWorkspace] selectFile:[[[request mainDocumentURL] absoluteString] substringFromIndex:16] inFileViewerRootedAtPath:nil];
		[listener ignore];
	}
	// sp-open-file://a_file_path opens the file with the default
	else if([[[request URL] scheme] isEqualToString:@"sp-open-file"] && navigationType == WebNavigationTypeLinkClicked) {
		[[NSWorkspace sharedWorkspace] openFile:[[[request mainDocumentURL] absoluteString] substringFromIndex:14]];
		[listener ignore];
	}
	else {

		switch(navigationType) {
			case WebNavigationTypeLinkClicked:
			[[aWebView mainFrame] loadRequest:request];
			[listener use];
			break;
			case WebNavigationTypeReload:
			[[aWebView mainFrame] loadHTMLString:[self initHTMLSourceString] baseURL:nil];
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

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if(error) {
		NSLog(@"%@", [error localizedDescription]);
	}
}

- (void)webView:(WebView *)webView didFailLoadWithError:(NSError*)error forFrame:(WebFrame *)frame
{
	if(error) {
		NSLog(@"%@", [error localizedDescription]);
	}
}

#pragma mark -
#pragma mark JS support

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
	[alert setInformativeText:(message)?:@""];
	[alert setMessageText:@"JavaScript"];
	[alert runModal];
	[alert release];
}

- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[alert setInformativeText:(message)?:@""];
	[alert setMessageText:@"JavaScript"];

	NSUInteger returnCode = [alert runModal];

	[alert release];

	if(returnCode == NSAlertFirstButtonReturn) return YES;
	return NO;
}

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
{

	[windowScriptObject setValue:self forKey:@"system"];
	[webView setScriptDebugDelegate:self];
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if (aSelector == @selector(run:))
		return @"run";
	if (aSelector == @selector(getShellEnvironmentForName:))
		return @"getShellEnvironmentForName";
	if (aSelector == @selector(insertText:))
		return @"insertText";
	if (aSelector == @selector(setText:))
		return @"setText";
	if (aSelector == @selector(setSelectedTextRange:))
		return @"setSelectedTextRange";
	if (aSelector == @selector(makeHTMLOutputWindowKeyWindow))
		return @"makeHTMLOutputWindowKeyWindow";
	if (aSelector == @selector(closeHTMLOutputWindow))
		return @"closeHTMLOutputWindow";
	if (aSelector == @selector(suppressExceptionAlert))
		return @"suppressExceptionAlert";
	return @"";
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
	if (selector == @selector(run:)) {
		return NO;
	}
	if (selector == @selector(getShellEnvironmentForName:)) {
		return NO;
	}
	if (selector == @selector(insertText:)) {
		return NO;
	}
	if (selector == @selector(setText:)) {
		return NO;
	}
	if (selector == @selector(setSelectedTextRange:)) {
		return NO;
	}
	if (selector == @selector(makeHTMLOutputWindowKeyWindow)) {
		return NO;
	}
	if (selector == @selector(closeHTMLOutputWindow)) {
		return NO;
	}
	if (selector == @selector(suppressExceptionAlert)) {
		return NO;
	}
	return YES;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)property {
	if (strcmp(property, "run") == 0) {
		return NO;
	}
	if (strcmp(property, "getShellEnvironmentForName") == 0) {
		return NO;
	}
	if (strcmp(property, "insertText") == 0) {
		return NO;
	}
	if (strcmp(property, "setText") == 0) {
		return NO;
	}
	if (strcmp(property, "setSelectedTextRange") == 0) {
		return NO;
	}
	if (strcmp(property, "makeHTMLOutputWindowKeyWindow") == 0) {
		return NO;
	}
	return YES;
}

- (void)webView:(WebView *)webView failedToParseSource:(NSString *)source baseLineNumber:(NSUInteger)lineNumber fromURL:(NSURL *)url withError:(NSError *)error forWebFrame:(WebFrame *)webFrame
{
	NSString *mes = [NSString stringWithFormat:@"Failed to parse JavaScript source:\nline = %ld\nerror = %@ with\n%@\nfor source = \n%@", lineNumber, [error localizedDescription], [error userInfo], source];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript Parsing Error", @"javascript parsing error")
									 defaultButton:NSLocalizedString(@"OK", @"OK button") 
								   alternateButton:nil 
									  otherButton:nil 
						informativeTextWithFormat:mes];

	[alert setAlertStyle:NSCriticalAlertStyle];
	[alert runModal];
}

- (void)webView:(WebView *)webView exceptionWasRaised:(WebScriptCallFrame *)frame sourceId:(NSInteger)sid line:(NSInteger)lineno forWebFrame:(WebFrame *)webFrame
{

	NSString *mes = [NSString stringWithFormat:@"Exception:\nline = %ld\nfunction = %@\ncaller = %@\nexception = %@", lineno, [frame functionName], [frame caller], [frame userInfo], [frame exception]];

	if([self suppressExceptionAlert]) {
		NSLog(@"%@", mes);
		return;
	}

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript Exception", @"javascript exception")
									 defaultButton:NSLocalizedString(@"OK", @"OK button") 
								   alternateButton:nil 
									  otherButton:nil 
						informativeTextWithFormat:mes];

	[alert setAlertStyle:NSCriticalAlertStyle];
	[alert runModal];
}
/**
 * JavaScript window.system.getShellEnvironmentForName('a_key') function to
 * return the value for key keyName
 */
- (NSString *)getShellEnvironmentForName:(NSString*)keyName
{
	return [[[NSApp delegate] shellEnvironmentForDocument:nil] objectForKey:keyName];
}

/**
 * JavaScript window.system.makeHTMLOutputWindowKeyWindow() function
 * to make the HTML output window the first responder
 */
- (void)makeHTMLOutputWindowKeyWindow
{
	[[self window] makeKeyAndOrderFront:nil];
}

/**
 * JavaScript window.system.makeHTMLOutputWindowKeyWindow() function
 * to close the HTML window
 */
- (void)closeHTMLOutputWindow
{
	[[self window] close];
}

/**
 * JavaScript window.system.insertText(text) function
 * to insert text into the first responder
 */
- (void)insertText:(NSString*)text
{
	id firstResponder = [[NSApp keyWindow] firstResponder];
	if([firstResponder isKindOfClass:[NSTextView class]]) {
		[firstResponder insertText:text];
		return;
	}
	NSBeep();
}

/**
 * JavaScript window.system.setText(text) function
 * to set the content of the first responder to text
 */
- (void)setText:(NSString*)text
{
	id firstResponder = [[NSApp keyWindow] firstResponder];
	if([firstResponder isKindOfClass:[NSTextView class]]) {
		[firstResponder setSelectedRange:NSMakeRange(0, [[firstResponder string] length])];
		[firstResponder insertText:text];
		return;
	}
	NSBeep();
}

/**
 * JavaScript window.system.setSelectedRange({location,length}) function
 * to set the selection range of the first responder
 */
- (void)setSelectedTextRange:(NSString*)range
{
	id firstResponder = [[NSApp keyWindow] firstResponder];
	if([firstResponder isKindOfClass:[NSTextView class]]) {
		NSRange theRange = NSIntersectionRange(NSRangeFromString(range), NSMakeRange(0, [[firstResponder string] length]));
		if(theRange.location != NSNotFound) {
			[firstResponder setSelectedRange:theRange];
		}
		return;
	}
	NSBeep();
}

/**
 * JavaScript window.system.suppressExceptionAlert() function
 * to suppress an exception alert, instead write the message to NSLog
 */
- (void)suppressExceptionAlert
{
	[self setSuppressExceptionAlert:YES];
}

/**
 * JavaScript window.system.run('a_command'|new Array('a_command', 'uuid')) function
 * to return the result of the BASH command a_command
 */
- (NSString *)run:(id)call
{

	NSError *err = nil;
	NSString *command = nil;
	NSString *uuid = nil;

	if([self docUUID] && [[self docUUID] length])
		uuid = [self docUUID];

	if([call isKindOfClass:[NSString class]])
		command = [NSString stringWithString:call];
	else if([[[call class] description] isEqualToString:@"WebScriptObject"]){
		command = [call webScriptValueAtIndex:0];
		uuid = [call webScriptValueAtIndex:1];
	}
	else {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while executing JavaScript BASH command", @"error while executing javascript bash command")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"Passed parameter couldn't be interpreted. Only string or array (with 2 elements) are allowed.", @"Passed parameter couldn't be interpreted. Only string or array (with 2 elements) are allowed.")];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return @"";
	}

	if(!command) return @"No JavaScript command found.";

	NSString *output = nil;
	if(uuid == nil)
		output = [command runBashCommandWithEnvironment:nil atCurrentDirectoryPath:nil error:&err];
	else {
		NSMutableDictionary *theEnv = [NSMutableDictionary dictionary];
		[theEnv addEntriesFromDictionary:[[NSApp delegate] shellEnvironmentForDocument:nil]];
		[theEnv setObject:uuid forKey:SPBundleShellVariableProcessID];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, uuid] forKey:SPBundleShellVariableQueryFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, uuid] forKey:SPBundleShellVariableQueryResultFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, uuid] forKey:SPBundleShellVariableQueryResultStatusFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, uuid] forKey:SPBundleShellVariableQueryResultMetaFile];
		output = [command runBashCommandWithEnvironment:theEnv 
								atCurrentDirectoryPath:nil 
								callerInstance:[NSApp delegate] 
								contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										@"JavaScript", @"name",
										NSLocalizedString(@"General", @"general menu item label"), @"scope",
										uuid, SPBundleFileInternalexecutionUUID,
										nil]
								error:&err];
	}

	if(err != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while executing JavaScript BASH command", @"error while executing javascript bash command")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:[err localizedDescription]];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return @"";
	}

	if(output)
		return output;
	else {
		NSLog(@"No valid output for JavaScript command found.");
		NSBeep();
		return @"";
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
