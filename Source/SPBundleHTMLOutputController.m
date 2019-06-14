//
//  SPBundleHTMLOutputController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 12, 2010.
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

#import "SPBundleHTMLOutputController.h"
#import "SPAlertSheets.h"
#import "SPPrintAccessory.h"
#import "SPAppController.h"
#import "SPBundleCommandRunner.h"

static NSString *SPSaveDocumentAction = @"SPSaveDocument";

@class WebScriptCallFrame;

#pragma mark -

@interface WebView (WebViewPrivate)

- (void)setScriptDebugDelegate:(id) delegate;

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
@synthesize suppressExceptionAlerting;

- (id)init
{
	if ((self = [super initWithWindowNibName:@"BundleHTMLOutput"])) {
		[webView setContinuousSpellCheckingEnabled:NO];
		[webView setGroupName:@"SequelProBundleHTMLOutput"];
		[webView setDrawsBackground:YES];
		[webView setEditable:NO];
		[webView setShouldCloseWithWindow:YES];
		[webView setShouldUpdateWhileOffscreen:NO];
		suppressExceptionAlerting = NO;
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
	if(webPreferences) SPClear(webPreferences);
	[super dealloc];
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSEventModifierFlags allFlags = (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand);
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	NSEventModifierFlags curFlags = ([theEvent modifierFlags] & allFlags);

	if(curFlags & NSEventModifierFlagCommand) {
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
		if([charactersIgnMod isEqualToString:@"0"]) // return the text size to the default size
		{
			[webView makeTextStandardSize:nil];
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

	if ([contextInfo isEqualToString:SPSaveDocumentAction]) {
		if (returnCode == NSOKButton) {
			NSString *sourceCode = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('html')[0].outerHTML"];
			NSError *err = nil;
			[sourceCode writeToURL:[sheet URL]
						atomically:YES
						encoding:NSUTF8StringEncoding
						error:&err];
			if (err != nil) {
				SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), [self window], [NSString stringWithFormat:@"%@", [err localizedDescription]]);
			}
		}
	}
}

- (IBAction)printDocument:(id)sender
{
#warning duplicate code with -[SPDatabaseDocument webView:didFinishLoadForFrame:]
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

	// do not try to use webkit from a background thread!
	[op setCanSpawnSeparateThread:NO];

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

	[SPAppDelegate addHTMLOutputController:c];
}

- (void)saveDocument
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setNameFieldStringValue:@"output"];
	[panel setAllowedFileTypes:@[@"html"]];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self sheetDidEnd:panel returnCode:returnCode contextInfo:SPSaveDocumentAction];
	}];
}

#pragma mark -

- (void)windowWillClose:(NSNotification *)notification
{
	[[webView mainFrame] loadHTMLString:@"<html></html>" baseURL:nil];

	[webView close];

	[self setInitHTMLSourceString:@""];

	windowUUID = @"";
	docUUID = @"";

	[SPAppDelegate removeHTMLOutputController:self];

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
		[SPAppDelegate addHTMLOutputController:c];
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
		[SPAppDelegate handleEventWithURL:[request URL]];
		[listener ignore];
	}
	// sp-reveal-file://a_file_path reveals the file in Finder
	else if([[[request URL] scheme] isEqualToString:@"sp-reveal-file"] && navigationType == WebNavigationTypeLinkClicked) {
		[[NSWorkspace sharedWorkspace] selectFile:[[[request mainDocumentURL] absoluteString] substringFromIndex:16] inFileViewerRootedAtPath:@""];
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

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
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

+ (BOOL)isKeyExcludedFromWebScript:(const char *)property
{
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
	NSString *mes = [NSString stringWithFormat:@"Failed to parse JavaScript source:\nline = %lu\nerror = %@ with\n%@\nfor source = \n%@", (unsigned long)lineNumber, [error localizedDescription], [error userInfo], source];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript Parsing Error", @"javascript parsing error")
									 defaultButton:NSLocalizedString(@"OK", @"OK button") 
								   alternateButton:nil 
									  otherButton:nil 
						informativeTextWithFormat:@"%@", mes];

	[alert setAlertStyle:NSCriticalAlertStyle];
	[alert runModal];
}

- (void)webView:(WebView *)webView exceptionWasRaised:(WebScriptCallFrame *)frame sourceId:(NSInteger)sid line:(NSInteger)lineno forWebFrame:(WebFrame *)webFrame
{

	NSString *mes = [NSString stringWithFormat:@"Exception:\nline = %lu\nfunction = %@\ncaller = %@\nuserinfo = %@\nexception = %@", (unsigned long)lineno, [frame functionName], [frame caller], [frame userInfo], [frame exception]];

	if([self suppressExceptionAlerting]) {
		NSLog(@"%@", mes);
		return;
	}

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"JavaScript Exception", @"javascript exception")
									 defaultButton:NSLocalizedString(@"OK", @"OK button") 
								   alternateButton:nil 
									  otherButton:nil 
						informativeTextWithFormat:@"%@", mes];

	[alert setAlertStyle:NSCriticalAlertStyle];
	[alert runModal];
}
/**
 * JavaScript window.system.getShellEnvironmentForName('a_key') function to
 * return the value for key keyName
 */
- (NSString *)getShellEnvironmentForName:(NSString*)keyName
{
	return [[SPAppDelegate shellEnvironmentForDocument:nil] objectForKey:keyName];
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

	if ([firstResponder isKindOfClass:[NSTextView class]]) {
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

	if ([firstResponder isKindOfClass:[NSTextView class]]) {
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

	if ([firstResponder isKindOfClass:[NSTextView class]]) {
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
	[self setSuppressExceptionAlerting:YES];
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
		output = [SPBundleCommandRunner runBashCommand:command withEnvironment:nil atCurrentDirectoryPath:nil error:&err];
	else {
		NSMutableDictionary *theEnv = [NSMutableDictionary dictionary];
		[theEnv addEntriesFromDictionary:[SPAppDelegate shellEnvironmentForDocument:nil]];
		[theEnv setObject:uuid forKey:SPBundleShellVariableProcessID];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, uuid] forKey:SPBundleShellVariableQueryFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, uuid] forKey:SPBundleShellVariableQueryResultFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, uuid] forKey:SPBundleShellVariableQueryResultStatusFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, uuid] forKey:SPBundleShellVariableQueryResultMetaFile];
		
		output = [SPBundleCommandRunner runBashCommand:command 
									   withEnvironment:theEnv 
								atCurrentDirectoryPath:nil 
										callerInstance:SPAppDelegate
										   contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
														@"JavaScript", @"name",
														NSLocalizedString(@"General", @"general menu item label"), @"scope",
														uuid, SPBundleFileInternalexecutionUUID, nil]
												 error:&err];
	}

	if(err != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while executing JavaScript BASH command", @"error while executing javascript bash command")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:@"%@", [err localizedDescription]];

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
#pragma mark Multi-touch trackpad support

/**
 * Trackpad two-finger zooming gesture for in/decreasing the font size
 */
- (void)magnifyWithEvent:(NSEvent *)anEvent
{
	if ([anEvent deltaZ] > 2.0) {
		[webView makeTextLarger:nil];
	}
	else if ([anEvent deltaZ] < -2.0) {
		[webView makeTextSmaller:nil];
	}
}

@end
