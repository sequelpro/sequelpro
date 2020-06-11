//
//  NoodleLineNumberView.h
//  sequel-pro
//
//  Created by Paul Kim on September 28, 2008.
//  Copyright (c) 2008 Noodlesoft, LLC. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// This version of the NoodleLineNumberView for Sequel Ace removes marker
// functionality and adds selection by clicking on the ruler. Furthermore
// the code was optimized.

#import "NoodleLineNumberView.h"

#include <tgmath.h>

#pragma mark NSCoding methods

#define NOODLE_FONT_CODING_KEY              @"font"
#define NOODLE_TEXT_COLOR_CODING_KEY        @"textColor"
#define NOODLE_ALT_TEXT_COLOR_CODING_KEY    @"alternateTextColor"
#define NOODLE_BACKGROUND_COLOR_CODING_KEY  @"backgroundColor"

#pragma mark -

#define DEFAULT_THICKNESS  22.0f
#define RULER_MARGIN        5.0f
#define RULER_MARGIN2       RULER_MARGIN * 2

typedef NSRange (*RangeOfLineIMP)(id object, SEL selector, NSRange range);

// Cache loop methods for speed

#pragma mark -

@interface NoodleLineNumberView ()

- (NSArray *)lineIndices;
- (void)invalidateLineIndices;
- (void)calculateLines;
- (void)updateGutterThicknessConstants;
- (void)setRuleThicknessNumber:(NSNumber *)aNum;

@end

@implementation NoodleLineNumberView

@synthesize alternateTextColor;
@synthesize backgroundColor;

- (id)initWithScrollView:(NSScrollView *)aScrollView
{

	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil)
	{
		[self setClientView:[aScrollView documentView]];
		[self setAlternateTextColor:[NSColor whiteColor]];
		lineIndices = nil;
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[self font], NSFontAttributeName, 
			[self textColor], NSForegroundColorAttributeName,
			nil] retain];

		NSSize s = [@"8" sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
		currentRuleThickness = 0.0f;
		dragSelectionStartLine = NSNotFound;

		// Cache loop methods for speed
		lineNumberForCharacterIndexSel = @selector(lineNumberForCharacterIndex:);
		lineNumberForCharacterIndexIMP = [self methodForSelector:lineNumberForCharacterIndexSel];
		lineRangeForRangeSel = @selector(lineRangeForRange:);
		addObjectSel = @selector(addObject:);
		numberWithUnsignedIntegerSel = @selector(numberWithUnsignedInteger:);
		numberWithUnsignedIntegerIMP = [NSNumber methodForSelector:numberWithUnsignedIntegerSel];
		rangeOfLineSel = @selector(getLineStart:end:contentsEnd:forRange:);

		currentNumberOfLines = 1;
		numberClass = [NSNumber class];

	}

	return self;
}

- (void)awakeFromNib
{
	[self setClientView:[[self scrollView] documentView]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	if (lineIndices) [lineIndices release];
	if (textAttributes) [textAttributes release];
	if (font) [font release];
	if (textColor) [textColor release];
	[super dealloc];
}

#pragma mark -

- (void)setFont:(NSFont *)aFont
{
	if (font != aFont)
	{
		[font autorelease];
		font = [aFont retain];
		if (textAttributes) [textAttributes release];
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName, 
			[self textColor], NSForegroundColorAttributeName,
			nil] retain];
		NSSize s = [@"8" sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
	}
}

- (NSFont *)font
{
	if (font == nil)
		return [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];

	return font;
}

- (void)setTextColor:(NSColor *)color
{
	if (textColor != color)
	{
		[textColor autorelease];
		textColor  = [color retain];
		if (textAttributes) [textAttributes release];
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[self font], NSFontAttributeName, 
			textColor, NSForegroundColorAttributeName,
			nil] retain];
		NSSize s = [@"8" sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
	}
}

- (NSColor *)textColor
{
	if (textColor == nil)
		return [NSColor colorWithCalibratedWhite:0.42f alpha:1.0f];

	return textColor;
}

- (void)setClientView:(NSView *)aView
{
	id oldClientView = [self clientView];

	if ((oldClientView != aView) && [oldClientView isKindOfClass:[NSTextView class]])
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)oldClientView textStorage]];

	[super setClientView:aView];

	if ((aView != nil) && [aView isKindOfClass:[NSTextView class]])
	{
		layoutManager  = [(NSTextView*)aView layoutManager];
		container      = [(NSTextView*)aView textContainer];
		clientView     = (NSTextView*)[self clientView];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:[clientView textStorage]];
		[self invalidateLineIndices];
	}

}

