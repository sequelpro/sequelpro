//
//  SPFieldEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 16, 2009.
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

#import "SPFieldEditorController.h"
#import "RegexKitLite.h"
#import "SPTooltip.h"
#import "SPGeometryDataView.h"
#import "SPCopyTable.h"
#import "SPWindow.h"
#include <objc/objc-runtime.h>
#import "SPCustomQuery.h"
#import "SPTableContent.h"
#import "SPJSONFormatter.h"

#import <SPMySQL/SPMySQL.h>

typedef enum {
	TextSegment = 0,
	ImageSegment,
	HexSegment
} FieldEditorSegment;

@implementation SPFieldEditorController

@synthesize editedFieldInfo;
@synthesize textMaxLength = maxTextLength;
@synthesize fieldType;
@synthesize fieldEncoding;
@synthesize allowNULL = _allowNULL;

/**
 * Initialise an instance of SPFieldEditorController using the XIB “FieldEditorSheet.xib”. Init the available Quciklook format by reading
 * EditorQuickLookTypes.plist and if given user-defined format store in the Preferences for key (SPQuickLookTypes).
 */
- (id)init
{
#ifndef SP_CODA
	if ((self = [super initWithWindowNibName:@"FieldEditorSheet"]))
#else
	if ((self = [super initWithWindowNibName:@"SQLFieldEditorSheet"]))
#endif
	{
		// force the nib to be loaded
		(void) [self window];
		counter = 0;
		maxTextLength = 0;
		stringValue = nil;
		_isEditable = NO;
		_isBlob = NO;
		_allowNULL = YES;
		_isGeometry = NO;
		contextInfo = nil;
		callerInstance = nil;
		doGroupDueToChars = NO;

		prefs = [NSUserDefaults standardUserDefaults];

		// Used for max text length recognition if last typed char is a non-space char
		editTextViewWasChanged = NO;

		// Allow the user to enter cmd+return to close the edit sheet in addition to fn+return
		[editSheetOkButton setKeyEquivalentModifierMask:NSEventModifierFlagCommand];

		if([editTextView respondsToSelector:@selector(setUsesFindBar:)])
			// 10.7+
			// Stealing the main window from the actual main window will cause
			// a UI bug with the tab bar and the find panel was really the only
			// thing that had an issue with not working with sheets.
			// The find bar works fine without hackery.
			[editTextView setUsesFindBar:YES];
		else {
			// Permit the field edit sheet to become main if necessary; this allows fields within the sheet to
			// support full interactivity, for example use of the NSFindPanel inside NSTextViews.
			[editSheet setIsSheetWhichCanBecomeMain:YES];
		}
		
		[editTextView setAutomaticDashSubstitutionEnabled:NO];
		[editTextView setAutomaticQuoteSubstitutionEnabled:NO];

		allowUndo = NO;
		selectionChanged = NO;

		tmpDirPath = [NSTemporaryDirectory() retain];
		tmpFileName = nil;

		NSMenu *menu = [editSheetQuickLookButton menu];
		[menu setAutoenablesItems:NO];
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Interpret data as:", @"Interpret data as:") action:NULL keyEquivalent:@""];
		[menuItem setTag:1];
		[menuItem setEnabled:NO];
		[menu addItem:menuItem];
		[menuItem release];
#ifndef SP_CODA
		NSUInteger tag = 2;

		// Load default QL types
		NSMutableArray *qlTypesItems = [[NSMutableArray alloc] init];
		NSError *readError = nil;

		NSString *filePath = [NSBundle pathForResource:@"EditorQuickLookTypes.plist"
												ofType:nil
										   inDirectory:[[NSBundle mainBundle] bundlePath]];
		
		NSData *defaultTypeData = [NSData dataWithContentsOfFile:filePath
														 options:NSMappedRead
														   error:&readError];

		NSDictionary *defaultQLTypes = nil;
		if(defaultTypeData && !readError) {
			defaultQLTypes = [NSPropertyListSerialization propertyListWithData:defaultTypeData
																	   options:NSPropertyListImmutable
																		format:NULL
																		 error:&readError];
		}
		
		if(defaultQLTypes == nil || readError ) {
			NSLog(@"Error while reading 'EditorQuickLookTypes.plist':\n%@", readError);
		}
		else if(defaultQLTypes != nil && [defaultQLTypes objectForKey:@"QuickLookTypes"]) {
			for(id type in [defaultQLTypes objectForKey:@"QuickLookTypes"]) {
				NSMenuItem *aMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithString:[type objectForKey:@"MenuLabel"]] action:NULL keyEquivalent:@""];
				[aMenuItem setTag:tag];
				[aMenuItem setAction:@selector(quickLookFormatButton:)];
				[menu addItem:aMenuItem];
				[aMenuItem release];
				tag++;
				[qlTypesItems addObject:type];
			}
		}
		// Load user-defined QL types
		if([prefs objectForKey:SPQuickLookTypes]) {
			for(id type in [prefs objectForKey:SPQuickLookTypes]) {
				NSMenuItem *aMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithString:[type objectForKey:@"MenuLabel"]] action:NULL keyEquivalent:@""];
				[aMenuItem setTag:tag];
				[aMenuItem setAction:@selector(quickLookFormatButton:)];
				[menu addItem:aMenuItem];
				[aMenuItem release];
				tag++;
				[qlTypesItems addObject:type];
			}
		}

		qlTypes = [@{SPQuickLookTypes : qlTypesItems} retain];
		[qlTypesItems release];
