//
//  YRKSpinningProgressIndicator.h
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface YRKSpinningProgressIndicator : NSView {
    NSInteger _position;
    NSInteger _numFins;

    BOOL _isAnimating;
    NSTimer *_animationTimer;
	NSThread *_animationThread;

    NSColor *_foreColor;
    NSColor *_backColor;
    BOOL _drawBackground;
    
    NSTimer *_fadeOutAnimationTimer;
    BOOL _isFadingOut;
    
    // For determinate mode
    BOOL _isIndeterminate;
    double _currentValue;
    double _maxValue;
    
    BOOL _usesThreadedAnimation;
}

- (void)stopAnimation:(id)sender;
- (void)startAnimation:(id)sender;


// Accessors

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
- (void)setNumberValue:(NSNumber *)numberValue;
- (double)maxValue;
- (void)setMaxValue:(double)maxValue;

- (void)setUsesThreadedAnimation:(BOOL)useThreaded;
- (BOOL)usesThreadedAnimation;

@end
