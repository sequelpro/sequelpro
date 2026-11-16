//
//  SPMainToolbar.m
//  sequel-pro
//

#import "SPMainToolbar.h"
#import "SPConstants.h"
#import "SPToolbarTransferItem.h"
#import "NSWindow+SPCompactChrome.h"

NSArray *SPMainToolbarAllowedItemIdentifiers(void)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	return @[
		SPMainToolbarDatabaseSelection,
		SPMainToolbarHistoryNavigation,
		SPMainToolbarShowConsole,
		SPMainToolbarClearConsole,
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarCustomQuery,
		SPMainToolbarTableInfo,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers,
		SPMainToolbarUserManager,
		SPMainToolbarTransfer,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier
	];
#pragma clang diagnostic pop
}

NSArray *SPMainToolbarDefaultItemIdentifiers(void)
{
	return @[
		SPMainToolbarDatabaseSelection,
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers,
		SPMainToolbarTableInfo,
		SPMainToolbarCustomQuery,
		SPMainToolbarTransfer,
		SPMainToolbarUserManager,
		NSToolbarFlexibleSpaceItemIdentifier,
		SPMainToolbarHistoryNavigation,
		SPMainToolbarShowConsole
	];
}

NSArray *SPMainToolbarSelectableItemIdentifiers(void)
{
	return @[
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarCustomQuery,
		SPMainToolbarTableInfo,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers
	];
}

/// One person in r: a head over rounded shoulders.
static NSBezierPath *SPToolbarPersonPath(NSRect r)
{
	CGFloat w = NSWidth(r), h = NSHeight(r);
	CGFloat headDiameter = w * 0.46;
	NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMidX(r) - headDiameter / 2, NSMaxY(r) - headDiameter, headDiameter, headDiameter)];

	CGFloat bodyTop = NSMinY(r) + h * 0.50;
	[path moveToPoint:NSMakePoint(NSMinX(r), NSMinY(r))];
	[path lineToPoint:NSMakePoint(NSMinX(r), bodyTop - w * 0.30)];
	[path curveToPoint:NSMakePoint(NSMidX(r), bodyTop) controlPoint1:NSMakePoint(NSMinX(r), bodyTop - w * 0.05) controlPoint2:NSMakePoint(NSMidX(r) - w * 0.30, bodyTop)];
	[path curveToPoint:NSMakePoint(NSMaxX(r), bodyTop - w * 0.30) controlPoint1:NSMakePoint(NSMidX(r) + w * 0.30, bodyTop) controlPoint2:NSMakePoint(NSMaxX(r), bodyTop - w * 0.05)];
	[path lineToPoint:NSMakePoint(NSMaxX(r), NSMinY(r))];
	[path closePath];
	return path;
}

NSImage *SPUsersToolbarImage(void)
{
	NSImage *image = [NSImage imageWithSize:NSMakeSize(24, 24) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		CGFloat scale = NSWidth(dstRect) / 24;
		NSRect back = NSMakeRect(11.5 * scale, 4 * scale, 11 * scale, 16 * scale);
		NSRect front = NSMakeRect(2 * scale, 1.5 * scale, 13 * scale, 19 * scale);

		// The one behind lighter (a template image keeps the alpha: grey, and light grey in Dark Mode)
		[[NSColor colorWithWhite:0 alpha:0.45] setFill];
		[SPToolbarPersonPath(back) fill];

		// A clear gap around the one in front, so the two read apart
		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationClear];
		NSBezierPath *gap = SPToolbarPersonPath(front);
		[gap setLineWidth:2.5 * scale];
		[gap stroke];
		[gap fill];
		[NSGraphicsContext restoreGraphicsState];

		[[NSColor blackColor] setFill];
		[SPToolbarPersonPath(front) fill];
		return YES;
	}];
	// Black, as Transfer's symbol, and white in Dark Mode
	[image setTemplate:YES];
	return image;
}