#endif

		fieldType = @"";
		fieldEncoding = @"";
	}

	return self;
}

/**
 * Dealloc SPFieldEditorController and closes Quicklook window if visible.
 */
- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

#ifndef SP_CODA
	// On Mac OSX 10.6 QuickLook runs non-modal thus order out the panel
	// if still visible
	if ([[QLPreviewPanel sharedPreviewPanel] isVisible]) {
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	}
#endif

	[self setEditedFieldInfo:nil];
	if ( sheetEditData ) SPClear(sheetEditData);
#ifndef SP_CODA
	if ( qlTypes )       SPClear(qlTypes);
#endif
	if ( tmpFileName )   SPClear(tmpFileName);
	if ( tmpDirPath )    SPClear(tmpDirPath);
	if ( esUndoManager ) SPClear(esUndoManager);
	if ( contextInfo )   SPClear(contextInfo);
	
	[super dealloc];
}

#pragma mark -

/**
 * Main method for editing data. It will validate several settings and display a modal sheet for theWindow whioch waits until the user closes the sheet.
 *
 * @param data The to be edited table field data.
 * @param fieldName The name of the currently edited table field.
 * @param anEncoding The used encoding while editing.
 * @param isFieldBlob If YES the underlying table field is a TEXT/BLOB field. This setting handles several controls which are offered in the sheet to the user.
 * @param isEditable If YES the underlying table field is editable, if NO the field is not editable and the SPFieldEditorController sheet do not show a "OK" button for saving.
 * @param theWindow The window for displaying the sheet.
 * @param sender The calling instance.
 * @param contextInfo context info for processing the edited data in sender.
 */
