//
//  $Id$
//
//  SPFieldEditorController.m
//  sequel-pro
//
//  Created by Hans-J√∂rg Bibiko on July 16, 2009
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
#ifndef SP_REFACTOR
#import "QLPreviewPanel.h"
#endif
#import "SPDataCellFormatter.h"
#import "RegexKitLite.h"
#import "SPDataCellFormatter.h"
#import "SPTooltip.h"
#import "SPGeometryDataView.h"
#import "SPCopyTable.h"
#include <objc/objc-runtime.h>
#import "SPCustomQuery.h"
#import "SPTableContent.h"
#import <SPMySQL/SPMySQL.h>

@interface SPFieldEditorController (SPFieldEditorControllerDelegate)

- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;

@end

#ifdef SP_REFACTOR
/* Suppress deprecation warning for beginSheetForDirectory: until Sequel Pro team can migrate */
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

@implementation SPFieldEditorController

@synthesize editedFieldInfo;

/**
 * Initialise an instance of SPFieldEditorController using the XIB “FieldEditorSheet.xib”. Init the available Quciklook format by reading
 * EditorQuickLookTypes.plist and if given user-defined format store in the Preferences for key (SPQuickLookTypes).
 */
- (id)init
{
#ifndef SP_REFACTOR
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
		[editSheetOkButton setKeyEquivalentModifierMask:NSCommandKeyMask];

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
#ifndef SP_REFACTOR
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

		qlTypes = [[NSDictionary dictionaryWithObject:qlTypesItems forKey:SPQuickLookTypes] retain];
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

#ifndef SP_REFACTOR
	// On Mac OSX 10.6 QuickLook runs non-modal thus order out the panel
	// if still visible
	if([[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] isVisible])
		[[NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel] orderOut:nil];
#endif

	if ( sheetEditData ) [sheetEditData release];
#ifndef SP_REFACTOR
	if ( qlTypes ) [qlTypes release];
#endif
	if ( tmpFileName ) [tmpFileName release];
	if ( tmpDirPath ) [tmpDirPath release];
	if ( esUndoManager ) [esUndoManager release];
	if ( contextInfo ) [contextInfo release];
	[super dealloc];
}

#pragma mark -

/**
 * Main method for editing data. It will validate several settings and display a modal sheet for theWindow whioch waits until the user closes the sheet.
 *
 * @param data The to be edited table field data.
 *
 * @param fieldName The name of the currently edited table field.
 *
 * @param anEncoding The used encoding while editing.
 *
 * @param isFieldBlob If YES the underlying table field is a TEXT/BLOB field. This setting handles several controls which are offered in the sheet to the user.
 *
 * @param isEditable If YES the underlying table field is editable, if NO the field is not editable and the SPFieldEditorController sheet do not show a "OK" button for saving.
 *
 * @param theWindow The window for displaying the sheet.
 *
 * @param sender The calling instance.
 *
 * @param contextInfo context info for processing the edited data in sender.
 *
 */
