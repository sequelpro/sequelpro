//
//  SPBracketHighlighter.m
//  Sequel Pro
//
//  Created by Piotr Marnik on 07/10/2017.
//  Copyright (c) 2017 Piotr Marnik. All rights reserved.
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

#import "SPBracketHighlighter.h"
#import "SPBrackets.h"

@interface SPBracketHighlighter()

@property NSTextView *textView;

@property NSInteger pos1;
@property NSInteger pos2;


@end

@implementation SPBracketHighlighter


-(instancetype)initWithTextView:(NSTextView *)textView {
	self.textView = textView;
	self.pos1 = NSNotFound;
	self.pos2 = NSNotFound;
	return self;
}

-(void)bracketHighglight:(NSInteger)position inRange:(NSRange)range {
	if (![self isValidPosition:position]) {
		return;
	}

	unichar aChar = [self.text characterAtIndex:position];
	
	[self highlightOff];
	self.pos2 = NSNotFound;
	self.pos1 = NSNotFound;
	if ([SPBrackets isOpeningBracket:aChar] || [SPBrackets isClosingBracket:aChar]) {
		NSInteger nextPos = [SPBrackets findMatchingBracketAtPosition:position inString:self.text];
		if (nextPos != NSNotFound && NSLocationInRange(nextPos, range)) {
			self.pos1 = position;
			self.pos2 = nextPos;
			[self highlightOn];
		}
	}

	
}

-(void)highlightOn {
	if ([self isValidPosition:self.pos1]) {
		[self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor yellowColor] range:NSMakeRange(self.pos1, 1)];
	}
	if ([self isValidPosition:self.pos2]) {
		[self.textView.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor yellowColor] range:NSMakeRange(self.pos2, 1)];
	}
}


-(BOOL)isValidPosition:(NSInteger)position {
	return (position != NSNotFound && position >= 0 && position < (NSInteger) self.text.length);
}

-(void)highlightOff {
	if ([self isValidPosition:self.pos1]) {
		[self.textView.textStorage removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(self.pos1, 1)];
	}
	if ([self isValidPosition:self.pos2]) {
		[self.textView.textStorage removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(self.pos2, 1)];
	}
}

-(NSString*)text {
	return self.textView.string;
}




@end
