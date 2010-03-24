//
//  $Id$
//
//  SPFieldEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 16, 2009
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

#import "SPFieldEditorController.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPDataAdditions.h"
#import "QLPreviewPanel.h"
#import "SPDataCellFormatter.h"
#import "RegexKitLite.h"
#import "SPDataCellFormatter.h"
#import "SPTooltip.h"
#import "SPConstants.h"

@implementation SPFieldEditorController

- (id)init
{
	if ((self = [super initWithWindowNibName:@"FieldEditorSheet"])) {
		// force the nib to be loaded
		(void) [self window];
		counter = 0;
		maxTextLength = 0;
		stringValue = nil;
		
		prefs = [NSUserDefaults standardUserDefaults];

		// Used for max text length recognition if last typed char is a non-space char
		editTextViewWasChanged = NO;

		// Allow the user to enter cmd+return to close the edit sheet in addition to fn+return
		[editSheetOkButton setKeyEquivalentModifierMask:NSCommandKeyMask];
		
		allowUndo = NO;
		selectionChanged = NO;
		
		tmpDirPath = NSTemporaryDirectory();
		tmpFileName = nil;
		
		NSMenu *menu = [editSheetQuickLookButton menu];
		[menu setAutoenablesItems:NO];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Interpret data as:", @"Interpret data as:") action:NULL keyEquivalent:@""];
		[item setTag:1];
		[item setEnabled:NO];
		[menu addItem:item];
		[item release];
		NSUInteger tag = 2;

		// Load default QL types
		NSMutableArray *qlTypesItems = [[NSMutableArray alloc] init];
		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;

		NSData *defaultTypeData = [NSData dataWithContentsOfFile:[NSBundle pathForResource:@"EditorQuickLookTypes.plist" ofType:nil inDirectory:[[NSBundle mainBundle] bundlePath]] 
			options:NSMappedRead error:&readError];

		NSDictionary *defaultQLTypes = [NSPropertyListSerialization propertyListFromData:defaultTypeData 
				mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError];
		if(defaultQLTypes == nil || readError != nil || convError != nil)
			NSLog(@"Error while reading 'EditorQuickLookTypes.plist':\n%@\n%@", [readError localizedDescription], convError);
		if(defaultQLTypes != nil && [defaultQLTypes objectForKey:@"QuickLookTypes"]) {
			for(id type in [defaultQLTypes objectForKey:@"QuickLookTypes"]) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithString:[type objectForKey:@"MenuLabel"]] action:NULL keyEquivalent:@""];
				[item setTag:tag];
				[item setAction:@selector(quickLookFormatButton:)];
				[menu addItem:item];
				[item release];
				tag++;
				[qlTypesItems addObject:type];
			}
		}
		// Load user-defined QL types
		if([prefs objectForKey:SPQuickLookTypes]) {
			for(id type in [prefs objectForKey:SPQuickLookTypes]) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithString:[type objectForKey:@"MenuLabel"]] action:NULL keyEquivalent:@""];
				[item setTag:tag];
				[item setAction:@selector(quickLookFormatButton:)];
				[menu addItem:item];
				[item release];
				tag++;
				[qlTypesItems addObject:type];
			}
		}
		qlTypes = [NSDictionary dictionaryWithObject:qlTypesItems forKey:SPQuickLookTypes];
		[qlTypesItems release];
	}
	return self;
	
}

- (void)dealloc
{

	// On Mac OSX 10.6 QuickLook runs non-modal thus order out the panel
	// if still visible
	if([[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] isVisible])
		[[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] orderOut:nil];

	if ( esUndoManager ) [esUndoManager release];
	if ( sheetEditData ) [sheetEditData release];
	[super dealloc];
}

- (void)setTextMaxLength:(unsigned long long)length
{
	maxTextLength = length;
}

