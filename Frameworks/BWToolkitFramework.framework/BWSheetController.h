//
//  BWSheetController.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWSheetController : NSObject
{
	NSWindow *sheet;
	NSWindow *parentWindow;
	id delegate;
}

@property (nonatomic, retain) IBOutlet NSWindow *sheet, *parentWindow;
@property (nonatomic, retain) IBOutlet id delegate;

- (IBAction)openSheet:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)messageDelegateAndCloseSheet:(id)sender;

// The optional delegate should implement the method:
// - (BOOL)shouldCloseSheet:(id)sender
// Return YES if you want the sheet to close after the button click, NO if it shouldn't close. The sender
// object is the button that requested the close. This is helpful because in the event that there are multiple buttons
// hooked up to the messageDelegateAndCloseSheet: method, you can distinguish which button called the method. 

@end
