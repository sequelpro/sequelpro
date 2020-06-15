//
//  SPFieldEditorController.h
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

#ifndef SP_CODA

#import <Quartz/Quartz.h> // QuickLookUI

//This is an informal protocol
@protocol _QLPreviewPanelController

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel;
- (void)endPreviewPanelControl:(QLPreviewPanel *)panel;

@end

#endif

@class SPWindow;

/**
 * @class SPFieldEditorController SPFieldEditorController.h
 *
 * @author Hans-Jörg Bibiko
 *
 * This class offers a sheet for editing different kind of data such as text, blobs (including images) as 
 * editSheet and bit fields as bitSheet. 
 */
@interface SPFieldEditorController : NSWindowController <NSComboBoxDataSource
#ifndef SP_CODA
, QLPreviewPanelDataSource, QLPreviewPanelDelegate, _QLPreviewPanelController
#endif
>
{
	IBOutlet id editSheetProgressBar;
	IBOutlet id editSheetSegmentControl;
	IBOutlet id editSheetQuickLookButton;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
	IBOutlet id jsonTextView;
	IBOutlet id editTextScrollView;
	IBOutlet id hexTextScrollView;
	IBOutlet id jsonTextScrollView;
	IBOutlet SPWindow *editSheet;
	IBOutlet id editSheetCancelButton;
	IBOutlet id editSheetIsNotEditableCancelButton;
	IBOutlet id editSheetOkButton;
	IBOutlet id editSheetOpenButton;
	IBOutlet id editSheetFieldName;

	IBOutlet id bitSheet;
	IBOutlet NSTextField *bitSheetFieldName;
	IBOutlet NSTextField *bitSheetHexTextField;
	IBOutlet NSTextField *bitSheetIntegerTextField;
	IBOutlet NSTextField *bitSheetOctalTextField;
	IBOutlet NSButton *bitSheetOkButton;
	IBOutlet NSButton *bitSheetCloseButton;
	IBOutlet NSButton *bitSheetNULLButton;
	IBOutlet NSButton *bitSheetBitButton0;
	IBOutlet NSButton *bitSheetBitButton1;
	IBOutlet NSButton *bitSheetBitButton2;
	IBOutlet NSButton *bitSheetBitButton3;
	IBOutlet NSButton *bitSheetBitButton4;
	IBOutlet NSButton *bitSheetBitButton5;
	IBOutlet NSButton *bitSheetBitButton6;
	IBOutlet NSButton *bitSheetBitButton7;
	IBOutlet NSButton *bitSheetBitButton8;
	IBOutlet NSButton *bitSheetBitButton9;
	IBOutlet NSButton *bitSheetBitButton10;
	IBOutlet NSButton *bitSheetBitButton11;
	IBOutlet NSButton *bitSheetBitButton12;
	IBOutlet NSButton *bitSheetBitButton13;
	IBOutlet NSButton *bitSheetBitButton14;
	IBOutlet NSButton *bitSheetBitButton15;
	IBOutlet NSButton *bitSheetBitButton16;
	IBOutlet NSButton *bitSheetBitButton17;
	IBOutlet NSButton *bitSheetBitButton18;
	IBOutlet NSButton *bitSheetBitButton19;
	IBOutlet NSButton *bitSheetBitButton20;
	IBOutlet NSButton *bitSheetBitButton21;
	IBOutlet NSButton *bitSheetBitButton22;
	IBOutlet NSButton *bitSheetBitButton23;
	IBOutlet NSButton *bitSheetBitButton24;
	IBOutlet NSButton *bitSheetBitButton25;
	IBOutlet NSButton *bitSheetBitButton26;
	IBOutlet NSButton *bitSheetBitButton27;
	IBOutlet NSButton *bitSheetBitButton28;
	IBOutlet NSButton *bitSheetBitButton29;
	IBOutlet NSButton *bitSheetBitButton30;
	IBOutlet NSButton *bitSheetBitButton31;
	IBOutlet NSButton *bitSheetBitButton32;
	IBOutlet NSButton *bitSheetBitButton33;
	IBOutlet NSButton *bitSheetBitButton34;
	IBOutlet NSButton *bitSheetBitButton35;
	IBOutlet NSButton *bitSheetBitButton36;
	IBOutlet NSButton *bitSheetBitButton37;
	IBOutlet NSButton *bitSheetBitButton38;
	IBOutlet NSButton *bitSheetBitButton39;
	IBOutlet NSButton *bitSheetBitButton40;
	IBOutlet NSButton *bitSheetBitButton41;
	IBOutlet NSButton *bitSheetBitButton42;
	IBOutlet NSButton *bitSheetBitButton43;
	IBOutlet NSButton *bitSheetBitButton44;
	IBOutlet NSButton *bitSheetBitButton45;
	IBOutlet NSButton *bitSheetBitButton46;
	IBOutlet NSButton *bitSheetBitButton47;
	IBOutlet NSButton *bitSheetBitButton48;
	IBOutlet NSButton *bitSheetBitButton49;
	IBOutlet NSButton *bitSheetBitButton50;
	IBOutlet NSButton *bitSheetBitButton51;
	IBOutlet NSButton *bitSheetBitButton52;
	IBOutlet NSButton *bitSheetBitButton53;
	IBOutlet NSButton *bitSheetBitButton54;
	IBOutlet NSButton *bitSheetBitButton55;
	IBOutlet NSButton *bitSheetBitButton56;
	IBOutlet NSButton *bitSheetBitButton57;
	IBOutlet NSButton *bitSheetBitButton58;
	IBOutlet NSButton *bitSheetBitButton59;
	IBOutlet NSButton *bitSheetBitButton60;
	IBOutlet NSButton *bitSheetBitButton61;
	IBOutlet NSButton *bitSheetBitButton62;
	IBOutlet NSButton *bitSheetBitButton63;
	IBOutlet NSTextField *bitSheetBitLabel0;
	IBOutlet NSTextField *bitSheetBitLabel8;
	IBOutlet NSTextField *bitSheetBitLabel16;
	IBOutlet NSTextField *bitSheetBitLabel24;
	IBOutlet NSTextField *bitSheetBitLabel32;
	IBOutlet NSTextField *bitSheetBitLabel40;
	IBOutlet NSTextField *bitSheetBitLabel48;
	IBOutlet NSTextField *bitSheetBitLabel56;

	id usedSheet;
	id callerInstance;
	NSDictionary *contextInfo;

	id sheetEditData;
	BOOL editSheetWillBeInitialized;
	BOOL _isBlob;
	BOOL _isEditable;
	BOOL _allowNULL;
	BOOL doGroupDueToChars;
	NSInteger quickLookCloseMarker;
	NSStringEncoding encoding;
	NSString *fieldType;
	NSString *fieldEncoding;
	NSString *stringValue;
	NSString *tmpFileName;
	NSString *tmpDirPath;

	NSInteger counter;
	unsigned long long maxTextLength;
	BOOL editTextViewWasChanged;
	BOOL allowUndo;
	BOOL wasCutPaste;
	BOOL selectionChanged;

	NSUserDefaults *prefs;

#ifndef SP_CODA
	NSDictionary *qlTypes;
#endif

	NSInteger editSheetReturnCode;
	BOOL _isGeometry;
	BOOL _isJSON;
	NSUndoManager *esUndoManager;

	NSDictionary *editedFieldInfo;
}

