//
//  NoodleLineNumberView.h
//  sequel-pro
//
//  Created by Paul Kim on September 28, 2008.
//  Copyright (c) 2008 Noodlesoft, LLC. All rights reserved.
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

@interface NoodleLineNumberView : NSRulerView
{

	// Array of character indices for the beginning of each line
	NSMutableArray  *lineIndices;
	NSUInteger      currentNumberOfLines;

	NSFont          *font;
	NSColor         *textColor;
	NSColor         *alternateTextColor;
	NSColor         *backgroundColor;
	CGFloat         maxHeightOfGlyph;
	CGFloat         maxWidthOfGlyph;
	CGFloat         maxWidthOfGlyph1;
	CGFloat         maxWidthOfGlyph2;
	CGFloat         maxWidthOfGlyph3;
	CGFloat         maxWidthOfGlyph4;
	CGFloat         maxWidthOfGlyph5;
	CGFloat         maxWidthOfGlyph6;
	CGFloat         maxWidthOfGlyph7;
	CGFloat         maxWidthOfGlyph8;
	CGFloat         currentRuleThickness;
	NSDictionary    *textAttributes;

	// Add support for selection by clicking/dragging
	NSUInteger      dragSelectionStartLine;

	SEL lineNumberForCharacterIndexSel;
	IMP lineNumberForCharacterIndexIMP;
	SEL lineRangeForRangeSel;
	SEL numberWithUnsignedIntegerSel;
	IMP numberWithUnsignedIntegerIMP;
	SEL addObjectSel;
	IMP addObjectIMP;
	SEL rangeOfLineSel;
	Class numberClass;

	NSLayoutManager  *layoutManager;
	NSTextContainer  *container;
	NSTextView       *clientView;


}

@property(retain) NSColor *alternateTextColor;
@property(retain) NSColor *backgroundColor;

- (NSFont*)font;
- (void)setFont:(NSFont*)aFont;
- (NSColor*)textColor;
- (void)setTextColor:(NSColor*)color;

- (id)initWithScrollView:(NSScrollView *)aScrollView;
- (NSUInteger)lineNumberForLocation:(CGFloat)location;
- (NSUInteger)lineNumberForCharacterIndex:(NSUInteger)index;

@end