- (void)editWithObject:(id)data
			 fieldName:(NSString *)fieldName
		 usingEncoding:(NSStringEncoding)anEncoding
		  isObjectBlob:(BOOL)isFieldBlob
			isEditable:(BOOL)isEditable
			withWindow:(NSWindow *)theWindow
				sender:(id)sender
		   contextInfo:(NSDictionary *)theContextInfo
{
	usedSheet = nil;

	_isEditable = isEditable;
	contextInfo = [theContextInfo retain];
	callerInstance = sender;

	_isGeometry = ([[fieldType uppercaseString] isEqualToString:@"GEOMETRY"]) ? YES : NO;
	_isJSON     = ([[fieldType uppercaseString] isEqualToString:SPMySQLJsonType]);

	// Set field label
	NSMutableString *label = [NSMutableString string];

	[label appendFormat:@"“%@”", fieldName];

	if ([fieldType length] || maxTextLength > 0 || [fieldEncoding length] || !_allowNULL)
		[label appendString:@" – "];

	if ([fieldType length])
		[label appendString:fieldType];

	//skip length for JSON type since it's a constant and MySQL doesn't display it either
	if (maxTextLength > 0 && !_isJSON)
		[label appendFormat:@"(%lld) ", maxTextLength];

	if (!_allowNULL)
		[label appendString:@"NOT NULL "];

	if ([fieldEncoding length])
		[label appendString:fieldEncoding];

	CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	if ([fieldType length] && [[fieldType uppercaseString] isEqualToString:@"BIT"]) {

		sheetEditData = [(NSString*)data retain];

		[bitSheetNULLButton setEnabled:_allowNULL];

		// Check for NULL
		if ([sheetEditData isEqualToString:[prefs objectForKey:SPNullValue]]) {
			[bitSheetNULLButton setState:NSOnState];
			[self setToNull:bitSheetNULLButton];
		}
		else {
			[bitSheetNULLButton setState:NSOffState];
		}

		[bitSheetFieldName setStringValue:label];

		// Init according bit check boxes
		NSUInteger i = 0;
		NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

		if ([bitSheetNULLButton state] == NSOffState && maxBit <= [(NSString*)sheetEditData length])
			for (i = 0; i < maxBit; i++)
			{
				[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", (long)i]]
				 setState:([(NSString*)sheetEditData characterAtIndex:(maxBit - i - 1)] == '1') ? NSOnState : NSOffState];
			}

		for (i = maxBit; i < 64; i++)
		{
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", (long)i]] setEnabled:NO];
		}

		[self updateBitSheet];

		usedSheet = bitSheet;

		[NSApp beginSheet:usedSheet 
		   modalForWindow:theWindow 
			modalDelegate:self 
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
			  contextInfo:nil];
	} 
	else {
		usedSheet = editSheet;

		// If required, use monospaced fonts
#ifndef SP_CODA
		if (![prefs objectForKey:SPFieldEditorSheetFont]) {
#endif
			[editTextView setFont:
#ifndef SP_CODA
			[prefs boolForKey:SPUseMonospacedFonts] ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] :
#endif			
			[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
#ifndef SP_CODA
		}
		else {
			[editTextView setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"FieldEditorSheetFont"]]];
		}
#endif

		[editTextView setContinuousSpellCheckingEnabled:
#ifndef SP_CODA
		[prefs boolForKey:SPBlobTextEditorSpellCheckingEnabled]
#else
		NO
#endif
		];

		[hexTextView setFont:[NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize]];

		[editSheetFieldName setStringValue:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Field", @"Field"), label]];

		// Hide all views in editSheet
		[hexTextView setHidden:YES];
		[hexTextScrollView setHidden:YES];
		[editImage setHidden:YES];
		[editTextView setHidden:YES];
		[editTextScrollView setHidden:YES];

		if (!_isEditable) {
			[editSheetOkButton setHidden:YES];
			[editSheetCancelButton setHidden:YES];
			[editSheetIsNotEditableCancelButton setHidden:NO];
			[editSheetOpenButton setEnabled:NO];
		}

		editSheetWillBeInitialized = YES;

		encoding = anEncoding;

		// we don't want the hex/image controls for JSON
		_isBlob = (!_isJSON && isFieldBlob);
		
		BOOL isBinary = ([[fieldType uppercaseString] isEqualToString:@"BINARY"] || [[fieldType uppercaseString] isEqualToString:@"VARBINARY"]);

		sheetEditData = [data retain];

		// Hide all views in editSheet
		[hexTextView setHidden:YES];
		[hexTextScrollView setHidden:YES];
		[editImage setHidden:YES];
		[editTextView setHidden:YES];
		[editTextScrollView setHidden:YES];

		// Hide QuickLook button and text/image/hex control for text data
		[editSheetQuickLookButton setHidden:((!_isBlob && !isBinary) || _isGeometry)];
		[editSheetSegmentControl setHidden:(!_isBlob && !isBinary && !_isGeometry)];

		[editSheetSegmentControl setEnabled:YES forSegment:ImageSegment];

		// Set window's min size since no segment and quicklook buttons are hidden
		if (_isBlob || isBinary || _isGeometry) {
			[usedSheet setFrameAutosaveName:@"SPFieldEditorBlobSheet"];
			[usedSheet setMinSize:NSMakeSize(650, 200)];
		} 
		else {
			[usedSheet setFrameAutosaveName:@"SPFieldEditorTextSheet"];
			[usedSheet setMinSize:NSMakeSize(390, 150)];
		}

		[editTextView setEditable:_isEditable];
		[editImage setEditable:_isEditable];

		NSSize screen = [[NSScreen mainScreen] visibleFrame].size;
		NSRect sheet = [usedSheet frame];
		
		[usedSheet setFrame:
		 NSMakeRect(sheet.origin.x, sheet.origin.y, 
					(sheet.size.width > screen.width) ? screen.width : sheet.size.width, 
					(sheet.size.height > screen.height) ? screen.height - 100 : sheet.size.height)
					display:YES];
							
		[NSApp beginSheet:usedSheet 
		   modalForWindow:theWindow 
			modalDelegate:self 
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
			  contextInfo:nil];

		[editSheetProgressBar startAnimation:self];

		NSImage *image = nil;

		if ([sheetEditData isKindOfClass:[NSData class]]) {
			image = [[[NSImage alloc] initWithData:sheetEditData] autorelease];

			// Set hex view to "" - load on demand only
			[hexTextView setString:@""];

			stringValue = [[NSString alloc] initWithData:sheetEditData encoding:encoding];

			if (stringValue == nil) {
				stringValue = [[NSString alloc] initWithData:sheetEditData encoding:NSASCIIStringEncoding];
			}

			if (isBinary) {
				stringValue	= [[NSString alloc] initWithFormat:@"0x%@", [sheetEditData dataToHexString]];
			}

			[hexTextView setHidden:NO];
			[hexTextScrollView setHidden:NO];
			[editImage setHidden:YES];
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			[editSheetSegmentControl setSelectedSegment:HexSegment];
		}
		else if ([sheetEditData isKindOfClass:[SPMySQLGeometryData class]]) {
			SPGeometryDataView *v = [[[SPGeometryDataView alloc] initWithCoordinates:[sheetEditData coordinates] targetDimension:2000.0f] autorelease];

			image = [v thumbnailImage];

			stringValue = [[sheetEditData wktString] retain];

			[hexTextView setString:@""];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editSheetSegmentControl setEnabled:NO forSegment:HexSegment];
			[editSheetSegmentControl setSelectedSegment:TextSegment];
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
		}
		else {
			// If the input is a JSON type column we can format it.
			// Since MySQL internally stores JSON in binary, it does not retain any formatting
			do {
				if(_isJSON) {
					NSString *formatted = [SPJSONFormatter stringByFormattingString:sheetEditData];
					if(formatted) {
						stringValue = [formatted retain];
						break;
					}
				}
				stringValue = [sheetEditData retain];
			} while(0);

			[hexTextView setString:@""];

			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:YES];
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
			[editSheetSegmentControl setSelectedSegment:TextSegment];
		}

		if (image) {
			[editImage setImage:image];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			if(!_isGeometry) {
				[editTextView setHidden:YES];
				[editTextScrollView setHidden:YES];
				[editSheetSegmentControl setSelectedSegment:ImageSegment];
			}
		}
		else {
			[editImage setImage:nil];
		}

		if (stringValue) {
			[editTextView setString:stringValue];

			if (image == nil) {
				if (!isBinary) {
					[hexTextView setHidden:YES];
					[hexTextScrollView setHidden:YES];
				}
				else {
					[editSheetSegmentControl setEnabled:NO forSegment:ImageSegment];
				}

				[editImage setHidden:YES];
				[editTextView setHidden:NO];
				[editTextScrollView setHidden:NO];
				[editSheetSegmentControl setSelectedSegment:TextSegment];
			}

			// Locate the caret in editTextView
			// (restore a given selection coming from the in-cell editing mode)
			NSRange selRange = [callerInstance fieldEditorSelectedRange];

			[editTextView setSelectedRange:selRange];
			[callerInstance setFieldEditorSelectedRange:NSMakeRange(0,0)];

			// If the string content is NULL select NULL for convenience
			if ([stringValue isEqualToString:[prefs objectForKey:SPNullValue]]) {
				[editTextView setSelectedRange:NSMakeRange(0,[[editTextView string] length])];
			}

			// Set focus
			[usedSheet makeFirstResponder:image == nil || _isGeometry ? editTextView : editImage];
		}
		
		if (stringValue) SPClear(stringValue);

		editSheetWillBeInitialized = NO;

		[editSheetProgressBar stopAnimation:self];
	}
}