- (void)editWithObject:(id)data fieldName:(NSString*)fieldName usingEncoding:(NSStringEncoding)anEncoding
		isObjectBlob:(BOOL)isFieldBlob isEditable:(BOOL)isEditable withWindow:(NSWindow *)theWindow
		sender:(id)sender contextInfo:(NSDictionary*)theContextInfo
{

	usedSheet = nil;

	_isEditable = isEditable;
	contextInfo = [theContextInfo retain];
	callerInstance = sender;

	_isGeometry = ([[fieldType uppercaseString] isEqualToString:@"GEOMETRY"]) ? YES : NO;

	// Set field label
	NSMutableString *label = [NSMutableString string];
	[label appendFormat:@"“%@”", fieldName];
	if([fieldType length] || maxTextLength > 0 || [fieldEncoding length] || !_allowNULL)
		[label appendString:@" – "];
	if([fieldType length])
		[label appendString:fieldType];
	if(maxTextLength > 0)
		[label appendFormat:@"(%ld) ", maxTextLength];
	if(!_allowNULL)
		[label appendString:@"NOT NULL "];
	if([fieldEncoding length])
		[label appendString:fieldEncoding];

	if([fieldType length] && [[fieldType uppercaseString] isEqualToString:@"BIT"]) {

		sheetEditData = [(NSString*)data retain];

		[bitSheetNULLButton setEnabled:_allowNULL];

		// Check for NULL
		if([sheetEditData isEqualToString:[prefs objectForKey:SPNullValue]]) {
			[bitSheetNULLButton setState:NSOnState];
			[self setToNull:bitSheetNULLButton];
		} else {
			[bitSheetNULLButton setState:NSOffState];
		}

		[bitSheetFieldName setStringValue:label];

		// Init according bit check boxes
		NSUInteger i = 0;
		NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);
		if([bitSheetNULLButton state] == NSOffState && maxBit <= [(NSString*)sheetEditData length])
			for( i = 0; i<maxBit; i++ )
				[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]]
					setState:([(NSString*)sheetEditData characterAtIndex:(maxBit-i-1)] == '1') ? NSOnState : NSOffState];
		for( i = maxBit; i<64; i++ )
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setEnabled:NO];

		[self updateBitSheet];

		usedSheet = bitSheet;

		[NSApp beginSheet:usedSheet modalForWindow:theWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];

	} else {

		usedSheet = editSheet;

		// If required, use monospaced fonts
#ifndef SP_REFACTOR
		if (![prefs objectForKey:SPFieldEditorSheetFont]) {
#endif
			[editTextView setFont:
#ifndef SP_REFACTOR
			([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : 
#endif			
			[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
#ifndef SP_REFACTOR
		}
		else {
			[editTextView setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"FieldEditorSheetFont"]]];
		}
#endif

		[editTextView setContinuousSpellCheckingEnabled:
#ifndef SP_REFACTOR
		[prefs boolForKey:SPBlobTextEditorSpellCheckingEnabled]
#else
		NO
#endif
		];

		[hexTextView setFont:[NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]]];

		[editSheetFieldName setStringValue:[NSString stringWithFormat:@"%@: %@%", NSLocalizedString(@"Field", @"Field"), label]];

		// hide all views in editSheet
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

		_isBlob = isFieldBlob;
		BOOL _isBINARY = ([[fieldType uppercaseString] isEqualToString:@"BINARY"] || [[fieldType uppercaseString] isEqualToString:@"VARBINARY"]);

		sheetEditData = [data retain];

		// hide all views in editSheet
		[hexTextView setHidden:YES];
		[hexTextScrollView setHidden:YES];
		[editImage setHidden:YES];
		[editTextView setHidden:YES];
		[editTextScrollView setHidden:YES];

		// Hide QuickLook button and text/image/hex control for text data
		[editSheetQuickLookButton setHidden:((!_isBlob && !_isBINARY) || _isGeometry)];
		[editSheetSegmentControl setHidden:(!_isBlob && !_isBINARY && !_isGeometry)];

		[editSheetSegmentControl setEnabled:YES forSegment:1];

		// Set window's min size since no segment and quicklook buttons are hidden
		if (_isBlob || _isBINARY || _isGeometry) {
			[usedSheet setFrameAutosaveName:@"SPFieldEditorBlobSheet"];
			[usedSheet setMinSize:NSMakeSize(650, 200)];
		} else {
			[usedSheet setFrameAutosaveName:@"SPFieldEditorTextSheet"];
			[usedSheet setMinSize:NSMakeSize(390, 150)];
		}

		[editTextView setEditable:_isEditable];
		[editImage setEditable:_isEditable];

		[NSApp beginSheet:usedSheet modalForWindow:theWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];

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
		} else if ([sheetEditData isKindOfClass:[SPMySQLGeometryData class]]) {
			SPGeometryDataView *v = [[[SPGeometryDataView alloc] initWithCoordinates:[sheetEditData coordinates] targetDimension:2000.0f] autorelease];
			image = [v thumbnailImage];
			stringValue = [[sheetEditData wktString] retain];
			[hexTextView setString:@""];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[editSheetSegmentControl setEnabled:NO forSegment:2];
			[editSheetSegmentControl setSelectedSegment:0];
			[editTextView setHidden:NO];
			[editTextScrollView setHidden:NO];
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
			if(!_isGeometry) {
				[editTextView setHidden:YES];
				[editTextScrollView setHidden:YES];
				[editSheetSegmentControl setSelectedSegment:1];
			}
		} else {
			[editImage setImage:nil];
		}
		if (stringValue) {
			[editTextView setString:stringValue];

			if(image == nil) {
				if(!_isBINARY) {
					[hexTextView setHidden:YES];
					[hexTextScrollView setHidden:YES];
				} else {
					[editSheetSegmentControl setEnabled:NO forSegment:1];
				}
				[editImage setHidden:YES];
				[editTextView setHidden:NO];
				[editTextScrollView setHidden:NO];
				[editSheetSegmentControl setSelectedSegment:0];
			}

			// Locate the caret in editTextView
			// (restore a given selection coming from the in-cell editing mode)
			NSRange selRange = [callerInstance fieldEditorSelectedRange];
			[editTextView setSelectedRange:selRange];
			[callerInstance setFieldEditorSelectedRange:NSMakeRange(0,0)];

			// If the string content is NULL select NULL for convenience
			if([stringValue isEqualToString:[prefs objectForKey:SPNullValue]])
				[editTextView setSelectedRange:NSMakeRange(0,[[editTextView string] length])];

			// Set focus
			if(image == nil || _isGeometry)
				[usedSheet makeFirstResponder:editTextView];
			else
				[usedSheet makeFirstResponder:editImage];

		}
		if(stringValue) [stringValue release], stringValue = nil;

		editSheetWillBeInitialized = NO;

		[editSheetProgressBar stopAnimation:self];

		// The field editor sheet runs as sheet thus a NSTextView won't respond to the Find Panel
		// since the Find Panel validate its buttons against [[NSApp mainWindow] firstResponder] == NSTextView.
		// After ordering out this sheet SPCopyTable remains the first responder thus set it hard.
		// This only works in conjunction with [NSTextView becomeFirstResponder] and [NSTextView resignFirstResponder]
		// which has to return YES.
#ifndef SP_REFACTOR
		if([[self window] firstResponder] == editTextView)
			[[NSApp mainWindow] makeFirstResponder:[[self window] firstResponder]];
#endif

	}

}

