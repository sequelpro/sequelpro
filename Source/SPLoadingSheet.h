//
//  SPLoadingSheet.h
//  Sequel Plus
//
//  A small sheet saying what is loading, shown while a slow sheet (the User Manager) gets ready.
//

#import <Cocoa/Cocoa.h>

/**
 * A small sheet on a window: a spinning indicator, a message (e.g. "Loading users…") and, when a cancel handler is
 * given, a Cancel button. The indicator keeps spinning while the main thread is busy (threaded animation).
 *
 * Built in code. Main thread only. The sheet is attached only when the window has no sheet already (see isShown);
 * -end detaches it (once; it is also safe when it was never shown). Cancel ends it, then calls the handler once.
 */
__attribute__((visibility("default")))
@interface SPLoadingSheet : NSObject

/// A new sheet, attached to window at once (unless window is nil or already has a sheet).
+ (instancetype)beginOnWindow:(NSWindow *)window message:(NSString *)message cancelHandler:(void (^)(void))cancelHandler;

/// Ends the sheet. Its cancel handler isn't called (and is dropped).
- (void)end;

@property (readonly, getter=isShown) BOOL shown;
@property (readonly) NSPanel *panel;
@property (readonly) NSProgressIndicator *spinner;
@property (readonly) NSTextField *messageField;
/// nil without a cancel handler.
@property (readonly) NSButton *cancelButton;

- (IBAction)cancel:(id)sender;

@end