- (id)editWithObject:(id)data fieldName:(NSString*)fieldName usingEncoding:(NSStringEncoding)anEncoding 
		isObjectBlob:(BOOL)isFieldBlob isEditable:(BOOL)isEditable withWindow:(NSWindow *)tableWindow
{
	// If required, use monospaced fonts
	if (![prefs objectForKey:SPFieldEditorSheetFont]) {
		[editTextView setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	else {
		[editTextView setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"FieldEditorSheetFont"]]];
	}

	[editTextView setContinuousSpellCheckingEnabled:[prefs boolForKey:SPBlobTextEditorSpellCheckingEnabled]];

	[hexTextView setFont:[NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]]];

	[editSheetFieldName setStringValue:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Field", @"Field"), fieldName]];

	// hide all views in editSheet
	[hexTextView setHidden:YES];
	[hexTextScrollView setHidden:YES];
	[editImage setHidden:YES];
	[editTextView setHidden:YES];
	[editTextScrollView setHidden:YES];
	
	if (!isEditable) {
		[editSheetOkButton setHidden:YES];
		[editSheetCancelButton setHidden:YES];
		[editSheetIsNotEditableCancelButton setHidden:NO];
		[editSheetOpenButton setEnabled:NO];
	}
	
	editSheetWillBeInitialized = YES;
	
	encoding = anEncoding;

	isBlob = isFieldBlob;
	
	sheetEditData = [data retain];
	
	// hide all views in editSheet
	[hexTextView setHidden:YES];
	[hexTextScrollView setHidden:YES];
	[editImage setHidden:YES];
	[editTextView setHidden:YES];
	[editTextScrollView setHidden:YES];
	
	// Hide QuickLook button and text/iamge/hex control for text data
	[editSheetQuickLookButton setHidden:(!isBlob)];
	[editSheetSegmentControl setHidden:(!isBlob)];

	// Set window's min size since no segment and quicklook buttons are hidden
	if (isBlob) {
		[editSheet setFrameAutosaveName:@"SPFieldEditorBlobSheet"];
		[editSheet setMinSize:NSMakeSize(560, 200)];
	} else {
		[editSheet setFrameAutosaveName:@"SPFieldEditorTextSheet"];
		[editSheet setMinSize:NSMakeSize(340, 150)];
	}
	
	[editTextView setEditable:isEditable];
	[editImage setEditable:isEditable];
	
	[NSApp beginSheet:editSheet modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	
	[editSheetProgressBar startAnimation:self];
	
	NSImage *image = nil;
	if ( [sheetEditData isKindOfClass:[NSData class]] ) {
		image = [[[NSImage alloc] initWithData:sheetEditData] autorelease];
		
		// Set hex view to "" - load on demand only
		[hexTextView setString:@""];
		
		stringValue = [[NSString alloc] initWithData:sheetEditData encoding:encoding];
		if (stringValue == nil)
			stringValue = [[NSString alloc] initWithData:sheetEditData encoding:NSASCIIStringEncoding];
		
		[hexTextView setHidden:NO];
		[hexTextScrollView setHidden:NO];
		[editImage setHidden:YES];
		[editTextView setHidden:YES];
		[editTextScrollView setHidden:YES];
		[editSheetSegmentControl setSelectedSegment:2];
	} else {
		stringValue = [sheetEditData retain];
		
		[hexTextView setString:@""];
		
		[hexTextView setHidden:YES];
		[hexTextScrollView setHidden:YES];
		[editImage setHidden:YES];
		[editTextView setHidden:NO];
		[editTextScrollView setHidden:NO];
		[editSheetSegmentControl setSelectedSegment:0];
	}
	
	if (image) {
		[editImage setImage:image];
		
		[hexTextView setHidden:YES];
		[hexTextScrollView setHidden:YES];
		[editImage setHidden:NO];
		[editTextView setHidden:YES];
		[editTextScrollView setHidden:YES];
		[editSheetSegmentControl setSelectedSegment:1];
	} else {
		[editImage setImage:nil];
	}
	if (stringValue) {
		[editTextView setString:stringValue];

		if(image == nil) {
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:YES];
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
			[editSheetSegmentControl setSelectedSegment:0];
		}

		// Locate the caret in editTextView
		// (to select all takes a bit time for large data)
		[editTextView setSelectedRange:NSMakeRange(0,0)];

		// If the string content is NULL select NULL for convenience
		if([stringValue isEqualToString:[prefs objectForKey:SPNullValue]])
			[editTextView setSelectedRange:NSMakeRange(0,[[editTextView string] length])];

		// Set focus
		if(image == nil)
			[editSheet makeFirstResponder:editTextView];
		else
			[editSheet makeFirstResponder:editImage];
		
		[stringValue release], stringValue = nil;
	}
	
	editSheetWillBeInitialized = NO;
	
	[editSheetProgressBar stopAnimation:self];

	// wait for editSheet
	NSModalSession session = [NSApp beginModalSessionForWindow:editSheet];
	NSInteger cycleCounter = 0;
	BOOL doGroupDueToChars = NO;
	for (;;) {

		// Break the run loop if editSheet was closed
		if ([NSApp runModalSession:session] != NSRunContinuesResponse 
			|| ![editSheet isVisible]) 
			break;

		// Execute code on DefaultRunLoop (like displaying a tooltip)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode  
								 beforeDate:[NSDate distantFuture]];

		// Allow undo grouping if user typed a ' ' (for word level undo)
		// or a RETURN but not for each char due to writing speed
		if([[NSApp currentEvent] type] == NSKeyDown 
			&& 	(
				[[[NSApp currentEvent] charactersIgnoringModifiers] isEqualToString:@" "]
				|| [[NSApp currentEvent] keyCode] == 36
				|| [[NSApp currentEvent] modifierFlags] & (NSCommandKeyMask|NSControlKeyMask|NSAlternateKeyMask)
				)) {
			doGroupDueToChars=YES;
		}

		// If conditions match create an undo group
		if( ( wasCutPaste || allowUndo || doGroupDueToChars ) && ![esUndoManager isUndoing] && ![esUndoManager isRedoing] ) {
			allowUndo = NO;
			wasCutPaste = NO;
			doGroupDueToChars = NO;
			selectionChanged = NO;

			cycleCounter = 0;
			while([esUndoManager groupingLevel] > 0) {
				[esUndoManager endUndoGrouping];
				cycleCounter++;
			}
			while([esUndoManager groupingLevel] < cycleCounter)
				[esUndoManager beginUndoGrouping];

			cycleCounter = 0;
		}

	}
	[NSApp endModalSession:session];
	[editSheet orderOut:nil];
	[NSApp endSheet:editSheet];

	// For safety reasons inform QuickLook to quit
	quickLookCloseMarker = 1;

	// Remember spell cheecker status
	[prefs setBool:[editTextView isContinuousSpellCheckingEnabled] forKey:SPBlobTextEditorSpellCheckingEnabled];
	
	return ( editSheetReturnCode && isEditable ) ? sheetEditData : nil;
}

