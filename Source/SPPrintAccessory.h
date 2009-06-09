#import <Cocoa/Cocoa.h>


@interface SPPrintAccessory : NSViewController <NSPrintPanelAccessorizing> 
{
	IBOutlet NSView *printAccessoryView;
	IBOutlet NSUserDefaultsController *defaultsController;
}

@end
