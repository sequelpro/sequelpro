//
//  PSMOverflowPopUpButton.m
//  NetScrape
//
//  Created by John Pannell on 8/4/04.
//  Copyright 2004 Positive Spin Media. All rights reserved.
//

#import "PSMRolloverButton.h"

@implementation PSMRolloverButton

- (void)awakeFromNib
{
	if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)]) {
        [super awakeFromNib];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(rolloverFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:self];

	[self setPostsFrameChangedNotifications:YES];
	[self resetCursorRects];
	
	_myTrackingRectTag = -1;
	_rolloverImage = nil;
	_usualImage = nil;
}

// the regular image
- (void)setUsualImage:(NSImage *)newImage
{
    [newImage retain];
    [_usualImage release];
    _usualImage = newImage;

	[self setImage:_usualImage];
}

- (NSImage *)usualImage
{
    return _usualImage;
}

- (void)setRolloverImage:(NSImage *)newImage
{
    [newImage retain];
    [_rolloverImage release];
    _rolloverImage = newImage;
}

- (NSImage *)rolloverImage
{
    return _rolloverImage;
}

// Remove old tracking rects when we change superviews
- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	[self removeTrackingRect];
	
	[super viewWillMoveToSuperview:newSuperview];
}

- (void)viewDidMoveToSuperview
{
	[super viewDidMoveToSuperview];
	
	[self resetCursorRects];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	[self removeTrackingRect];
	
	[super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	
	[self resetCursorRects];
}

- (void)rolloverFrameDidChange:(NSNotification *)notification
{
	[self resetCursorRects];
}

- (void)addTrackingRect
{
    // assign a tracking rect to watch for mouse enter/exit
	NSRect	trackRect = [self bounds];
	NSPoint	localPoint = [self convertPoint:[[self window] convertScreenToBase:[NSEvent mouseLocation]] fromView:nil];

	BOOL mouseInside = NSPointInRect(localPoint, trackRect);
	
    _myTrackingRectTag = [self addTrackingRect:trackRect owner:self userData:nil assumeInside:mouseInside];

	if (mouseInside) {
		[self mouseEntered:nil];
	}
	else {
		[self mouseExited:nil];
	}
}

- (void)removeTrackingRect
{
	if (_myTrackingRectTag != -1) {
		[self removeTrackingRect:_myTrackingRectTag];
	}

	_myTrackingRectTag = -1;
}

// override for rollover effect
- (void)mouseEntered:(nullable NSEvent *)event
{
    // set rollover image
    [self setImage:_rolloverImage];

	[super mouseEntered:event];
}

- (void)mouseExited:(nullable NSEvent *)event
{
    // restore usual image
	[self setImage:_usualImage];

	[super mouseExited:event];
}

- (void)resetCursorRects
{
    // called when the button rect has been changed
    [self removeTrackingRect];
    [self addTrackingRect];
}

- (void)setFrame:(NSRect)rect
{
	[super setFrame:rect];
	[self resetCursorRects];
}

- (void)setBounds:(NSRect)rect
{
	[super setBounds:rect];
	[self resetCursorRects];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:_rolloverImage forKey:@"rolloverImage"];
        [coder encodeObject:_usualImage forKey:@"usualImage"];
        [coder encodeInteger:_myTrackingRectTag forKey:@"myTrackingRectTag"];
    }
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        if ([decoder allowsKeyedCoding]) {
            _rolloverImage = [[decoder decodeObjectForKey:@"rolloverImage"] retain];
            _usualImage = [[decoder decodeObjectForKey:@"usualImage"] retain];
            _myTrackingRectTag = [decoder decodeIntegerForKey:@"myTrackingRectTag"];
        }
    }

    return self;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self removeTrackingRect];

	[_rolloverImage release];
	[_usualImage release];

	[super dealloc];
}

@end
