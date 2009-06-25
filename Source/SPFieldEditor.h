//
//  SPFieldEditor.h
//  sequel-pro
//
//  Created by Bibiko on 25.06.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SPFieldEditor : NSWindow {

	IBOutlet id editSheetProgressBar;
	IBOutlet id editSheet;
	IBOutlet id editSheetSegmentControl;
	IBOutlet id editSheetQuickLookButton;
	IBOutlet id editImage;
	IBOutlet id editTextView;
	IBOutlet id hexTextView;
	IBOutlet id editTextScrollView;
	IBOutlet id hexTextScrollView;

	id editData;
	BOOL editSheetWillBeInitialized;
	int quickLookCloseMarker;
	NSStringEncoding encoding;

}

- (IBAction)closeEditSheet:(id)sender;
- (IBAction)openEditSheet:(id)sender;
- (IBAction)saveEditSheet:(id)sender;
- (IBAction)dropImage:(id)sender;
- (IBAction)segmentControllerChanged:(id)sender;
- (IBAction)quickLookFormatButton:(id)sender;

- (void)setEditData:(id)data;

- (void)setMySQLConnectionEncoding:(NSStringEncoding)anEncoding;

- (void)processPasteImageData;
- (void)processUpdatedImageData:(NSData *)data;

- (void)invokeQuickLookOfType:(NSString *)type treatAsText:(BOOL)isText;
- (void)removeQuickLooksTempFile:(NSString*)aPath;

@end