@property(readwrite, retain) NSDictionary *editedFieldInfo;

//don't blame me for nonatomic,assign. That's how the previous setters worked :)

/**
 * The maximum text length of the underlying table field for input validation.
 */
@property(nonatomic,assign) unsigned long long textMaxLength;

/**
 * The field type of the underlying table field for input validation.
 * The field type will be used for dispatching which sheet will be shown.
 * If type == BIT the bitSheet will be used otherwise the editSheet.
 */
@property(nonatomic,assign) NSString *fieldType;

/**
 * The field encoding of the underlying table field for displaying it to the user.
 */
@property(nonatomic,assign) NSString *fieldEncoding;

/**
 * Whether underlying table field allows NULL for several validations.
 * If allowNULL is YES NULL value is allowed for the underlying table field.
 */
@property(nonatomic,assign) BOOL allowNULL;

- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo;
- (IBAction)saveEditSheet:(id)sender;
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (IBAction)dropImage:(id)sender;
- (IBAction)segmentControllerChanged:(id)sender;
- (IBAction)quickLookFormatButton:(id)sender;

- (IBAction)bitSheetSelectBit0:(id)sender;
- (IBAction)bitSheetBitButtonWasClicked:(id)sender;
- (IBAction)bitSheetOperatorButtonWasClicked:(id)sender;
- (IBAction)setToNull:(id)sender;
- (void)updateBitSheet;

- (void)editWithObject:(id)data fieldName:(NSString*)fieldName usingEncoding:(NSStringEncoding)anEncoding
		isObjectBlob:(BOOL)isFieldBlob isEditable:(BOOL)isEditable withWindow:(NSWindow *)theWindow
		sender:(id)sender contextInfo:(NSDictionary*)theContextInfo;

- (void)processPasteImageData;
- (void)processUpdatedImageData:(NSData *)data;

- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText;

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;
- (void)textViewDidChangeSelection:(NSNotification *)notification;

- (void)setWasCutPaste;
- (void)setAllowedUndo;
- (void)setDoGroupDueToChars;

@end

@protocol SPFieldEditorControllerDelegate <NSObject>

@optional
- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;

@end