/**
 * Segement controller for text/image/hex buttons in editSheet
 */
- (IBAction)segmentControllerChanged:(id)sender
{
	switch((FieldEditorSegment)[sender selectedSegment]){
		case TextSegment:
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
			[editImage setHidden:YES];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[usedSheet makeFirstResponder:editTextView];
			break;
		case ImageSegment:
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[usedSheet makeFirstResponder:editImage];
			break;
		case HexSegment:
			[usedSheet makeFirstResponder:hexTextView];
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

/**
 * Open the open file panel to load a file (text/image) into the editSheet
 */
- (IBAction)openEditSheet:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self openPanelDidEnd:panel returnCode:returnCode contextInfo:nil];
	}];
}

/**
 * Open the save file panel to save the content of the editSheet according to its type as NSData or NSString atomically into the past file.
 */
- (IBAction)saveEditSheet:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	if ([editSheetSegmentControl selectedSegment] == ImageSegment && [sheetEditData isKindOfClass:[SPMySQLGeometryData class]]) {
		[panel setAllowedFileTypes:@[@"pdf"]];
		[panel setAllowsOtherFileTypes:NO];
	}
	else {
		[panel setAllowsOtherFileTypes:YES];
	}

	[panel setCanSelectHiddenExtension:YES];
	[panel setExtensionHidden:NO];

	[panel beginSheetModalForWindow:usedSheet completionHandler:^(NSInteger returnCode)
	{
		[self savePanelDidEnd:panel returnCode:returnCode contextInfo:nil];
	}];
}

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_CODA
	// Remember spell cheecker status
	[prefs setBool:[editTextView isContinuousSpellCheckingEnabled] forKey:SPBlobTextEditorSpellCheckingEnabled];
#endif
}

/**
 * Close the editSheet. Before closing it validates the editSheet data against maximum text size.
 * If data size is too long select the part which is to long for better editing and keep the sheet opened.
 * If any temporary Quicklook files were created delete them before clsoing the sheet.
 */
