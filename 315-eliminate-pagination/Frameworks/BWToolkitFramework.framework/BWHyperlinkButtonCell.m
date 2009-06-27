//
//  BWHyperlinkButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWHyperlinkButtonCell.h"

@interface NSCell (BWPrivate)
- (NSDictionary *)_textAttributes;
@end

@implementation BWHyperlinkButtonCell

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	[attributes setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
	
	return attributes;
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	
}

- (void)setBordered:(BOOL)flag
{
	
}

- (BOOL)isBordered
{
	return YES;
}

@end
