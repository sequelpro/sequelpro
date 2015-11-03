//
//  SPIdMenu.m
//  sequel-pro
//
//  Created by Max Lohrmann on 02.11.15.
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

#import "SPIdMenu.h"

@implementation SPIdMenu

@synthesize menuId = _menuId;

-(id)copyWithZone:(NSZone *)zone
{
	SPIdMenu *copy = [super copyWithZone:zone];
	copy->_menuId = [[self menuId] copyWithZone:zone];
	return copy;
}

-(void)dealloc
{
	[self setMenuId:nil];
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	if([aCoder allowsKeyedCoding]) {
		[aCoder encodeObject:[self menuId] forKey:@"SPMenuId"];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if(self = [super initWithCoder:aDecoder]) {
		if([aDecoder allowsKeyedCoding]) {
			[self setMenuId:[aDecoder decodeObjectForKey:@"SPMenuId"]];
		}
	}
	return self;
}

- (NSString *)description
{
	return [[super description] stringByAppendingFormat:@" with menuId=%@",[self menuId]];
}

@end