- (IBAction)closeEditSheet:(id)sender
{
	editSheetReturnCode = 0;

	// Validate the sheet data before saving them.
	// - for max text length (except for NULL value string) select the part which won't be saved
	//   and suppress closing the sheet
	if (sender == editSheetOkButton) {
		
		unsigned long long maxLength = maxTextLength;
		
		// For FLOAT fields ignore the decimal point in the text when comparing lengths
		if ([[fieldType uppercaseString] isEqualToString:@"FLOAT"] && ([[[editTextView textStorage] string] rangeOfString:@"."].location != NSNotFound)) {
			maxLength++;
		}
		
		if (maxLength > 0 && [[editTextView textStorage] length] > maxLength && ![[[editTextView textStorage] string] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			[editTextView setSelectedRange:NSMakeRange((NSUInteger)maxLength, [[editTextView textStorage] length] - (NSUInteger)maxLength)];
			[editTextView scrollRangeToVisible:NSMakeRange([editTextView selectedRange].location,0)];
			[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Text is too long. Maximum text length is set to %llu.", @"Text is too long. Maximum text length is set to %llu."), maxTextLength]];
			
			return;
		}

		editSheetReturnCode = 1;
	}
	else if (sender == bitSheetOkButton && _isEditable) {
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

	[NSApp endSheet:usedSheet returnCode:1];
	[usedSheet orderOut:self];

	if(callerInstance) {
		id returnData = ( editSheetReturnCode && _isEditable ) ? (_isGeometry) ? [editTextView string] : sheetEditData : nil;
		
		//for MySQLs JSON type remove the formatting again, since it won't be stored anyway
		if(_isJSON) {
			NSString *unformatted = [SPJSONFormatter stringByUnformattingString:returnData];
			if(unformatted) returnData = unformatted;
		}
		
#ifdef SP_CODA /* patch */
		if ( [callerInstance isKindOfClass:[SPCustomQuery class]] )
			[(SPCustomQuery*)callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
		else if ( [callerInstance isKindOfClass:[SPTableContent class]] )
			[(SPTableContent*)callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
#else
		if([callerInstance respondsToSelector:@selector(processFieldEditorResult:contextInfo:)]) {
			[(id <SPFieldEditorControllerDelegate>)callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
		}
#endif
	}
}

/**
 * Open file panel didEndSelector. If the returnCode == NSOKButton it opens the selected file in the editSheet.
 */
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSString *contents = nil;

		editSheetWillBeInitialized = YES;

		[editSheetProgressBar startAnimation:self];

		// free old data
		if ( sheetEditData != nil ) {
			[sheetEditData release];
		}

		// load new data/images
		sheetEditData = [[NSData alloc] initWithContentsOfURL:[panel URL]];

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
			[editSheetSegmentControl setSelectedSegment:ImageSegment];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];

			// Otherwise deselect the image view
		} else {
			[editSheetSegmentControl setSelectedSegment:TextSegment];
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

/**
 * Save file panel didEndSelector. If the returnCode == NSOKButton it writes the current content of editSheet according to its type as NSData or NSString atomically into the past file.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {

		[editSheetProgressBar startAnimation:self];

		NSURL *fileURL = [panel URL];

		// Write binary field types directly to the file
		if ( [sheetEditData isKindOfClass:[NSData class]] ) {
			[sheetEditData writeToURL:fileURL atomically:YES];

		}
		else if ( [sheetEditData isKindOfClass:[SPMySQLGeometryData class]] ) {

			if ( [editSheetSegmentControl selectedSegment] == TextSegment || editImage == nil ) {

				[[editTextView string] writeToURL:fileURL
										atomically:YES
										  encoding:encoding
											 error:NULL];

			} else if (editImage != nil){

				SPGeometryDataView *v = [[[SPGeometryDataView alloc] initWithCoordinates:[sheetEditData coordinates] targetDimension:2000.0f] autorelease];
				NSData *pdf = [v pdfData];
				if(pdf)
					[pdf writeToURL:fileURL atomically:YES];

			}
		}
		// Write other field types' representations to the file via the current encoding
		else {
			[[sheetEditData description] writeToURL:fileURL
										  atomically:YES
											encoding:encoding
											   error:NULL];
		}

		[editSheetProgressBar stopAnimation:self];
	}
}

#pragma mark -
#pragma mark Drop methods

/**
 * If the image was deleted reset all views in editSheet.
 * The actual dropped image process is handled by (processUpdatedImageData:).
 */
- (IBAction)dropImage:(id)sender
{
	if ( [editImage image] == nil ) {
		if (nil != sheetEditData) [sheetEditData release];
		sheetEditData = [[NSData alloc] init];
		[editTextView setString:@""];
		[hexTextView setString:@""];
		return;
	}
}

#pragma mark -
#pragma mark QuickLook

/**
 * Invoked if a Quicklook format was chosen
 */
- (IBAction)quickLookFormatButton:(id)sender
{
#ifndef SP_CODA
	if(qlTypes != nil && [[qlTypes objectForKey:@"QuickLookTypes"] count] > (NSUInteger)[sender tag] - 2) {
		NSDictionary *type = [[qlTypes objectForKey:@"QuickLookTypes"] objectAtIndex:[sender tag] - 2];
		[self invokeQuickLookOfType:[type objectForKey:@"Extension"] treatAsText:([[type objectForKey:@"treatAsText"] integerValue])];
	}
#endif
}

/**
 * Create a temporary file in NSTemporaryDirectory() with the chosen extension type which will be called by Apple's Quicklook generator
 *
 * @param type The type as file extension for Apple's default Quicklook generator.
 *
 * @param isText If YES the content of editSheet will be treates as pure text.
 */
- (void)createTemporaryQuickLookFileOfType:(NSString *)type treatAsText:(BOOL)isText
{
	// Create a temporary file name to store the data as file
	// since QuickLook only works on files.
	// Alternate the file name to suppress caching by using counter%2.
	if (tmpFileName) [tmpFileName release];
	tmpFileName = [[NSString alloc] initWithFormat:@"%@SequelProQuickLook%ld.%@", tmpDirPath, (long)(counter%2), type];

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

/**
 * Opens QuickLook for current data if QuickLook is available
 *
 * @param type The type as file extension for Apple's default Quicklook generator.
 *
 * @param isText If YES the content of editSheet will be treates as pure text.
 */
- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText
{
#ifndef SP_CODA
	// See Developer example "QuickLookDownloader"
	// file:///Developer/Documentation/DocSets/com.apple.adc.documentation.AppleSnowLeopard.CoreReference.docset/Contents/Resources/Documents/samplecode/QuickLookDownloader/index.html#//apple_ref/doc/uid/DTS40009082

	[editSheetProgressBar startAnimation:self];

	[self createTemporaryQuickLookFileOfType:type treatAsText:isText];

	counter++;

	// TODO: If QL is  visible reload it - but how?
	// Up to now QL will close and the user has to redo it.
	if([[QLPreviewPanel sharedPreviewPanel] isVisible]) {
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	}

	[[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];

	[editSheetProgressBar stopAnimation:self];

#endif
}

#pragma mark - QLPreviewPanelController methods

/**
 * QuickLook delegate for SDK 10.6. Set the Quicklook delegate to self and suppress setShowsAddToiPhotoButton since the format is unknow.
 */
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
#ifndef SP_CODA

	// This document is now responsible of the preview panel
	[panel setDelegate:self];
	[panel setDataSource:self];

#endif
}

/**
 * QuickLook delegate for SDK 10.6 - not in usage.
 */
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
	// This document loses its responsisibility on the preview panel
	// Until the next call to -beginPreviewPanelControl: it must not
	// change the panel's delegate, data source or refresh it.
}

/**
 * QuickLook delegate for SDK 10.6
 */
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
	return YES;
}

#pragma mark - QLPreviewPanelDataSource methods

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It always returns 1.
 */
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
	return 1;
}

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It returns as NSURL the temporarily created file.
 */
- (id)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)anIndex
{
	if(tmpFileName)
		return [NSURL fileURLWithPath:tmpFileName];

	return nil;
}

#pragma mark - QLPreviewPanelDelegate methods

// QuickLook delegates for SDK 10.6
// - (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
// {
// }

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It returns the frame of the application's middle. If an empty frame is returned then the panel will fade in/out instead.
 */
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id)item
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

#pragma mark -

/**
 * Called by (SPImageView) if an image was pasted into the editSheet
 */
-(void)processPasteImageData
{

	editSheetWillBeInitialized = YES;

	NSImage *image = nil;

	image = [[[NSImage alloc] initWithPasteboard:[NSPasteboard generalPasteboard]] autorelease];
	if (image) {

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

/**
 * Invoked if the imageView was changed or a file dragged and dropped onto it.
 *
 * @param data The image data. If data == nil the reset all views in editSheet.
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

#pragma mark -
#pragma mark BIT Field Sheet

/**
 * Update all controls in the bitSheet
 */
- (void)updateBitSheet
{
	NSUInteger i = 0;
	NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

	if([bitSheetNULLButton state] == NSOnState) {
		if ( sheetEditData != nil ) {
			[sheetEditData release];
		}

		NSString *nullString = [prefs objectForKey:SPNullValue];
		sheetEditData = [[NSString stringWithString:nullString] retain];
		[bitSheetIntegerTextField setStringValue:nullString];
		[bitSheetHexTextField setStringValue:nullString];
		[bitSheetOctalTextField setStringValue:nullString];
		return;
	}

	NSMutableString *bitString = [NSMutableString string];
	[bitString setString:@""];
	for( i = 0; i<maxBit; i++ )
		[bitString appendString:@"0"];

	NSUInteger intValue = 0;
	NSUInteger bitValue = 0x1;

	for(i=0; i<maxBit; i++) {
		if([(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", (unsigned long)i]] state] == NSOnState) {
			intValue += bitValue;
			[bitString replaceCharactersInRange:NSMakeRange((NSUInteger)maxTextLength-i-1, 1) withString:@"1"];
		}
		bitValue <<= 1;
	}
	[bitSheetIntegerTextField setStringValue:[[NSNumber numberWithUnsignedLongLong:intValue] stringValue]];
	[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%lX", (unsigned long)intValue]];
	[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%llo", (unsigned long long)intValue]];
	// free old data
	if ( sheetEditData != nil ) {
		[sheetEditData release];
	}

	// set edit data to text
	sheetEditData = [[NSString stringWithString:bitString] retain];

}

/**
 * Selector of any operator in the bitSheet. The different buttons will be distinguished by the sender's tag.
 */
- (IBAction)bitSheetOperatorButtonWasClicked:(id)sender
{
	unsigned long i = 0;
	unsigned long aBit;
	unsigned long maxBit = (unsigned long)((maxTextLength > 64) ? 64 : maxTextLength);

	switch([sender tag]) {
		case 0: // all to 1
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:NSOnState];
		break;
		case 1: // all to 0
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:NSOffState];
		break;
		case 2: // negate
		for(i=0; i<maxBit; i++)
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:![(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] state]];
		break;
		case 3: // shift left
		for(i=maxBit-1; i>0; i--) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i-1]] state]];
		}
		[[self valueForKeyPath:@"bitSheetBitButton0"] setState:NSOffState];
		break;
		case 4: // shift right
		for(i=0; i<maxBit-1; i++) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i+1]] state]];
		}
		[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", maxBit-1]] setState:NSOffState];
		break;
		case 5: // rotate left
		aBit = [(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", maxBit-1]] state];
		for(i=maxBit-1; i>0; i--) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i-1]] state]];
		}
		[[self valueForKeyPath:@"bitSheetBitButton0"] setState:aBit];
		break;
		case 6: // rotate right
		aBit = [(NSButton*)[self valueForKeyPath:@"bitSheetBitButton0"] state];
		for(i=0; i<maxBit-1; i++) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i+1]] state]];
		}
		[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", maxBit-1]] setState:aBit];
		break;
	}
	[self updateBitSheet];
}

