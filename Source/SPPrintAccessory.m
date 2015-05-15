//
//  SPPrintAccessory.m
//  sequel-pro
//
//  Created by Marius Ursache.
//  Copyright (c) 2009 Marius Ursache. All rights reserved.
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

#import "SPPrintAccessory.h"

@implementation SPPrintAccessory

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	printWebView = nil;
    
	return [super initWithNibName:@"PrintAccessory" bundle:nibBundleOrNil];
}

- (void)awakeFromNib
{
	[self setView:printAccessoryView];
	
	[defaultsController addObserver:self forKeyPath:@"values.PrintBackground" options:NSKeyValueObservingOptionNew context:@"PrinterSettingsChanged"];
}	

- (NSArray *)localizedSummaryItems
{    
	return @[@{}];
}

- (NSSet *)keyPathsForValuesAffectingPreview
{
	return [NSSet setWithObjects:@"defaultsController.values.PrintBackground", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context isEqualToString:@"PrinterSettingsChanged"]) {
		if (printWebView) 
			[[printWebView preferences] setShouldPrintBackgrounds:[[defaultsController valueForKeyPath:@"values.PrintBackground"] boolValue]];
	} 
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

/**
 * Set the print view that the print accessory controls; set initial preferences based on user defaults.
 */
- (void)setPrintView:(WebView *)theWebView
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