NSToolbarItem *SPCreateMainToolbarItem(NSString *identifier)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
	NSImage *image = nil;

	if ([identifier isEqualToString:SPMainToolbarDatabaseSelection]) {
		[item setLabel:NSLocalizedString(@"Select Database", @"toolbar item for selecting a db")];
		[item setPaletteLabel:[item label]];
	}
	else if ([identifier isEqualToString:SPMainToolbarHistoryNavigation]) {
		[item setLabel:NSLocalizedString(@"Table History", @"toolbar item for navigation history")];
		[item setPaletteLabel:[item label]];
	}
	else if ([identifier isEqualToString:SPMainToolbarShowConsole]) {
		[item setPaletteLabel:NSLocalizedString(@"Show Console", @"show console")];
		[item setToolTip:NSLocalizedString(@"Show the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for show console")];
		[item setLabel:NSLocalizedString(@"Console", @"Console")];
		// The original artwork, drawn as Table Info or Query are (not in a grey capsule)
		[item setBordered:NO];
		image = [NSImage imageNamed:@"hideconsole"];
	}
	else if ([identifier isEqualToString:SPMainToolbarClearConsole]) {
		[item setLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		[item setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		[item setToolTip:NSLocalizedString(@"Clear the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for clear console")];
		image = [NSImage imageNamed:@"clearconsole"];
	}
	else if ([identifier isEqualToString:SPMainToolbarTableStructure]) {
		[item setLabel:NSLocalizedString(@"Structure", @"toolbar item label for switching to the Table Structure tab")];
		[item setPaletteLabel:NSLocalizedString(@"Edit Table Structure", @"toolbar item label for switching to the Table Structure tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Table Structure tab", @"tooltip for toolbar item for switching to the Table Structure tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-structure"];
	}
	else if ([identifier isEqualToString:SPMainToolbarTableContent]) {
		[item setLabel:NSLocalizedString(@"Content", @"toolbar item label for switching to the Table Content tab")];
		[item setPaletteLabel:NSLocalizedString(@"Browse & Edit Table Content", @"toolbar item label for switching to the Table Content tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Table Content tab", @"tooltip for toolbar item for switching to the Table Content tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-browse"];
	}
	else if ([identifier isEqualToString:SPMainToolbarCustomQuery]) {
		[item setLabel:NSLocalizedString(@"Query", @"toolbar item label for switching to the Run Query tab")];
		[item setPaletteLabel:NSLocalizedString(@"Run Custom Query", @"toolbar item label for switching to the Run Query tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Run Query tab", @"tooltip for toolbar item for switching to the Run Query tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-sql"];
	}
	else if ([identifier isEqualToString:SPMainToolbarTableInfo]) {
		[item setLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		[item setPaletteLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Table Info tab", @"tooltip for toolbar item for switching to the Table Info tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-table-info"];
	}
	else if ([identifier isEqualToString:SPMainToolbarTableRelations]) {
		[item setLabel:NSLocalizedString(@"Relations", @"toolbar item label for switching to the Table Relations tab")];
		[item setPaletteLabel:NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Table Relations tab", @"tooltip for toolbar item for switching to the Table Relations tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-table-relations"];
	}
	else if ([identifier isEqualToString:SPMainToolbarTableTriggers]) {
		[item setLabel:NSLocalizedString(@"Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		[item setPaletteLabel:NSLocalizedString(@"Table Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the Table Triggers tab", @"tooltip for toolbar item for switching to the Table Triggers tab")];
		image = [NSImage imageNamed:@"toolbar-switch-to-table-triggers"];
	}
	else if ([identifier isEqualToString:SPMainToolbarUserManager]) {
		[item setLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		[item setPaletteLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		[item setToolTip:NSLocalizedString(@"Switch to the User Manager tab", @"tooltip for toolbar item for switching to the User Manager tab")];
		// Drawn as the other items are (not in a bordered button, which AppKit would give an image item with an action)
		image = SPUsersToolbarImage();
		[item setBordered:NO];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[item setMinSize:NSMakeSize(28, 28)];
		[item setMaxSize:NSMakeSize(28, 28)];
#pragma clang diagnostic pop
	}
	else if ([identifier isEqualToString:SPMainToolbarTransfer]) {
		// MySQL → MySQL Transfer (SPDatabaseDocument -showTransfer:; enabled by its validation)
		SPConfigureTransferToolbarItem(item);
		image = [item image];
	}
	else {
		return nil;
	}

	if (image) [item setImage:SPCompactToolbarImage(image)];

	return item;
}

NSPopUpButton *SPCreateDatabaseToolbarPopUpButton(void)
{
	NSPopUpButton *popup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 3, 200, 26) pullsDown:NO] autorelease];
	[popup setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin];
	[popup setBezelStyle:NSBezelStyleTexturedRounded];
	[popup setFont:[NSFont titleBarFontOfSize:12]];

	NSPopUpButtonCell *cell = [popup cell];
	[cell setAlignment:NSTextAlignmentCenter];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setHighlightsBy:NSPushInCellMask | NSChangeGrayCellMask | NSChangeBackgroundCellMask];

	return popup;
}

NSSegmentedControl *SPCreateHistoryToolbarControl(void)
{
	NSSegmentedControl *control = [[[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0, 3, 57, 25)] autorelease];
	[control setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
	[control setSegmentCount:2];
	[control setSegmentStyle:NSSegmentStyleTexturedSquare];
	[control setTrackingMode:NSSegmentSwitchTrackingMomentary];
	[control setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];

	NSArray *images = @[NSImageNameGoLeftTemplate, NSImageNameGoRightTemplate];
	NSArray *toolTips = @[NSLocalizedString(@"Back", @"history back"), NSLocalizedString(@"Forward", @"history forward")];
	for (NSInteger i = 0; i < 2; i++) {
		[control setImage:[NSImage imageNamed:images[i]] forSegment:i];
		[control setWidth:27 forSegment:i];
		[control setToolTip:toolTips[i] forSegment:i];
		[control setEnabled:NO forSegment:i];
		[[control cell] setTag:i forSegment:i];
	}
	[control sizeToFit];

	return control;
}
