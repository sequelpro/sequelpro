//
//  $Id$
//
//  SPPrintAccessory.m
//  sequel-pro
//
//  Created by Marius Ursache
//  Copyright (c) 2009 Marius Ursache. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPPrintAccessory.h"

@implementation SPPrintAccessory

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	printWebView = nil;
    return [super initWithNibName:@"printAccessory" bundle:nibBundleOrNil];
}

- (void)awakeFromNib
{
	[self setView:printAccessoryView];
	[defaultsController addObserver:self forKeyPath:@"values.PrintBackground" options:NSKeyValueObservingOptionNew context:@"PrinterSettingsChanged"];
}	

- (NSArray *)localizedSummaryItems
{    
	return [NSArray arrayWithObject:[NSDictionary dictionary]];
}

- (NSSet *)keyPathsForValuesAffectingPreview
{
	return [NSSet setWithObjects:
			@"defaultsController.values.PrintBackground",
//			@"defaultsController.values.PrintGrid",
			nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context isEqualToString:@"PrinterSettingsChanged"]) {
		if (printWebView) 
			[[printWebView preferences] setShouldPrintBackgrounds:[[defaultsController valueForKeyPath:@"values.PrintBackground"] boolValue]];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

/*
 * Set the print view that the print accessory controls; set initial 
 * preferences based on user defaults.
 */
- (void) setPrintView:(WebView *)theWebView
{
	printWebView = theWebView;
	[[printWebView preferences] setShouldPrintBackgrounds:[[defaultsController valueForKeyPath:@"values.PrintBackground"] boolValue]];
}

- (void)dealloc
{
	[defaultsController removeObserver:self forKeyPath:@"values.PrintBackground"];
	[super dealloc];
}

@end