/*
 * Establish and return an UndoManager for editTextView
 */
- (NSUndoManager*)undoManagerForTextView:(NSTextView*)aTextView
{
	if (!esUndoManager)
		esUndoManager = [[NSUndoManager alloc] init];

	return esUndoManager;
}

- (void)setWasCutPaste
{
	wasCutPaste = YES;
}

- (IBAction)closeEditSheet:(id)sender
{

	editSheetReturnCode = 0;

	// Validate the sheet data before saving them.
	// - for max text length (except for NULL value string) select the part which won't be saved
	//   and suppress closing the sheet
	if(sender == editSheetOkButton) {
		if (maxTextLength > 0 && [[editTextView textStorage] length] > maxTextLength && ![[[editTextView textStorage] string] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			[editTextView setSelectedRange:NSMakeRange(maxTextLength, [[editTextView textStorage] length] - maxTextLength)];
			[editTextView scrollRangeToVisible:NSMakeRange([editTextView selectedRange].location,0)];
			[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Text is too long. Maximum text length is set to %llu.", @"Text is too long. Maximum text length is set to %llu."), maxTextLength]];
			return;
		}
		[NSApp stopModal];
		editSheetReturnCode = 1;
	}
	
	// Delete all QuickLook temp files if it was invoked
	if(tmpFileName != nil) {
		NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDirPath error:nil];
		for (NSString *file in dirContents) {
			if ([file hasPrefix:@"SequelProQuickLook"]) {
				if(![[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", tmpDirPath, file] error:NULL]) {
					NSLog(@"QL: Couldn't delete temporary file '%@/%@'.", tmpDirPath, file);
				}
			}
		}
	}
 
	[NSApp abortModal];

}

- (IBAction)openEditSheet:(id)sender
{
	[[NSOpenPanel openPanel] beginSheetForDirectory:nil 
											   file:@"" 
									 modalForWindow:[self window] 
									  modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
										contextInfo:NULL];
}

/*
 * Segement controller for text/image/hex buttons in editSheet
 */
- (IBAction)segmentControllerChanged:(id)sender
{
	switch([sender selectedSegment]){
		case 0: // text
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
			[editImage setHidden:YES];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[[self window] makeFirstResponder:editTextView];
			break;
		case 1: // image
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[[self window] makeFirstResponder:editImage];
			break;
		case 2: // hex - load on demand
			[[self window] makeFirstResponder:hexTextView];
			if([[hexTextView string] isEqualToString:@""]) {
				[editSheetProgressBar startAnimation:self];
				if([sheetEditData isKindOfClass:[NSData class]]) {
					[hexTextView setString:[sheetEditData dataToFormattedHexString]];
				} else {
					[hexTextView setString:[[sheetEditData dataUsingEncoding:encoding allowLossyConversion:YES] dataToFormattedHexString]];
				}
				[editSheetProgressBar stopAnimation:self];
			}
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			[editImage setHidden:YES];
			[hexTextView setHidden:NO];
			[hexTextScrollView setHidden:NO];
			break;
	}
}

/*
 * Saves a file containing the content of the editSheet
 */
- (IBAction)saveEditSheet:(id)sender
{	
	[[NSSavePanel savePanel] beginSheetForDirectory:nil 
											   file:@"" 
									 modalForWindow:[self window] 
									  modalDelegate:self 
									 didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
										contextInfo:NULL];
}

/**
 * Save panel didEndSelector. Writes the current content to disk.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		
		[editSheetProgressBar startAnimation:self];
		
		NSString *fileName = [panel filename];
		
		// Write binary field types directly to the file
		if ( [sheetEditData isKindOfClass:[NSData class]] ) {
			[sheetEditData writeToFile:fileName atomically:YES];
			
		// Write other field types' representations to the file via the current encoding
		} 
		else {
			[[sheetEditData description] writeToFile:fileName
										  atomically:YES
											encoding:encoding
											   error:NULL];
		}
		
		[editSheetProgressBar stopAnimation:self];
	}
}

/**
 * Open panel didEndSelector. Opens the selected file.
 */
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSString *fileName = [panel filename];
		NSString *contents = nil;
		
		editSheetWillBeInitialized = YES;
		
		[editSheetProgressBar startAnimation:self];
		
		// free old data
		if ( sheetEditData != nil ) {
			[sheetEditData release];
		}
		
		// load new data/images
		sheetEditData = [[NSData alloc] initWithContentsOfFile:fileName];
		
		NSImage *image = [[NSImage alloc] initWithData:sheetEditData];
		contents = [[NSString alloc] initWithData:sheetEditData encoding:encoding];
		if (contents == nil)
			contents = [[NSString alloc] initWithData:sheetEditData encoding:NSASCIIStringEncoding];
		
		// set the image preview, string contents and hex representation
		[editImage setImage:image];
		
		
		if(contents)
			[editTextView setString:contents];
		else
			[editTextView setString:@""];
		
		// Load hex data only if user has already displayed them
		if(![[hexTextView string] isEqualToString:@""])
			[hexTextView setString:[sheetEditData dataToFormattedHexString]];
		
		// If the image cell now contains a valid image, select the image view
		if (image) {
			[editSheetSegmentControl setSelectedSegment:1];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			
			// Otherwise deselect the image view
		} else {
			[editSheetSegmentControl setSelectedSegment:0];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:YES];
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
		}
		
		[image release];
		if(contents)
			[contents release];
		[editSheetProgressBar stopAnimation:self];
		editSheetWillBeInitialized = NO;
	}
}

