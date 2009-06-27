//
//  BWTransparentTextFieldCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentTextFieldCell.h"
#import "NSApplication+BWAdditions.h"

static NSShadow *textShadow;

@interface NSCell (BWTTFCPrivate)
- (NSDictionary *)_textAttributes;
@end

@implementation BWTransparentTextFieldCell

+ (void)initialize
{
	textShadow = [[NSShadow alloc] init];
	[textShadow setShadowOffset:NSMakeSize(0,-1)];	
}

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	
	if ([NSApplication isOnLeopard])
		[attributes setObject:[NSFont boldSystemFontOfSize:11] forKey:NSFontAttributeName];
	else
		[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
		
	[attributes setObject:textShadow forKey:NSShadowAttributeName];
	
	return attributes;
}

@end
