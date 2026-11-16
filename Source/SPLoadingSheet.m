//
//  SPLoadingSheet.m
//  Sequel Plus
//

#import "SPLoadingSheet.h"

@implementation SPLoadingSheet
{
	NSWindow *parentWindow;          // not retained: the sheet ends before its window goes
	void (^cancelHandler)(void);
}

@synthesize shown;
@synthesize panel;
@synthesize spinner;
@synthesize messageField;
@synthesize cancelButton;

+ (instancetype)beginOnWindow:(NSWindow *)window message:(NSString *)message cancelHandler:(void (^)(void))theCancelHandler
{
	SPLoadingSheet *sheet = [[[self alloc] init] autorelease];
	[sheet _buildWithMessage:message cancellable:(theCancelHandler != nil)];
	sheet->cancelHandler = [theCancelHandler copy];

	if (window && ![window attachedSheet]) {
		sheet->parentWindow = window;
		sheet->shown = YES;
		[sheet->spinner startAnimation:nil];
		[sheet retain]; // until the sheet ends
		[window beginSheet:sheet->panel completionHandler:^(NSModalResponse returnCode) {
			[sheet autorelease];
		}];
	}
	return sheet;
}

- (void)dealloc
{
	[cancelHandler release];
	[panel release];
	[spinner release];
	[messageField release];
	[cancelButton release];
	[super dealloc];
}

- (void)_buildWithMessage:(NSString *)message cancellable:(BOOL)cancellable
{
	CGFloat width = 320, height = cancellable ? 100 : 64;
	panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[panel setReleasedWhenClosed:NO];
	NSView *content = [panel contentView];

	spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, height - 44, 24, 24)];
	[spinner setStyle:NSProgressIndicatorStyleSpinning];
	[spinner setIndeterminate:YES];
	[spinner setDisplayedWhenStopped:NO];
	// Spins on its own thread, so it keeps moving while the main thread waits for the server
	[spinner setUsesThreadedAnimation:YES];
	[content addSubview:spinner];

	messageField = [[NSTextField labelWithString:message ?: @""] retain];
	[messageField setFrame:NSMakeRect(54, height - 42, width - 74, 20)];
	[messageField setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
	[messageField setLineBreakMode:NSLineBreakByTruncatingTail];
	[content addSubview:messageField];

	if (cancellable) {
		cancelButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Cancel", @"cancel button") target:self action:@selector(cancel:)] retain];
		[cancelButton sizeToFit];
		NSRect frame = [cancelButton frame];
		frame.size.width = MAX(NSWidth(frame), 82);
		frame.origin = NSMakePoint(width - 20 - NSWidth(frame), 14);
		[cancelButton setFrame:frame];
		[cancelButton setKeyEquivalent:@"\e"];
		[content addSubview:cancelButton];
	}
}

- (void)end
{
	[cancelHandler release];
	cancelHandler = nil;
	if (!shown) return;
	shown = NO;
	[spinner stopAnimation:nil];
	[cancelButton setTarget:nil];
	NSWindow *window = parentWindow;
	parentWindow = nil;
	if ([panel sheetParent]) [[panel sheetParent] endSheet:panel];
	else if (window) [window endSheet:panel];
	[panel orderOut:nil];
}

- (IBAction)cancel:(id)sender
{
	void (^handler)(void) = [[cancelHandler retain] autorelease];
	[self end];
	if (handler) handler();
}

@end