/**
 * Selector to set the focus to the first bit - but it doesn't work (⌘B).
 */
- (IBAction)bitSheetSelectBit0:(id)sender
{
	[usedSheet makeFirstResponder:[self valueForKeyPath:@"bitSheetBitButton0"]];
}

/**
 * Selector to set the to be edited data to NULL or not according to [sender state].
 * If NULL processes several validations.
 */
- (IBAction)setToNull:(id)sender
{
	unsigned long i;
	unsigned long maxBit = (unsigned long)((maxTextLength > 64) ? 64 : maxTextLength);

	if([(NSButton*)sender state] == NSOnState) {
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setEnabled:NO];
		[bitSheetHexTextField setEnabled:NO];
		[bitSheetIntegerTextField setEnabled:NO];
		[bitSheetOctalTextField setEnabled:NO];
	} else {
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setEnabled:YES];
		[bitSheetHexTextField setEnabled:YES];
		[bitSheetIntegerTextField setEnabled:YES];
		[bitSheetOctalTextField setEnabled:YES];
	}

	[self updateBitSheet];
}

/**
 * Selector if any bit NSButton was pressed to update any controls in bitSheet.
 */
- (IBAction)bitSheetBitButtonWasClicked:(id)sender
{
	[self updateBitSheet];
}

