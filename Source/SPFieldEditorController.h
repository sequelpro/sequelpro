//
//  $Id: SPFieldEditorController.h 802 2009-06-03 20:46:57Z bibiko $
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

#import <Cocoa/Cocoa.h>


@interface SPFieldEditorController : NSWindowController {
	
	IBOutlet id editSheetProgressBar;
	IBOutlet id editSheetSegmentControl;
	IBOutlet id editSheetQuickLookButton;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
	IBOutlet id editTextScrollView;
	IBOutlet id hexTextScrollView;
	IBOutlet id editSheet;
	IBOutlet id editSheetCancelButton;
	IBOutlet id editSheetOkButton;
	IBOutlet id editSheetOpenButton;
	
	id sheetEditData;
	BOOL editSheetWillBeInitialized;
	BOOL isBlob;
	int quickLookCloseMarker;
	NSStringEncoding encoding;
	NSString *stringValue;
	NSString *tmpFileName;
	
	int counter;
	
	NSUserDefaults *prefs;
}

- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (IBAction)saveEditSheet:(id)sender;
- (IBAction)dropImage:(id)sender;
- (IBAction)segmentControllerChanged:(id)sender;
- (IBAction)quickLookFormatButton:(id)sender;
- (IBAction)dropImage:(id)sender;

- (id)editWithObject:(id)data usingEncoding:(NSStringEncoding)anEncoding isObjectBlob:(BOOL)isFieldBlob isEditable:(BOOL)isEditable withWindow:(NSWindow *)tableWindow;

- (void)processPasteImageData;
- (void)processUpdatedImageData:(NSData *)data;

- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText;
- (void)removeQuickLooksTempFile:(NSString*)aPath;

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector;
- (void)textViewDidChangeSelection:(NSNotification *)notification;

@end
