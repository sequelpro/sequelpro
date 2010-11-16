//
//  SRValidator.h
//  ShortcutRecorder
//
//  Copyright 2006-2007 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      David Dauer
//      Jesper
//      Jamie Kirkpatrick

#import <Cocoa/Cocoa.h>

@interface SRValidator : NSObject {
    id              delegate;
}

- (id) initWithDelegate:(id)theDelegate;

- (BOOL) isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags error:(NSError **)error;
- (BOOL) isKeyCode:(NSInteger)keyCode andFlags:(NSUInteger)flags takenInMenu:(NSMenu *)menu error:(NSError **)error;

- (id) delegate;
- (void) setDelegate: (id) theDelegate;

@end

#pragma mark -

@interface NSObject( SRValidation )
- (BOOL) shortcutValidator:(SRValidator *)validator isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason;
@end
