//
//  BWAddMiniBottomBarIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWAddSmallBottomBar.h"
#import "BWAddRegularBottomBar.h"
#import "BWAddMiniBottomBar.h"
#import "BWAddSheetBottomBar.h"
#import "NSWindow+BWAdditions.h"

@interface NSWindow (BWBBPrivate)
- (void)setBottomCornerRounded:(BOOL)flag;
@end

@implementation BWAddMiniBottomBar ( BWAddMiniBottomBarIntegration )

- (void)ibDidAddToDesignableDocument:(IBDocument *)document
{
	[super ibDidAddToDesignableDocument:document];
	
	[self performSelector:@selector(addBottomBar) withObject:nil afterDelay:0];
	[self performSelector:@selector(removeOtherBottomBarViewsInDocument:) withObject:document afterDelay:0];
}

- (void)addBottomBar
{
	if ([[self window] isTextured] == NO)
	{
		[[self window] setContentBorderThickness:16 forEdge:NSMinYEdge];
		
		// Private method
		if ([[self window] respondsToSelector:@selector(setBottomCornerRounded:)])
			[[self window] setBottomCornerRounded:NO];		
	}
}

- (void)removeOtherBottomBarViewsInDocument:(IBDocument *)document
{
	NSArray *subviews = [[[self window] contentView] subviews];
	
	int i;
	for (i = 0; i < [subviews count]; i++)
	{
		NSView *view = [subviews objectAtIndex:i];
		if (view != self && ([view isKindOfClass:[BWAddRegularBottomBar class]] || [view isKindOfClass:[BWAddSmallBottomBar class]] || [view isKindOfClass:[BWAddMiniBottomBar class]] || [view isKindOfClass:[BWAddSheetBottomBar class]]))
		{
			[document removeObject:view];
			[view removeFromSuperview];
		}
	}
}

@end
