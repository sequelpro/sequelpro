//
//  BWInsetTextField.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWInsetTextField.h"

@implementation BWInsetTextField

- (id)initWithCoder:(NSCoder *)decoder;
{
	self = [super initWithCoder:decoder];
	
	if (self)
	{
		[[self cell] setBackgroundStyle:NSBackgroundStyleRaised];
	}
	
	return self;
}

@end
