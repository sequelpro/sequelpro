//
//  YRKSpinningProgressIndicator.h
//
//  Original drawing code by Kelan Champagne; forked by Rowan Beentje
//  for fixes, determinate mode, and threaded drawing.
//
//  Copyright (c) 2009, Kelan Champagne (http://yeahrightkeller.com)
//  All rights reserved.
// 
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the <organization> nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
// 
//  THIS SOFTWARE IS PROVIDED BY Kelan Champagne ''AS IS'' AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL Kelan Champagne BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@interface YRKSpinningProgressIndicator : NSView 
{
    NSInteger _position;
    NSInteger _numFins;

    BOOL _isAnimating;
    NSTimer *_animationTimer;
	NSThread *_animationThread;

    NSColor *_foreColor;
    NSColor *_backColor;
    BOOL _drawBackground;
    NSShadow *_shadow;
    
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
