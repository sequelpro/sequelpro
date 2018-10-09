//
//  SPPillAttachmentCell.m
//  sequel-pro
//
//  Created by Max Lohrmann on 01.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPPillAttachmentCell.h"

@interface SPPillAttachmentCell ()

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView characterIndex:(NSUInteger)charIndex layoutManager:(NSLayoutManager *)layoutManager;

@end

@implementation SPPillAttachmentCell

- (id)init
{
    if(self = [super init]) {
        _borderColor = [[NSColor colorWithCalibratedRed:168/255.0 green:184/255.0 blue:249/255.0 alpha: 1] retain];
        _gradient    = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:199/255.0 green:216/255.0 blue:244/255.0 alpha: 1]
                                                     endingColor:[NSColor colorWithCalibratedRed:217/255.0 green:229/255.0 blue:247/255.0 alpha: 1]];
    }
    return self;
}

- (void)dealloc
{
    SPClear(_borderColor);
    SPClear(_gradient);

    [super dealloc];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [self drawWithFrame:cellFrame inView:controlView characterIndex:NSNotFound];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView characterIndex:(NSUInteger)charIndex
{
    [self drawWithFrame:cellFrame inView:controlView characterIndex:charIndex layoutManager:nil];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView characterIndex:(NSUInteger)charIndex layoutManager:(NSLayoutManager *)layoutManager
{
	CGFloat bRadius = cellFrame.size.height/2.0;
    NSBezierPath* rectanglePath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cellFrame,1,1) xRadius:bRadius yRadius:bRadius];
    [_gradient drawInBezierPath: rectanglePath angle: -90];
    [_borderColor setStroke];
    [rectanglePath setLineWidth:1.0];
    [rectanglePath stroke];

    [self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSString* textContent = [self stringValue];
    NSMutableParagraphStyle* rectangleStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    [rectangleStyle setAlignment:NSCenterTextAlignment];

    NSMutableDictionary *rectangleFontAttributes = [NSMutableDictionary dictionaryWithDictionary:[self attributes]];
    [rectangleFontAttributes setObject:[rectangleStyle autorelease] forKey:NSParagraphStyleAttributeName];

    //cellFrame.origin.y += [[self font] descender];
    [textContent drawInRect:cellFrame withAttributes:rectangleFontAttributes];
}

- (NSPoint)cellBaselineOffset
{
    //Not used in menu
    return NSMakePoint(0, [[self font] descender]-1);
}

- (NSRect)cellFrameForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(NSRect)lineFrag glyphPosition:(NSPoint)position characterIndex:(NSUInteger)charIndex
{
    NSSize sz = [self cellSize];
	CGFloat offset = (lineFrag.size.height - sz.height) / 2;
    return NSMakeRect(0, [[self font] descender]+offset, sz.width+(2*12), sz.height);
}

- (NSSize)cellSize
{
    //Not used in menu
    return [[self stringValue] sizeWithAttributes:[self attributes]];
}

- (NSDictionary *)attributes
{
    return @{NSFontAttributeName: [self font]};
}

@end