#pragma mark -
#pragma mark QuickLook

- (IBAction)quickLookFormatButton:(id)sender
{
	if(qlTypes != nil && [[qlTypes objectForKey:@"QuickLookTypes"] count] > [sender tag] - 2) {
		NSDictionary *type = [[qlTypes objectForKey:@"QuickLookTypes"] objectAtIndex:[sender tag] - 2];
		[self invokeQuickLookOfType:[type objectForKey:@"Extension"] treatAsText:([[type objectForKey:@"treatAsText"] integerValue])];
	}
}

- (void)createTemporaryQuickLookFileOfType:(NSString *)type treatAsText:(BOOL)isText
{
	// Create a temporary file name to store the data as file
	// since QuickLook only works on files.
	// Alternate the file name to suppress caching by using counter%2.
	tmpFileName = [NSString stringWithFormat:@"%@SequelProQuickLook%d.%@", tmpDirPath, counter%2, type];

	// if data are binary
	if ( [sheetEditData isKindOfClass:[NSData class]] && !isText) {
		[sheetEditData writeToFile:tmpFileName atomically:YES];
		
	// write other field types' representations to the file via the current encoding
	} else {
		
		// if "html" type try to set the HTML charset - not yet completed
		if([type isEqualToString:@"html"]) {

			NSString *enc;
			switch(encoding) {
				case NSASCIIStringEncoding:
				enc = @"US-ASCII";break;
				case NSUTF8StringEncoding:
				enc = @"UTF-8";break;
				case NSISOLatin1StringEncoding:
				enc = @"ISO-8859-1";break;
				default:
				enc = @"US-ASCII";
			}
			[[NSString stringWithFormat:@"<META HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=%@'>%@", enc, [editTextView string]] writeToFile:tmpFileName
										atomically:YES
										encoding:encoding
										error:NULL];
		} else {
			[[sheetEditData description] writeToFile:tmpFileName
										atomically:YES
										encoding:encoding
										error:NULL];
		}
	}
}