#pragma mark -
#pragma mark TextView delegate methods

/**
 * Performs interface validation for various controls. Esp. if user changed the value in bitSheetIntegerTextField or bitSheetHexTextField.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];

	if (object == bitSheetIntegerTextField) {

		unsigned long i = 0;
		unsigned long maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

		NSUInteger intValue = (NSUInteger)strtoull([[bitSheetIntegerTextField stringValue] UTF8String], NULL, 0);

		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:NSOffState];

		[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%lX", (unsigned long)intValue]];
		[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%llo", (long long)intValue]];

		i = 0;
		while( intValue && i < maxBit )
		{
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%lu", i]] setState:( (intValue & 0x1) == 0) ? NSOffState : NSOnState];
			intValue >>= 1;
			i++;
		}
		[self updateBitSheet];
	}
	else if (object == bitSheetHexTextField) {

		NSUInteger i = 0;
		NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

		unsigned long long intValue;

		[[NSScanner scannerWithString:[bitSheetHexTextField stringValue]] scanHexLongLong: &intValue];

		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", (long)i]] setState:NSOffState];

		[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%qX", intValue]];
		[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%llo", intValue]];

		i = 0;
		while( intValue && i < maxBit )
		{
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", (long)i]] setState:( (intValue & 0x1) == 0) ? NSOffState : NSOnState];
			intValue >>= 1;
			i++;
		}
		
		[self updateBitSheet];
	}
}

/**
 * Validate editTextView for maximum text length except for NULL as value string
 */
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)r replacementString:(NSString *)replacementString
{
	if (textView == editTextView && 
		(maxTextLength > 0) && 
		![[[[editTextView textStorage] string] stringByAppendingString:replacementString] isEqualToString:[prefs objectForKey:SPNullValue]]) 
	{
		NSInteger newLength;

		// Auxilary to ensure that eg textViewDidChangeSelection:
		// saves a non-space char + base char if that combination
		// occurs at the end of a sequence of typing before saving
		// (OK button).
		editTextViewWasChanged = ([replacementString length] == 1);

		// Pure attribute changes are ok
		if (!replacementString) return YES;

		// The exact change isn't known. Disallow the change to be safe.
		if (r.location == NSNotFound) return NO;

		// Length checking while using the Input Manager (eg for Japanese)
		if ([textView hasMarkedText] && (maxTextLength > 0) && (r.location < maxTextLength)) {

			// User tries to insert a new char but max text length was already reached - return NO
			if (!r.length && ([[textView textStorage] length] >= maxTextLength)) {
				[SPTooltip showWithObject:[NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu.", @"Maximum text length is set to %llu."), maxTextLength]];
				[textView unmarkText];
				
				return NO;
			}
			// Otherwise allow it if insertion point is valid for eg
			// a VARCHAR(3) field filled with two Chinese chars and one inserts the
			// third char by typing its pronounciation "wo" - 2 Chinese chars plus "wo" would give
			// 4 which is larger than max length.
			// TODO this doesn't solve the problem of inserting more than one char. For now
			// that part which won't be saved will be hilited if user pressed the OK button.
			else if (r.location < maxTextLength) {
				return YES;
			}
		}

		// Calculate the length of the text after the change.
		newLength = [[[textView textStorage] string] length] + [replacementString length] - r.length;

		NSUInteger textLength = [[[textView textStorage] string] length];
		
		unsigned long long originalMaxTextLength = maxTextLength;
		
		// For FLOAT fields ignore the decimal point in the text when comparing lengths
		if ([[fieldType uppercaseString] isEqualToString:@"FLOAT"] && 
			([[[textView textStorage] string] rangeOfString:@"."].location != NSNotFound)) {
			
			if ((NSUInteger)newLength == (maxTextLength + 1)) {
				maxTextLength++;
				textLength--;
			}
			else if ((NSUInteger)newLength > maxTextLength) {
				textLength--;
			}
		}

		// If it's too long, disallow the change but try
		// to insert a text chunk partially to maxTextLength.
		if ((NSUInteger)newLength > maxTextLength) {
			if ((maxTextLength - textLength + [textView selectedRange].length) <= [replacementString length]) {	
			
				NSString *tooltip = nil;
				
				if (maxTextLength - textLength + [textView selectedRange].length) {
					tooltip = [NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu. Inserted text was truncated.", @"Maximum text length is set to %llu. Inserted text was truncated."), maxTextLength];
				}
				else {
					tooltip = [NSString stringWithFormat:NSLocalizedString(@"Maximum text length is set to %llu.", @"Maximum text length is set to %llu."), maxTextLength];
				}
				
				[SPTooltip showWithObject:tooltip];
												
				[textView insertText:[replacementString substringToIndex:(NSUInteger)maxTextLength - textLength +[textView selectedRange].length]];
			}
			
			maxTextLength = originalMaxTextLength;
			
			return NO;
		}

		maxTextLength = originalMaxTextLength;

		// Otherwise, allow it
		return YES;
	}
	
	return YES;
}

/**
 * Invoked when the user changes the string in the editSheet
 */
- (void)textViewDidChangeSelection:(NSNotification *)notification
{
	if([notification object] == editTextView) {
		// Do nothing if user really didn't changed text (e.g. for font size changing return)
		if(!editTextViewWasChanged && (editSheetWillBeInitialized
			|| (([[[notification object] textStorage] editedRange].location == NSNotFound)
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
}

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

/**
 * Traps any editing in editTextView to allow undo grouping only if the text buffer was really changed.
 * Inform the run loop delayed for larger undo groups.
 */
- (void)textDidChange:(NSNotification *)aNotification
{

	[NSObject cancelPreviousPerformRequestsWithTarget:self
								selector:@selector(setAllowedUndo)
								object:nil];

	// If conditions match create an undo group
	NSInteger cycleCounter;
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

	[self performSelector:@selector(setAllowedUndo) withObject:nil afterDelay:0.09];

}

#pragma mark -
#pragma mark UndoManager methods

/**
 * Establish and return an UndoManager for editTextView
 */
- (NSUndoManager*)undoManagerForTextView:(NSTextView*)aTextView
{
	if (!esUndoManager)
		esUndoManager = [[NSUndoManager alloc] init];

	return esUndoManager;
}

/**
 * Set variable if something in editTextView was cutted or pasted for creating better undo grouping.
 */
- (void)setWasCutPaste
{
	wasCutPaste = YES;
}

/**
 * Will be invoke delayed for creating better undo grouping according to type speed (see [self textDidChange:]).
 */
- (void)setAllowedUndo
{
	allowUndo = YES;
}

/**
 * Will be set if according to characters typed in editTextView for creating better undo grouping.
 */
- (void)setDoGroupDueToChars
{
	doGroupDueToChars = YES;
}

@end
