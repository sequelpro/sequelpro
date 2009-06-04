#import "SPPrintAccessory.h"
#import <WebKit/WebKit.h>

@implementation SPPrintAccessory

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
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
		[[WebPreferences standardPreferences] setShouldPrintBackgrounds:[[defaultsController valueForKeyPath:@"values.PrintBackground"] boolValue] ];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)dealloc
{
	[defaultsController removeObserver:self forKeyPath:@"values.PrintBackground"];
	[super dealloc];
}

@end