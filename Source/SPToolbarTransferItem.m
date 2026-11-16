//
//  SPToolbarTransferItem.m
//  sequel-pro
//

#import "SPToolbarTransferItem.h"
#import "SPConstants.h"

NSImage *SPTransferToolbarImage(void)
{
	NSImage *symbol = [NSImage imageWithSystemSymbolName:@"arrow.left.arrow.right" accessibilityDescription:NSLocalizedString(@"Transfer", @"PostgreSQL toolbar: Transfer")];
	symbol = [symbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:17 weight:NSFontWeightRegular]];
	if (!symbol) return nil;

	NSSize symbolSize = [symbol size];
	NSImage *image = [NSImage imageWithSize:NSMakeSize(24, 24) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		NSRect target = NSMakeRect(round((24 - symbolSize.width) / 2), round((24 - symbolSize.height) / 2), symbolSize.width, symbolSize.height);
		[symbol drawInRect:target];
		return YES;
	}];
	[image setTemplate:YES];
	return image;
}

void SPConfigureTransferToolbarItem(NSToolbarItem *item)
{
	[item setLabel:NSLocalizedString(@"Transfer", @"PostgreSQL toolbar: Transfer")];
	[item setPaletteLabel:[item label]];
	[item setToolTip:NSLocalizedString(@"Copy this database, or some of its tables, to another connection", @"tooltip for the Transfer toolbar item")];
	[item setImage:SPTransferToolbarImage()];
}

BOOL SPInsertTransferToolbarItemIfNeeded(NSToolbar *toolbar, NSUserDefaults *defaults)
{
	if (!toolbar || [defaults boolForKey:SPToolbarTransferItemAdded]) return NO;

	NSArray *identifiers = [[toolbar items] valueForKey:@"itemIdentifier"];

	// No items yet: the layout isn't loaded (a toolbar loads it once it is in a window)
	if (![identifiers count]) return NO;

	BOOL inserted = NO;

	if (![identifiers containsObject:SPMainToolbarTransfer]) {
		NSUInteger index = [identifiers indexOfObject:SPMainToolbarCustomQuery];
		if (index == NSNotFound) index = [identifiers indexOfObject:SPMainToolbarUserManager];

		if (index != NSNotFound) {
			index++;
		}
		else {
			index = [identifiers indexOfObject:SPMainToolbarShowConsole];
			if (index == NSNotFound) index = [identifiers count];
		}

		[toolbar insertItemWithItemIdentifier:SPMainToolbarTransfer atIndex:(NSInteger)index];
		inserted = YES;
	}

	[defaults setBool:YES forKey:SPToolbarTransferItemAdded];

	return inserted;
}

BOOL SPMoveTransferToolbarItemAfterQueryIfNeeded(NSToolbar *toolbar, NSUserDefaults *defaults)
{
	if (!toolbar || [defaults boolForKey:SPToolbarTransferItemMovedAfterQuery]) return NO;

	NSArray *identifiers = [[toolbar items] valueForKey:@"itemIdentifier"];

	// No items yet: the layout isn't loaded (a toolbar loads it once it is in a window)
	if (![identifiers count]) return NO;

	BOOL moved = NO;
	NSUInteger transfer = [identifiers indexOfObject:SPMainToolbarTransfer];
	NSUInteger query = [identifiers indexOfObject:SPMainToolbarCustomQuery];

	if (transfer != NSNotFound && query != NSNotFound && transfer != query + 1) {
		[toolbar removeItemAtIndex:(NSInteger)transfer];
		if (transfer < query) query--;
		[toolbar insertItemWithItemIdentifier:SPMainToolbarTransfer atIndex:(NSInteger)(query + 1)];
		moved = YES;
	}

	[defaults setBool:YES forKey:SPToolbarTransferItemMovedAfterQuery];

	return moved;
}

@implementation SPDisabledToolbarItem

- (void)setEnabled:(BOOL)enabled
{
	[super setEnabled:NO];
}

- (BOOL)isEnabled
{
	return NO;
}

- (void)validate
{
	[super setEnabled:NO];
}

@end
