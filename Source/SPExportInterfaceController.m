//
//  $Id$
//
//  SPExportInterfaceController.m
//  Sequel Pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 31, 2012
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPExportInterfaceController.h"

@implementation SPExportController (SPExportInterfaceController)

/**
 * Resizes the export window's height by the supplied delta, while retaining the position of 
 * all interface controls to accommodate the custom filename view.
 *
 * @param delta The height delta for which the height should be adjusted for.
 */
- (void)_resizeWindowForCustomFilenameViewByHeightDelta:(NSInteger)delta
{
	NSUInteger popUpMask              = [exportInputPopUpButton autoresizingMask];
	NSUInteger fileCheckMask          = [exportFilePerTableCheck autoresizingMask];
	NSUInteger scrollMask             = [exportTablelistScrollView autoresizingMask];
	NSUInteger buttonBarMask          = [exportTableListButtonBar autoresizingMask];
	NSUInteger buttonMask             = [exportCustomFilenameViewButton autoresizingMask];
	NSUInteger textFieldMask          = [exportCustomFilenameViewLabelButton autoresizingMask];
	NSUInteger customFilenameViewMask = [exportCustomFilenameView autoresizingMask];
	NSUInteger tabBarMask             = [exportOptionsTabBar autoresizingMask];
	
	NSRect frame = [[self window] frame];
	
	if (frame.size.height > 600 && delta > heightOffset1) {
		frame.origin.y += [exportCustomFilenameView frame].size.height;
		frame.size.height -= [exportCustomFilenameView frame].size.height;
		
		[[self window] setFrame:frame display:YES animate:YES];
	}
	
	[exportInputPopUpButton setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportFilePerTableCheck setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportTablelistScrollView setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportTableListButtonBar setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportOptionsTabBar setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportCustomFilenameViewButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportCustomFilenameViewLabelButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportCustomFilenameView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	
	NSInteger newMinHeight = (windowMinHeigth - heightOffset1 + delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth - heightOffset1 + delta;
	
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	
	frame.origin.y += heightOffset1;
	frame.size.height -= heightOffset1;
	
	heightOffset1 = delta;
	
	frame.origin.y -= heightOffset1;
	frame.size.height += heightOffset1;
	
	[[self window] setFrame:frame display:YES animate:YES];
	
	[exportInputPopUpButton setAutoresizingMask:popUpMask];
	[exportFilePerTableCheck setAutoresizingMask:fileCheckMask];
	[exportTablelistScrollView setAutoresizingMask:scrollMask];
	[exportTableListButtonBar setAutoresizingMask:buttonBarMask];
	[exportCustomFilenameViewButton setAutoresizingMask:buttonMask];
	[exportCustomFilenameViewLabelButton setAutoresizingMask:textFieldMask];
	[exportCustomFilenameView setAutoresizingMask:customFilenameViewMask];
	[exportOptionsTabBar setAutoresizingMask:tabBarMask];
}

/**
 * Resizes the export window's height by the supplied delta, while retaining the position of 
 * all interface controls to accommodate the advanced options view.
 *
 * @param delta The height delta for which the height should be adjusted for.
 */
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta
{
	NSUInteger scrollMask        = [exportTablelistScrollView autoresizingMask];
	NSUInteger buttonBarMask     = [exportTableListButtonBar autoresizingMask];
	NSUInteger tabBarMask        = [exportTypeTabBar autoresizingMask];
	NSUInteger optionsTabBarMask = [exportOptionsTabBar autoresizingMask];
	NSUInteger buttonMask        = [exportAdvancedOptionsViewButton autoresizingMask];
	NSUInteger textFieldMask     = [exportAdvancedOptionsViewLabelButton autoresizingMask];
	NSUInteger advancedViewMask  = [exportAdvancedOptionsView autoresizingMask];
	
	NSRect frame = [[self window] frame];
	
	if (frame.size.height > 600 && delta > heightOffset2) {
		frame.origin.y += [exportAdvancedOptionsView frame].size.height;
		frame.size.height -= [exportAdvancedOptionsView frame].size.height;
		
		[[self window] setFrame:frame display:YES animate:YES];
	}
	
	[exportTablelistScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportTableListButtonBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportTypeTabBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportOptionsTabBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsViewButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsViewLabelButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	
	NSInteger newMinHeight = (windowMinHeigth - heightOffset2 + delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth - heightOffset2 + delta;
	
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	
	frame.origin.y += heightOffset2;
	frame.size.height -= heightOffset2;
	
	heightOffset2 = delta;
	
	frame.origin.y -= heightOffset2;
	frame.size.height += heightOffset2;
	
	[[self window] setFrame:frame display:YES animate:YES];
	
	[exportTablelistScrollView setAutoresizingMask:scrollMask];
	[exportTableListButtonBar setAutoresizingMask:buttonBarMask];
	[exportTypeTabBar setAutoresizingMask:tabBarMask];
	[exportOptionsTabBar setAutoresizingMask:optionsTabBarMask];
	[exportAdvancedOptionsViewButton setAutoresizingMask:buttonMask];
	[exportAdvancedOptionsViewLabelButton setAutoresizingMask:textFieldMask];
	[exportAdvancedOptionsView setAutoresizingMask:advancedViewMask];
}

@end