/**
 * Set the maximum text length of the underlying table field for input validation.
 *
 * @param length The maximum text length
 */
- (void)setTextMaxLength:(NSUInteger)length
{
	maxTextLength = length;
}

/**
 * Set the field type of the underlying table field for input validation.
 *
 * @param aType The field type which will be used for dispatching which sheet will be shown. If type == BIT the bitSheet will be used otherwise the editSheet.
 */
- (void)setFieldType:(NSString*)aType
{
	fieldType = aType;
}

/**
 * Set the field encoding of the underlying table field for displaying it to the user.
 *
 * @param aEncoding encoding
 */
- (void)setFieldEncoding:(NSString*)aEncoding
{
	fieldEncoding = aEncoding;
}

/**
 * Set if underlying table field allows NULL for several validations.
 *
 * @param allowNULL If allowNULL is YES NULL value is allowed for the underlying table field
 */
- (void)setAllowNULL:(BOOL)allowNULL
{
	_allowNULL = allowNULL;
}

/**
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
			[usedSheet makeFirstResponder:editTextView];
#ifndef SP_REFACTOR
			[[NSApp mainWindow] makeFirstResponder:editTextView];
#endif
			break;
		case 1: // image
			[editTextView setHidden:YES];
			[editTextScrollView setHidden:YES];
			[editImage setHidden:NO];
			[hexTextView setHidden:YES];
			[hexTextScrollView setHidden:YES];
			[usedSheet makeFirstResponder:editImage];
			break;
		case 2: // hex - load on demand
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
	[[NSOpenPanel openPanel] beginSheetForDirectory:nil
											   file:@""
									 modalForWindow:usedSheet
									  modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
										contextInfo:NULL];
}

/**
 * Open the save file panel to save the content of the editSheet according to its type as NSData or NSString atomically into the past file.
 */
