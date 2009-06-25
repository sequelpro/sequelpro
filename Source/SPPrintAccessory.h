#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface SPPrintAccessory : NSViewController <NSPrintPanelAccessorizing> 
{
	IBOutlet NSView *printAccessoryView;
	IBOutlet NSUserDefaultsController *defaultsController;

	WebView *printWebView;
}

- (void) setPrintView:(WebView *)theWebView;

@end
