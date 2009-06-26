//
//  BWAddSmallBottomBar.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAddSmallBottomBar.h"
#import "NSWindow-NSTimeMachineSupport.h"

@implementation BWAddSmallBottomBar

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)])
			[self performSelector:@selector(addBottomBar) withObject:nil afterDelay:0];			
	}
	return self;
}

- (void)awakeFromNib
{
	[[self window] setContentBorderThickness:24	forEdge:NSMinYEdge];
}

- (void)drawRect:(NSRect)aRect
{
	if ([self respondsToSelector:@selector(ibDidAddToDesignableDocument:)] && [[self window] contentBorderThicknessForEdge:NSMinYEdge] == 0)
		[self performSelector:@selector(addBottomBar) withObject:nil afterDelay:0];	
	
	if ([[self window] isSheet] && [[self window] respondsToSelector:@selector(setMovable:)])
		[[self window] setMovable:NO];
}

- (NSRect)bounds
{
	return NSMakeRect(-10000,-10000,0,0);
}

@end