- (IBAction)saveEditSheet:(id)sender
{

	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *fileDefault = @"";

	if([editSheetSegmentControl selectedSegment] == 1 && [sheetEditData isKindOfClass:[SPMySQLGeometryData class]]) {
		[panel setAllowedFileTypes:[NSArray arrayWithObject:@"pdf"]];
		[panel setAllowsOtherFileTypes:NO];
	} else {
		[panel setAllowsOtherFileTypes:YES];
	}
	[panel setCanSelectHiddenExtension:YES];
	[panel setExtensionHidden:NO];

	[panel beginSheetForDirectory:nil
							   file:fileDefault
					 modalForWindow:usedSheet
					  modalDelegate:self
					 didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
}

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_REFACTOR
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
		
#ifdef SP_REFACTOR /* patch */
		if ( [callerInstance isKindOfClass:[SPCustomQuery class]] )
			[(SPCustomQuery*)callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
		else if ( [callerInstance isKindOfClass:[SPTableContent class]] )
			[(SPTableContent*)callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
#else
		[callerInstance processFieldEditorResult:returnData contextInfo:contextInfo];
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

			if ( [editSheetSegmentControl selectedSegment] == 0 || editImage == nil ) {

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
#ifndef SP_REFACTOR
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
 *
 */
- (void)createTemporaryQuickLookFileOfType:(NSString *)type treatAsText:(BOOL)isText
{

	// Create a temporary file name to store the data as file
	// since QuickLook only works on files.
	// Alternate the file name to suppress caching by using counter%2.
	if (tmpFileName) [tmpFileName release];
	tmpFileName = [[NSString alloc] initWithFormat:@"%@SequelProQuickLook%d.%@", tmpDirPath, counter%2, type];

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
 *
 */
- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText
{
#ifndef SP_REFACTOR
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
#endif
}

/**
 * QuickLook delegate for SDK 10.6. Set the Quicklook delegate to self and suppress setShowsAddToiPhotoButton since the format is unknow.
 */
- (void)beginPreviewPanelControl:(id)panel
{
#ifndef SP_REFACTOR

	// This document is now responsible of the preview panel
	[panel setDelegate:self];
	[panel setDataSource:self];

	// Due to the unknown image format disable image sharing
	[panel setShowsAddToiPhotoButton:NO];
#endif

}

/**
 * QuickLook delegate for SDK 10.6 - not in usage.
 */
- (void)endPreviewPanelControl:(id)panel
{
	// This document loses its responsisibility on the preview panel
	// Until the next call to -beginPreviewPanelControl: it must not
	// change the panel's delegate, data source or refresh it.
}

/**
 * QuickLook delegate for SDK 10.6
 */
- (BOOL)acceptsPreviewPanelControl:(id)panel;
{
	return YES;
}

// QuickLook delegates for SDK 10.6
// - (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
// {
// }

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It always returns 1.
 */
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
	return 1;
}

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It returns as NSURL the temporarily created file.
 */
- (id)previewPanel:(id)panel previewItemAtIndex:(NSInteger)anIndex
{
	if(tmpFileName)
		return [NSURL fileURLWithPath:tmpFileName];

	return nil;
}

/**
 * QuickLook delegate for SDK 10.5.
 *
 * @return It returns the frame of the application's middle. If an empty frame is returned then the panel will fade in/out instead.
 */
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

/**
 * QuickLook delegate for SDK 10.6.
 *
 * @return It returns the frame of the application's middle. If an empty frame is returned then the panel will fade in/out instead.
 */
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

/**
 * Called by (SPImageView) if an image was pasted into the editSheet
 */
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
		if([(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] state] == NSOnState) {
			intValue += bitValue;
			[bitString replaceCharactersInRange:NSMakeRange((NSUInteger)maxTextLength-i-1, 1) withString:@"1"];
		}
		bitValue <<= 1;
	}
	[bitSheetIntegerTextField setStringValue:[[NSNumber numberWithUnsignedLongLong:intValue] stringValue]];
	[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%qX", intValue]];
	[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%jO", intValue]];
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

	NSUInteger i = 0;
	NSUInteger aBit;
	NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

	switch([sender tag]) {
		case 0: // all to 1
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:NSOnState];
		break;
		case 1: // all to 0
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:NSOffState];
		break;
		case 2: // negate
		for(i=0; i<maxBit; i++)
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:![(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] state]];
		break;
		case 3: // shift left
		for(i=maxBit-1; i>0; i--) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i-1]] state]];
		}
		[[self valueForKeyPath:@"bitSheetBitButton0"] setState:NSOffState];
		break;
		case 4: // shift right
		for(i=0; i<maxBit-1; i++) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i+1]] state]];
		}
		[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", maxBit-1]] setState:NSOffState];
		break;
		case 5: // rotate left
		aBit = [(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", maxBit-1]] state];
		for(i=maxBit-1; i>0; i--) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i-1]] state]];
		}
		[[self valueForKeyPath:@"bitSheetBitButton0"] setState:aBit];
		break;
		case 6: // rotate right
		aBit = [(NSButton*)[self valueForKeyPath:@"bitSheetBitButton0"] state];
		for(i=0; i<maxBit-1; i++) {
			[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:[(NSButton*)[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i+1]] state]];
		}
		[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", maxBit-1]] setState:aBit];
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

	NSUInteger i;
	NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

	if([(NSButton*)sender state] == NSOnState) {
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setEnabled:NO];
		[bitSheetHexTextField setEnabled:NO];
		[bitSheetIntegerTextField setEnabled:NO];
		[bitSheetOctalTextField setEnabled:NO];
	} else {
		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setEnabled:YES];
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

		NSUInteger i = 0;
		NSUInteger maxBit = (NSUInteger)((maxTextLength > 64) ? 64 : maxTextLength);

		NSUInteger intValue = (NSUInteger)strtoull([[bitSheetIntegerTextField stringValue] UTF8String], NULL, 0);

		for(i=0; i<maxBit; i++)
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:NSOffState];

		[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%qX", intValue]];
		[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%jO", intValue]];

		i = 0;
		while( intValue && i < maxBit )
		{
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:( (intValue & 0x1) == 0) ? NSOffState : NSOnState];
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
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:NSOffState];

		[bitSheetHexTextField setStringValue:[NSString stringWithFormat:@"%qX", intValue]];
		[bitSheetOctalTextField setStringValue:[NSString stringWithFormat:@"%jO", intValue]];

		i = 0;
		while( intValue && i < maxBit )
		{
			[[self valueForKeyPath:[NSString stringWithFormat:@"bitSheetBitButton%ld", i]] setState:( (intValue & 0x1) == 0) ? NSOffState : NSOnState];
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