/*
 * Opens QuickLook for current data if QuickLook is available
 */
- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText
{

	// Load QL via private framework (SDK 10.5)
	if([[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/QuickLookUI.framework"] load]) {

		[editSheetProgressBar startAnimation:self];

		[self createTemporaryQuickLookFileOfType:type treatAsText:isText];

		counter++;

		// Init QuickLook
		id ql = [NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel];
		
		[[ql delegate] setDelegate:self];
		[ql setURLs:[NSArray arrayWithObject:
					 [NSURL fileURLWithPath:tmpFileName]] currentIndex:0 preservingDisplayState:YES];

		// TODO: No interaction with iChat and iPhoto due to .scriptSuite warning:
		// unknown image format
		[ql setShowsAddToiPhotoButton:NO];
		[ql setShowsiChatTheaterButton:NO];
		// Since we are inside of editSheet we have to avoid full-screen zooming
		// otherwise QuickLook hangs
		[ql setShowsFullscreenButton:NO];
		[ql setEnableDragNDrop:NO];
		// Order out QuickLook with animation effect according to self:previewPanel:frameForURL:
		[ql makeKeyAndOrderFrontWithEffect:2];   // 1 = fade in
		
		// quickLookCloseMarker == 1 break the modal session
		quickLookCloseMarker = 0;
		
		[editSheetProgressBar stopAnimation:self];

		// Run QuickLook in its own modal seesion for event handling
		NSModalSession session = [NSApp beginModalSessionForWindow:ql];
		for (;;) {
			// Conditions for closing QuickLook
			if ([NSApp runModalSession:session] != NSRunContinuesResponse 
				|| quickLookCloseMarker == 1 
				|| ![ql isVisible]) 
				break;
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode  
									 beforeDate:[NSDate distantFuture]];

		}
		[NSApp endModalSession:session];

		// set ql's delegate to nil for dealloc
		[[ql windowController] setDelegate:nil];

	}
	// Load QL via framework (SDK 10.5 but SP runs on 10.6)
	// TODO: This is an hack in order to be able to support QuickLook on Mac OS X 10.5 and 10.6
	// as long as SP will be compiled against SDK 10.5.
	// If SP will be compiled against SDK 10.6 we can use the standard way by using 
	// the QuickLookUI which is part of the Quartz.framework. See Developer example "QuickLookDownloader"
	// file:///Developer/Documentation/DocSets/com.apple.adc.documentation.AppleSnowLeopard.CoreReference.docset/Contents/Resources/Documents/samplecode/QuickLookDownloader/index.html#//apple_ref/doc/uid/DTS40009082
	else if([[NSBundle bundleWithPath:@"/System/Library/Frameworks/Quartz.framework/Frameworks/QuickLookUI.framework"] load]) {

		[editSheetProgressBar startAnimation:self];

		[self createTemporaryQuickLookFileOfType:type treatAsText:isText];

		counter++;

		// TODO: If QL is  visible reload it - but how?
		// Up to now QL will close and the user has to redo it.
		if([[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] isVisible]) {
			[[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] orderOut:nil];
		}

		[[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] makeKeyAndOrderFront:nil];

		[editSheetProgressBar stopAnimation:self];

	} else {
		[SPTooltip showWithObject:[NSString stringWithFormat:@"QuickLook is not available on that platform."]];
	}

}

// QuickLook delegates for SDK 10.6
- (void)beginPreviewPanelControl:(id)panel
{

	// This document is now responsible of the preview panel
	[panel setDelegate:self];
	[panel setDataSource:self];

	// Due to the unknown image format disable image sharing
	[panel setShowsAddToiPhotoButton:NO];

}
// QuickLook delegates for SDK 10.6
- (void)endPreviewPanelControl:(id)panel
{
	// This document loses its responsisibility on the preview panel
	// Until the next call to -beginPreviewPanelControl: it must not
	// change the panel's delegate, data source or refresh it.
}
// QuickLook delegates for SDK 10.6
- (BOOL)acceptsPreviewPanelControl:(id)panel;
{
	return YES;
}
// QuickLook delegates for SDK 10.6
// - (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
// {
// }
// QuickLook delegates for SDK 10.6
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
	return 1;
}
// QuickLook delegates for SDK 10.6
- (id)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index
{
	return [NSURL fileURLWithPath:tmpFileName];
}

