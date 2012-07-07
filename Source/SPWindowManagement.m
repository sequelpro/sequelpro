//
//  $Id$
//
//  SPWindowManagement.m
//  Sequel Pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 7, 2012
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "SPWindowManagement.h"
#import "SPWindowController.h"
#import "SPDatabaseDocument.h"

@implementation SPAppController (SPWindowManagement)

/**
 * Create a new window, containing a single tab.
 */
- (IBAction)newWindow:(id)sender
{
	static NSPoint cascadeLocation = {.x = 0, .y = 0};
	
	// Create a new window controller, and set up a new connection view within it.
	SPWindowController *newWindowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	NSWindow *newWindow = [newWindowController window];
	
	// Cascading defaults to on - retrieve the window origin automatically assigned by cascading,
	// and convert to a top left point.
	NSPoint topLeftPoint = [newWindow frame].origin;
	topLeftPoint.y += [newWindow frame].size.height;
	
	// The first window should use autosaving; subsequent windows should cascade.
	// So attempt to set the frame autosave name; this will succeed for the very
	// first window, and fail for others.
	BOOL usedAutosave = [newWindow setFrameAutosaveName:@"DBView"];
	
	if (!usedAutosave) {
		[newWindow setFrameUsingName:@"DBView"];
	}
	
	// Add the connection view
	[newWindowController addNewConnection:self];
	
	// Cascade according to the statically stored cascade location.
	cascadeLocation = [newWindow cascadeTopLeftFromPoint:cascadeLocation];
	
	// Set the window controller as the window's delegate
	[newWindow setDelegate:newWindowController];
	
	// Show the window, and perform frontmost tasks again once the window has drawn
	[newWindowController showWindow:self];
	[[newWindowController selectedTableDocument] didBecomeActiveTabInWindow];
}

/**
 * Create a new tab in the frontmost window.
 */
- (IBAction)newTab:(id)sender
{
	SPWindowController *frontController = nil;
	
	for (NSWindow *aWindow in [NSApp orderedWindows]) 
	{
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			frontController = [aWindow windowController];
			break;
		}
	}
	
	// If no window was found, create a new one
	if (!frontController) {
		[self newWindow:self];
	} 
	else {
		if ([[frontController window] isMiniaturized]) {
			[[frontController window] deminiaturize:self];
		}
		
		[frontController addNewConnection:self];
	}
}

/**
 * Duplicate the current connection tab
 */
- (IBAction)duplicateTab:(id)sender
{
	SPDatabaseDocument *theFrontDocument = [self frontDocument];
	
	if (!theFrontDocument) return [self newTab:sender];
	
	// Add a new tab to the window
	if ([[self frontDocumentWindow] isMiniaturized]) {
		[[self frontDocumentWindow] deminiaturize:self];
	}
	
	[[[self frontDocumentWindow] windowController] addNewConnection:self];
	
	// Get the state of the previously-frontmost document
	NSDictionary *allStateDetails = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithBool:YES], @"connection",
									 [NSNumber numberWithBool:YES], @"history",
									 [NSNumber numberWithBool:YES], @"session",
									 [NSNumber numberWithBool:YES], @"query",
									 [NSNumber numberWithBool:YES], @"password",
									 nil];
	
	NSMutableDictionary *frontState = [NSMutableDictionary dictionaryWithDictionary:[theFrontDocument stateIncludingDetails:allStateDetails]];
	
	// Ensure it's set to autoconnect
	[frontState setObject:[NSNumber numberWithBool:YES] forKey:@"auto_connect"];
	
	// Set the connection on the new tab
	[[self frontDocument] setState:frontState];
}

/**
 * Retrieve the frontmost document window; returns nil if not found.
 */
- (NSWindow *)frontDocumentWindow
{
	for (NSWindow *aWindow in [NSApp orderedWindows]) {
		if ([[aWindow windowController] isMemberOfClass:[SPWindowController class]]) {
			return aWindow;
		}
	}
	
	return nil;
}

/**
 * When tab drags start, bring all the windows in front of other applications.
 */
- (void)tabDragStarted:(id)sender
{
	[NSApp arrangeInFront:self];
}

@end