#pragma mark -

- (void)textDidChange:(NSNotification *)notification
{

	if(!clientView) return;

	// Invalidate the line indices only if text view was changed in length but not if the font was changed.
	// They will be recalculated and recached on demand.
	if([[clientView textStorage] editedMask] != 1)
		[self invalidateLineIndices];

	[self setNeedsDisplayInRect:[self bounds]];

}

- (NSUInteger)lineNumberForLocation:(CGFloat)location
{
	NSUInteger      line, count, rectCount;
	NSRectArray     rects;
	NSRect          visibleRect;
	NSRange         nullRange;
	NSArray         *lines;
	id              view;

	view = [self clientView];
	visibleRect = [[[self scrollView] contentView] bounds];

	lines = [self lineIndices];

	location += NSMinY(visibleRect);
	
	if ([view isKindOfClass:[NSTextView class]])
	{

		nullRange = NSMakeRange(NSNotFound, 0);
		count = [lines count];

		// Find the characters that are currently visible
		NSRange range = [layoutManager characterRangeForGlyphRange:[layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container] actualGlyphRange:NULL];

		// Fudge the range a tad in case there is an extra new line at end.
		// It doesn't show up in the glyphs so would not be accounted for.
		range.length++;

		for (line = (NSUInteger)(*lineNumberForCharacterIndexIMP)(self, lineNumberForCharacterIndexSel, range.location); line < count; line++)
		{

			rects = [layoutManager rectArrayForCharacterRange:NSMakeRange([NSArrayObjectAtIndex(lines, line) unsignedIntegerValue], 0)
								 withinSelectedCharacterRange:nullRange
											  inTextContainer:container
													rectCount:&rectCount];

			if(!rectCount) return NSNotFound;

			if ((location >= NSMinY(rects[0])) && (location < NSMaxY(rects[0])))
				return line + 1;

		}
	}
	return NSNotFound;
}

