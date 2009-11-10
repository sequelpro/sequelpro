//
// YRKSpinningProgressIndicator.m
//
// Original drawing code by Kelan Champagne; forked by Rowan Beentje
// for fixes, determinate mode, and threaded drawing.
//
// Copyright (c) 2009, Kelan Champagne (http://yeahrightkeller.com)
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the <organization> nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY Kelan Champagne ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL Kelan Champagne BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "YRKSpinningProgressIndicator.h"


@interface YRKSpinningProgressIndicator (YRKSpinningProgressIndicatorPrivate)

- (void) animateInBackgroundThread;

@end


@implementation YRKSpinningProgressIndicator

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _position = 0;
        _numFins = 12;
        _isAnimating = NO;
		_animationThread = nil;
		_foreColor = nil;
		_backColor = nil;
		_isIndeterminate = YES;
		_currentValue = 0.0;
		_maxValue = 100.0;
    }
    return self;
}

- (void) dealloc {
	if (_foreColor) [_foreColor release];
	if (_backColor) [_backColor release];
	if (_isAnimating) [self stopAnimation:self];
	[super dealloc];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    if ([self window] == nil) {
        // No window?  View hierarchy may be going away.  Ensure animation is stopped.
        [self stopAnimation:self];
    }
    else if (_isAnimating) {
		[self stopAnimation:self];
		[self startAnimation:self];
    }
}

- (void)drawRect:(NSRect)rect
{
	int i;
	float alpha = 1.0;

	// Determine size based on current bounds
	NSSize size = [self bounds].size;
	float maxSize;
	if(size.width >= size.height)
		maxSize = size.height;
	else
		maxSize = size.width;

	// fill the background, if set
	if(_drawBackground) {
		[_backColor set];
		[NSBezierPath fillRect:[self bounds]];
	}

	CGContextRef currentContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	[NSGraphicsContext saveGraphicsState];

	// Move the CTM so 0,0 is at the center of our bounds
	CGContextTranslateCTM(currentContext,[self bounds].size.width/2,[self bounds].size.height/2);

	if (_isIndeterminate) {

		// do initial rotation to start place
		CGContextRotateCTM(currentContext, 3.14159*2/_numFins * _position);

		NSBezierPath *path = [[NSBezierPath alloc] init];
		float lineWidth = 0.08 * maxSize; // should be 2.75 for 32x32
		float lineStart = 0.234375 * maxSize; // should be 7.5 for 32x32
		float lineEnd = 0.421875 * maxSize;  // should be 13.5 for 32x32
		[path setLineWidth:lineWidth];
		[path setLineCapStyle:NSRoundLineCapStyle];
		[path moveToPoint:NSMakePoint(0,lineStart)];
		[path lineToPoint:NSMakePoint(0,lineEnd)];

		for (i=0; i<_numFins; i++) {
			if(_isAnimating) {
				[[_foreColor colorWithAlphaComponent:alpha] set];
			} else {
				[[_foreColor colorWithAlphaComponent:0.2] set];
			}

			[path stroke];

			// we draw all the fins by rotating the CTM, then just redraw the same segment again
			CGContextRotateCTM(currentContext, 6.282185/_numFins);
			alpha -= 1.0/_numFins;
		}
		[path release];

	} else {

		float lineWidth = 1 + (0.01 * maxSize);
		float circleRadius = (maxSize - lineWidth) / 2.1;
		NSPoint circleCenter = NSMakePoint(0, 0);
		[[_foreColor colorWithAlphaComponent:alpha] set];
		NSBezierPath *path = [[NSBezierPath alloc] init];
		[path setLineWidth:lineWidth];
		[path appendBezierPathWithOvalInRect:NSMakeRect(-circleRadius, -circleRadius, circleRadius*2, circleRadius*2)];
		[path stroke];
		[path release];
		path = [[NSBezierPath alloc] init];
		[path appendBezierPathWithArcWithCenter:circleCenter radius:circleRadius startAngle:90 endAngle:90-(360*(_currentValue/_maxValue)) clockwise:YES];
		[path lineToPoint:circleCenter] ;
		[path fill];
		[path release];
	}

	[NSGraphicsContext restoreGraphicsState];
}

# pragma mark -
# pragma mark Subclass

- (void)animate:(id)sender
{
    if(_position > 1) {
        _position--;
    }
    else {
        _position = _numFins;
    }
	[self display];
}

- (void) animateInBackgroundThread
{
	NSAutoreleasePool *animationPool = [[NSAutoreleasePool alloc] init];
	
	// Set up the animation speed to subtly change with size > 32.
	int animationDelay = 38000 + (2000 * ([self bounds].size.height / 32));
	int poolFlushCounter = 0;

	do {
		[self animate:nil];
		usleep(animationDelay);
		poolFlushCounter++;
		if (poolFlushCounter > 256) {
			[animationPool drain];
			animationPool = [[NSAutoreleasePool alloc] init];
			poolFlushCounter = 0;
		}
	} while (![[NSThread currentThread] isCancelled]); 

	[animationPool release];
}

- (void)startAnimation:(id)sender
{
	if (_isAnimating) return;
    _isAnimating = YES;

	_animationThread = [[NSThread alloc] initWithTarget:self selector:@selector(animateInBackgroundThread) object:nil];
	[_animationThread start];
}

- (void)stopAnimation:(id)sender
{
    _isAnimating = NO;
	if (_animationThread) {
		[_animationThread cancel];
		if (![_animationThread isFinished]) {
			[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
		}
		[_animationThread release], _animationThread = nil;
	}

    [self setNeedsDisplay:YES];
}

# pragma mark Not Implemented

- (void)setStyle:(NSProgressIndicatorStyle)style
{
    if (NSProgressIndicatorSpinningStyle != style) {
        NSAssert(NO, @"Non-spinning styles not available.");
    }
}


# pragma mark -
# pragma mark Accessors

- (NSColor *)foreColor
{
    return [[_foreColor retain] autorelease];
}

- (void)setForeColor:(NSColor *)value
{
    if (_foreColor != value) {
        [_foreColor release];
        _foreColor = [value copy];
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)backColor
{
    return [[_backColor retain] autorelease];
}

- (void)setBackColor:(NSColor *)value
{
    if (_backColor != value) {
        [_backColor release];
        _backColor = [value copy];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)drawBackground
{
    return _drawBackground;
}

- (void)setDrawBackground:(BOOL)value
{
    if (_drawBackground != value) {
        _drawBackground = value;
    }
    [self setNeedsDisplay:YES];
}

- (BOOL)isIndeterminate
{
	return _isIndeterminate;
}

- (void)setIndeterminate:(BOOL)isIndeterminate
{
	_isIndeterminate = isIndeterminate;
	if (!_isIndeterminate && _isAnimating) [self stopAnimation:self];
	[self displayIfNeeded];
}

- (double)doubleValue
{
	return _currentValue;
}

- (void)setDoubleValue:(double)doubleValue
{
	if (_isIndeterminate) _isIndeterminate = NO;
	_currentValue = doubleValue;
	[self setNeedsDisplay:YES];
}

- (double)maxValue
{
	return _maxValue;
}

- (void)setMaxValue:(double)maxValue
{
	_maxValue = maxValue;
	[self displayIfNeeded];
}

@end