// QuickLook delegates for SDK 10.5
// It should return the frame for the item represented by the URL
// If an empty frame is returned then the panel will fade in/out instead
- (NSRect)previewPanel:(NSPanel*)panel frameForURL:(NSURL*)URL
{
	
	// Close modal session defined in invokeQuickLookOfType:
	// if user closes the QuickLook view
	quickLookCloseMarker = 1;
	
	// Return the App's middle point
	NSRect mwf = [[NSApp mainWindow] frame];
	return NSMakeRect(
					  mwf.origin.x+mwf.size.width/2,
					  mwf.origin.y+mwf.size.height/2,
					  5, 5);
	
}
// QuickLook delegates for SDK 10.6
// It should return the frame for the item represented by the URL
// If an empty frame is returned then the panel will fade in/out instead
- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id)item
{
	// Return the App's middle point
	NSRect mwf = [[NSApp mainWindow] frame];
	return NSMakeRect(
					  mwf.origin.x+mwf.size.width/2,
					  mwf.origin.y+mwf.size.height/2,
					  5, 5);
}
// QuickLook delegates for SDK 10.6
// - (id)previewPanel:(id)panel transitionImageForPreviewItem:(id)item contentRect:(NSRect *)contentRect
// {
// 	return [NSImage imageNamed:@"database"];
// }

-(void)processPasteImageData
{

	editSheetWillBeInitialized = YES;
	
	NSImage *image = nil;
	
	image = [[[NSImage alloc] initWithPasteboard:[NSPasteboard generalPasteboard]] autorelease];
	if (image) {
		
		if (nil != sheetEditData) [sheetEditData release];
		
		[editImage setImage:image];
		
		if( sheetEditData ) [sheetEditData release];
		sheetEditData = [[NSData alloc] initWithData:[image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1]];
		
		NSString *contents = [[NSString alloc] initWithData:sheetEditData encoding:encoding];
		if (contents == nil)
			contents = [[NSString alloc] initWithData:sheetEditData encoding:NSASCIIStringEncoding];
		
		// Set the string contents and hex representation
		if(contents)
			[editTextView setString:contents];
		if(![[hexTextView string] isEqualToString:@""])
			[hexTextView setString:[sheetEditData dataToFormattedHexString]];
		
		[contents release];
		
	}
	
	editSheetWillBeInitialized = NO;
}
/*
 * Invoked when the imageView in the connection sheet has the contents deleted
 * or a file dragged and dropped onto it.
 */
- (void)processUpdatedImageData:(NSData *)data
{
	
	editSheetWillBeInitialized = YES;
	
	if (nil != sheetEditData) [sheetEditData release];
	
	// If the image was not processed, set a blank string as the contents of the edit and hex views.
	if ( data == nil ) {
		sheetEditData = [[NSData alloc] init];
		[editTextView setString:@""];
		[hexTextView setString:@""];
		editSheetWillBeInitialized = NO;
		return;
	}
	
	// Process the provided image
	sheetEditData = [[NSData alloc] initWithData:data];
	NSString *contents = [[NSString alloc] initWithData:data encoding:encoding];
	if (contents == nil)
		contents = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	
	// Set the string contents and hex representation
	if(contents)
		[editTextView setString:contents];
	if(![[hexTextView string] isEqualToString:@""])
		[hexTextView setString:[sheetEditData dataToFormattedHexString]];
	
	[contents release];
	editSheetWillBeInitialized = NO;
}

- (IBAction)dropImage:(id)sender
{
	
	// If the image was deleted, set a blank string as the contents of the edit and hex views.
	// The actual dropped image processing is handled by processUpdatedImageData:.
	if ( [editImage image] == nil ) {
		if (nil != sheetEditData) [sheetEditData release];
		sheetEditData = [[NSData alloc] init];
		[editTextView setString:@""];
		[hexTextView setString:@""];
		return;
	}
}

