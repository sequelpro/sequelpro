//
//  SPPopUpButtonCell.m
//  sequel-pro
//
//  Created by Max Lohrmann on 10.11.15.
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

#import "SPPopUpButtonCell.h"

@implementation SPPopUpButtonCell

- (id)objectValue
{
	NSInteger n = [[super objectValue] integerValue];
	
	// this method can be called for invalid selections, which return -1, which fails with itemAtIndex:
	if(n < 0 || n >= [self numberOfItems]) return nil;
	
	return [[self itemAtIndex:n] representedObject];
}

- (void)setObjectValue:(id)objectValue
{
	NSInteger n = [self indexOfItemWithRepresentedObject:objectValue];
	[super setObjectValue:@(n)];
}

@end