- (NSUInteger)lineNumberForCharacterIndex:(NSUInteger)charIndex
{
	NSUInteger      left, right, mid, lineStart;
	NSArray  *lines;

	lines = [self lineIndices];

	// Binary search
	left = 0;
	right = [lines count];

	while ((right - left) > 1)
	{

		mid = (right + left) >> 1;
		lineStart = [NSArrayObjectAtIndex(lines, mid) unsignedIntegerValue];

		if (charIndex < lineStart)
			right = mid;
		else if (charIndex > lineStart)
			left = mid;
		else
			return mid;

	}
	return left;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{

	NSRect bounds;

	bounds = [self bounds];

	// if (backgroundColor != nil)
	// {
	// 	[backgroundColor set];
	// 	NSRectFill(bounds);
	// 
	// 	[[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
	// 	[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds)) toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];
	// }

	if ([clientView isKindOfClass:[NSTextView class]])
	{
		NSRect           visibleRect;
		NSRange          range, nullRange;
		NSString         *labelText;
		NSUInteger       rectCount, lineIndex, line, count;
		NSRectArray      rects;
		CGFloat          yinset;
		NSArray          *lines;

		nullRange      = NSMakeRange(NSNotFound, 0);

		yinset         = [clientView textContainerInset].height;
		visibleRect    = [[[self scrollView] contentView] bounds];

		lines          = [self lineIndices];
		count          = [lines count];

		if(!count) return;

		// Find the characters that are currently visible
		range = [layoutManager characterRangeForGlyphRange:[layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container] actualGlyphRange:NULL];

		// Fudge the range a tad in case there is an extra new line at end.
		// It doesn't show up in the glyphs so would not be accounted for.
		range.length++;

		CGFloat boundsRULERMargin2 = NSWidth(bounds) - RULER_MARGIN2;
		CGFloat boundsWidthRULER   = NSWidth(bounds) - RULER_MARGIN;
		CGFloat yinsetMinY         = yinset - NSMinY(visibleRect);
		CGFloat rectHeight;

		for (line = (NSUInteger)(*lineNumberForCharacterIndexIMP)(self, lineNumberForCharacterIndexSel, range.location); line < count; line++)
		{
			lineIndex = [NSArrayObjectAtIndex(lines, line) unsignedIntegerValue];

			if (NSLocationInRange(lineIndex, range))
			{
				rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(lineIndex, 0)
					withinSelectedCharacterRange:nullRange
					inTextContainer:container
					rectCount:&rectCount];

				if (rectCount > 0)
				{
					// Note that the ruler view is only as tall as the visible
					// portion. Need to compensate for the clipview's coordinates.

					// Line numbers are internally stored starting at 0
					labelText = [NSString stringWithFormat:@"%llu", (unsigned long long)(line + 1)];

					// How many digits has the current line number?
					NSUInteger idx = line + 1;
					NSInteger numOfDigits = 0;
					while(idx) { numOfDigits++; idx/=10; }

					rectHeight = NSHeight(rects[0]);
					// Draw string flush right, centered vertically within the line
					[labelText drawInRect:
					NSMakeRect(boundsWidthRULER - (maxWidthOfGlyph * numOfDigits),
						yinsetMinY + NSMinY(rects[0]) + ((NSInteger)(rectHeight - maxHeightOfGlyph) >> 1),
						boundsRULERMargin2, rectHeight)
						withAttributes:textAttributes];
				}
			}

			if (lineIndex > NSMaxRange(range))
				break;

		}
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{

	NSUInteger  line;
	NSTextView  *view;

	if (![[self clientView] isKindOfClass:[NSTextView class]]) return;
	view = (NSTextView *)[self clientView];

	line = [self lineNumberForLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil].y];
	dragSelectionStartLine = line;

	if (line != NSNotFound)
	{
		NSUInteger selectionStart, selectionEnd;
		NSArray *lines = [self lineIndices];

		selectionStart = [NSArrayObjectAtIndex(lines, (line - 1)) unsignedIntegerValue];
		if (line < [lines count]) {
			selectionEnd = [NSArrayObjectAtIndex(lines, line) unsignedIntegerValue];
		} else {
			selectionEnd = [[view string] length];
		}
		[view setSelectedRange:NSMakeRange(selectionStart, selectionEnd - selectionStart)];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{

	NSUInteger   line, startLine, endLine;
	NSTextView   *view;

	if (![[self clientView] isKindOfClass:[NSTextView class]] || dragSelectionStartLine == NSNotFound) return;
	view = (NSTextView *)[self clientView];

	line = [self lineNumberForLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil].y];

	if (line != NSNotFound)
	{
		NSUInteger selectionStart, selectionEnd;
		NSArray *lines = [self lineIndices];
		if (line >= dragSelectionStartLine) {
			startLine = dragSelectionStartLine;
			endLine = line;
		} else {
			startLine = line;
			endLine = dragSelectionStartLine;
		}

		selectionStart = [NSArrayObjectAtIndex(lines, (startLine - 1)) unsignedIntegerValue];
		if (endLine < [lines count]) {
			selectionEnd = [NSArrayObjectAtIndex(lines, endLine) unsignedIntegerValue];
		} else {
			selectionEnd = [[view string] length];
		}
		[view setSelectedRange:NSMakeRange(selectionStart, selectionEnd - selectionStart)];
	}

	[view autoscroll:theEvent];
}

#pragma mark -

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([decoder allowsKeyedCoding])
		{
			font = [[decoder decodeObjectForKey:NOODLE_FONT_CODING_KEY] retain];
			textColor = [[decoder decodeObjectForKey:NOODLE_TEXT_COLOR_CODING_KEY] retain];
			alternateTextColor = [[decoder decodeObjectForKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY] retain];
			backgroundColor = [[decoder decodeObjectForKey:NOODLE_BACKGROUND_COLOR_CODING_KEY] retain];
		}
		else
		{
			font = [[decoder decodeObject] retain];
			textColor = [[decoder decodeObject] retain];
			alternateTextColor = [[decoder decodeObject] retain];
			backgroundColor = [[decoder decodeObject] retain];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	if ([encoder allowsKeyedCoding])
	{
		[encoder encodeObject:font forKey:NOODLE_FONT_CODING_KEY];
		[encoder encodeObject:textColor forKey:NOODLE_TEXT_COLOR_CODING_KEY];
		[encoder encodeObject:alternateTextColor forKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY];
		[encoder encodeObject:backgroundColor forKey:NOODLE_BACKGROUND_COLOR_CODING_KEY];
	}
	else
	{
		[encoder encodeObject:font];
		[encoder encodeObject:textColor];
		[encoder encodeObject:alternateTextColor];
		[encoder encodeObject:backgroundColor];
	}
}

#pragma mark -
#pragma mark PrivateAPI

- (NSArray *)lineIndices
{

	if (lineIndices == nil)
		[self calculateLines];

	return lineIndices;

}

- (void)invalidateLineIndices
{

	if (lineIndices) SPClear(lineIndices);

}

- (void)calculateLines
{

	if ([clientView isKindOfClass:[NSTextView class]])
	{

		NSUInteger anIndex, stringLength, lineEnd, contentEnd;
		NSString   *textString;
		CGFloat    newThickness;

		textString   = [clientView string];
		stringLength = [textString length];

		// Switch off line numbering if text larger than 3MB
		// for performance reasons.
		// TODO improve performance maybe via threading
		if(stringLength>3000000)
			return;

		lineIndices = [[NSMutableArray alloc] initWithCapacity:currentNumberOfLines];

		anIndex = 0;

		// Cache loop methods for speed
		IMP rangeOfLineIMP = [textString methodForSelector:rangeOfLineSel];
		addObjectIMP = [lineIndices methodForSelector:addObjectSel];
		
		do
		{
			(void)(*addObjectIMP)(lineIndices, addObjectSel, (*numberWithUnsignedIntegerIMP)(numberClass, numberWithUnsignedIntegerSel, anIndex));
			(*rangeOfLineIMP)(textString, rangeOfLineSel, NULL, &anIndex, NULL, NSMakeRange(anIndex, 0));
		}
		while (anIndex < stringLength);

		// Check if text ends with a new line.
		(*rangeOfLineIMP)(textString, rangeOfLineSel, NULL, &lineEnd, &contentEnd, NSMakeRange([[lineIndices lastObject] unsignedIntValue], 0));
		if (contentEnd < lineEnd)
			(void)(*addObjectIMP)(lineIndices, addObjectSel, (*numberWithUnsignedIntegerIMP)(numberClass, numberWithUnsignedIntegerSel, anIndex));

		NSUInteger lineCount = [lineIndices count];
		if(lineCount < 100)
			newThickness = maxWidthOfGlyph2;
		else if(lineCount < 1000)
			newThickness = maxWidthOfGlyph3;
		else if(lineCount < 10000)
			newThickness = maxWidthOfGlyph4;
		else if(lineCount < 100000)
			newThickness = maxWidthOfGlyph5;
		else if(lineCount < 1000000)
			newThickness = maxWidthOfGlyph6;
		else if(lineCount < 10000000)
			newThickness = maxWidthOfGlyph7;
		else if(lineCount < 100000000)
			newThickness = maxWidthOfGlyph8;
		else
			newThickness = 100;

		currentNumberOfLines = lineCount;

		if (currentRuleThickness != newThickness)
		{

			currentRuleThickness = newThickness;

			// Not a good idea to resize the view during calculations (which can happen during
			// display). Do a delayed perform.
			[self performSelector:@selector(setRuleThicknessNumber:) withObject:[NSNumber numberWithFloat:newThickness] afterDelay:0.0];
		}
	}
}

- (void)setRuleThicknessNumber:(NSNumber *)aNum
{
	// We want to do a delayed perform, but setRuleThickness: does take a CGFloat
	// and not an object. In the past we used NSInvocation to work around that,
	// however that has one major issue: >>This class does not retain the arguments
	// for the contained invocation by default.<< (NSInvocation doc).
	// A perform with delay 0.0 is queued with the run loop, so a dealloc can very
	// well happen before that!
	[self setRuleThickness:[aNum floatValue]];
}

- (void)updateGutterThicknessConstants
{
	maxWidthOfGlyph1 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph     + RULER_MARGIN2));
	maxWidthOfGlyph2 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 2 + RULER_MARGIN2));
	maxWidthOfGlyph3 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 3 + RULER_MARGIN2));
	maxWidthOfGlyph4 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 4 + RULER_MARGIN2));
	maxWidthOfGlyph5 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 5 + RULER_MARGIN2));
	maxWidthOfGlyph6 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 6 + RULER_MARGIN2));
	maxWidthOfGlyph7 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 7 + RULER_MARGIN2));
	maxWidthOfGlyph8 = ceilf(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 8 + RULER_MARGIN2));
}

@end