#pragma mark -
#pragma mark Delegates

/*
 Validate editTextView for max text length except for NULL value string
 */
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)r replacementString:(NSString *)replacementString
{

	if(textView == editTextView && maxTextLength > 0 
		&& ![ [[[editTextView textStorage] string] stringByAppendingString:replacementString] isEqualToString:[prefs objectForKey:SPNullValue]]) {

		NSInteger newLength;

		// Auxilary to ensure that eg textViewDidChangeSelection:
		// saves a non-space char + base char if that combination
		// occurs at the end of a sequence of typing before saving
		// (OK button).
		editTextViewWasChanged = ([replacementString length] == 1);

		// Pure attribute changes are ok.
		if (!replacementString) return YES;

		// The exact change isn't known. Disallow the change to be safe.
		if (r.location==NSNotFound) return NO;

		// Length checking while using the Input Manager (eg for Japanese)
		if ([textView hasMarkedText] && maxTextLength > 0 && r.location < maxTextLength)
			// User tries to insert a new char but max text length was already reached - return NO
			if( !r.length  && [[textView textStorage] length] >= maxTextLength ) {
				[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu.", @"Maximum text length is set to %llu."), maxTextLength]];
				[textView unmarkText];
				return NO;
			}
			// otherwise allow it if insertion point is valid for eg 
			// a VARCHAR(3) field filled with two Chinese chars and one inserts the
			// third char by typing its pronounciation "wo" - 2 Chinese chars plus "wo" would give
			// 4 which is larger than max length.
			// TODO this doesn't solve the problem of inserting more than one char. For now
			// that part which won't be saved will be hilited if user pressed the OK button.
			else if (r.location < maxTextLength) 
				return YES;

		// Calculate the length of the text after the change.
		newLength=[[textView textStorage] length]+[replacementString length]-r.length;

		// If it's too long, disallow the change but try 
		// to insert a text chunk partially to maxTextLength.
		if (newLength>maxTextLength) {
			
			if(maxTextLength-[[textView textStorage] length]+[textView selectedRange].length <= [replacementString length]) {
				if(maxTextLength-[[textView textStorage] length]+[textView selectedRange].length)
					[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu. Inserted text was truncated.", @"Maximum text length is set to %llu. Inserted text was truncated."), maxTextLength]];
				else
					[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu.", @"Maximum text length is set to %llu."), maxTextLength]];
				[textView insertText:[replacementString substringToIndex:maxTextLength-[[textView textStorage] length]+[textView selectedRange].length]];
			}
			return NO;
		}

		// Otherwise, allow it.
		return YES;

	}
	return YES;
}

/*
 invoked when the user changes the string in the editSheet
 */
- (void)textViewDidChangeSelection:(NSNotification *)notification
{

	// Do nothing if user really didn't changed text (e.g. for font size changing return)
	if(!editTextViewWasChanged && (editSheetWillBeInitialized 
		|| (([[[notification object] textStorage] editedRange].length == 0)
		&& ([[[notification object] textStorage] changeInLength] == 0)))) {
		// Inform the undo-grouping about the caret movement
		selectionChanged = YES;
		return;
	}

	// clear the image and hex (since i doubt someone can "type" a gif)
	[editImage setImage:nil];
	[hexTextView setString:@""];
	
	// free old data
	if ( sheetEditData != nil ) {
		[sheetEditData release];
	}

	// set edit data to text
	sheetEditData = [[NSString stringWithString:[editTextView string]] retain];
	
}

#pragma -
#pragma TextView delegate methods

/**
 * Traps enter and return key and closes editSheet instead of inserting a linebreak when user hits return.
 */
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	if ( aTextView == editTextView ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
			[[[NSApp currentEvent] characters] isEqualToString:@"\003"] )
		{
			[self closeEditSheet:editSheetOkButton];
			return YES;
		}
	}
	
	return NO;
}

- (void)setAllowedUndo
{
	allowUndo = YES;
}

- (void)textDidChange:(NSNotification *)aNotification
{
	// Allow undo grouping only if the text buffer was really changed. Inform
	// the run loop delayed for larger undo groups.
	[self performSelector:@selector(setAllowedUndo) withObject:nil afterDelay:0.2];
}

@end
