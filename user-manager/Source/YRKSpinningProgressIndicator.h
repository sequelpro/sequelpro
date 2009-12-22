//
//  YRKSpinningProgressIndicator.h
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface YRKSpinningProgressIndicator : NSView {
    int _position;
    int _numFins;

	BOOL _isIndeterminate;
	double _currentValue;
	double _maxValue;

    BOOL _isAnimating;
	NSThread *_animationThread;

    NSColor *_foreColor;
    NSColor *_backColor;
    BOOL _drawBackground;
}
- (void)animate:(id)sender;
- (void)stopAnimation:(id)sender;
- (void)startAnimation:(id)sender;

- (NSColor *)foreColor;
- (void)setForeColor:(NSColor *)value;

- (NSColor *)backColor;
- (void)setBackColor:(NSColor *)value;

- (BOOL)drawBackground;
- (void)setDrawBackground:(BOOL)value;

- (BOOL)isIndeterminate;
- (void)setIndeterminate:(BOOL)isIndeterminate;

- (double)doubleValue;
- (void)setDoubleValue:(double)doubleValue;
- (double)maxValue;
- (void)setMaxValue:(double)maxValue;
@end
