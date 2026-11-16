#import <XCTest/XCTest.h>

// App classes without exported symbols: looked up at run time
@interface NSObject (SPFavoritesFolderMenuTests)
+ (id)treeNodeWithRepresentedObject:(id)object;
+ (id)groupNodeWithName:(NSString *)name;
+ (id)favoriteNodeWithDictionary:(NSMutableDictionary *)dictionary;
- (void)setIsGroup:(BOOL)isGroup;
- (void)setNodeIsExpanded:(BOOL)expanded;
- (NSMutableArray *)mutableChildNodes;
- (void)loadNib;
- (void)setUpFavoritesOutlineView;
- (void)_reloadFavoritesViewData;
- (void)_restoreOutlineViewStateNode:(id)node;
- (id)selectedFavoriteNode;
- (NSOutlineView *)favoritesOutlineView;
- (NSInteger)menuRow;
- (void)menuNeedsUpdate:(NSMenu *)menu;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
@end

/// The favorites list's right-click menu on a folder: New Folder and New Favorite (SPConnectionController on the real
/// nib, with a favorites tree of its own; the actions, which save the real favorites, are never run).
@interface SPFavoritesFolderMenuTests : XCTestCase
@property (strong) id controller;
@property (strong) NSWindow *window;
@property (strong) id staging;
@property (strong) id beta;
@end

@implementation SPFavoritesFolderMenuTests

- (id)groupNamed:(NSString *)name expanded:(BOOL)expanded
{
	id group = [NSClassFromString(@"SPGroupNode") groupNodeWithName:name];
	[group setNodeIsExpanded:expanded];
	id node = [NSClassFromString(@"SPTreeNode") treeNodeWithRepresentedObject:group];
	[node setIsGroup:YES];
	return node;
}

- (id)favoriteNamed:(NSString *)name
{
	NSMutableDictionary *favorite = [@{@"name": name, @"host": @"db.example.com", @"type": @0, @"id": @(arc4random())} mutableCopy];
	return [NSClassFromString(@"SPTreeNode") treeNodeWithRepresentedObject:[NSClassFromString(@"SPFavoriteNode") favoriteNodeWithDictionary:favorite]];
}

- (void)setUp
{
	// FAVORITES: Beta, Staging (a folder)
	id root = [self groupNamed:@"root" expanded:YES];
	id section = [self groupNamed:@"FAVORITES" expanded:YES];
	[[root mutableChildNodes] addObject:section];
	self.beta = [self favoriteNamed:@"Beta"];
	self.staging = [self groupNamed:@"Staging" expanded:NO];
	[[self.staging mutableChildNodes] addObject:[self favoriteNamed:@"Gamma"]];
	[[section mutableChildNodes] addObjectsFromArray:@[self.beta, self.staging]];

	// Kept alive (the nib's objects outlive a test)
	static NSMutableArray *keepAlive;
	if (!keepAlive) keepAlive = [NSMutableArray array];
	self.controller = [[NSClassFromString(@"SPConnectionController") alloc] init];
	[keepAlive addObject:self.controller];
	[self.controller loadNib];
	[self.controller setValue:root forKey:@"favoritesRoot"];
	[self.controller setValue:[self groupNamed:@"QUICK CONNECT" expanded:NO] forKey:@"quickConnectItem"];
	[self.controller _reloadFavoritesViewData];
	[self.controller setUpFavoritesOutlineView];
	[self.controller _restoreOutlineViewStateNode:root];

	// In a window, for the right-click's coordinates
	self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 900, 650) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	self.window.releasedWhenClosed = NO;
	NSView *view = [self.controller valueForKey:@"connectionView"];
	[view setFrame:[[self.window contentView] bounds]];
	[[self.window contentView] addSubview:view];
	[[self outline] reloadData];
}

- (void)tearDown
{
	[self.window orderOut:nil];
	self.window = nil;
}

- (NSOutlineView *)outline
{
	return [self.controller favoritesOutlineView];
}

/// Right-clicks row (or, for -1, below the last row) and returns the menu as it is about to show.
- (NSMenu *)rightClickRow:(NSInteger)row
{
	NSOutlineView *outline = [self outline];
	NSPoint point;
	if (row >= 0) {
		NSRect rect = [outline rectOfRow:row];
		point = NSMakePoint(NSMidX(rect), NSMidY(rect));
	}
	else {
		NSRect last = [outline rectOfRow:[outline numberOfRows] - 1];
		point = NSMakePoint(NSMidX(last), NSMaxY(last) + 40);
		if (NSHeight([outline frame]) < point.y + 1) [outline setFrameSize:NSMakeSize(NSWidth([outline frame]), point.y + 100)];
	}
	NSPoint inWindow = [outline convertPoint:point toView:nil];
	NSEvent *event = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:inWindow modifierFlags:0 timestamp:0
									windowNumber:[self.window windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
	NSMenu *menu = [outline menuForEvent:event];
	XCTAssertNotNil(menu);
	XCTAssertEqual([menu delegate], self.controller);
	[(id)[menu delegate] menuNeedsUpdate:menu];
	return menu;
}

- (NSInteger)rowOf:(id)node
{
	return [[self outline] rowForItem:node];
}

- (NSArray<NSMenuItem *> *)visibleItems:(NSMenu *)menu
{
	return [[menu itemArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"hidden == NO"]];
}

- (void)testAFolderOffersNewFolderAndNewFavoriteFirst
{
	NSMenu *menu = [self rightClickRow:[self rowOf:self.staging]];
	XCTAssertEqual([self.controller selectedFavoriteNode], self.staging, @"the clicked folder is selected: the new items go in it");

	NSArray *visible = [self visibleItems:menu];
	XCTAssertEqualObjects([visible[0] title], @"New Folder");
	XCTAssertEqualObjects(NSStringFromSelector([visible[0] action]), @"addGroup:");
	XCTAssertEqual([visible[0] target], self.controller);
	XCTAssertEqualObjects([visible[1] title], @"New Favorite");
	XCTAssertEqualObjects(NSStringFromSelector([visible[1] action]), @"addFavorite:");
	XCTAssertEqual([visible[1] target], self.controller);
	XCTAssertTrue([visible[2] isSeparatorItem]);
	XCTAssertEqualObjects([visible[3] title], @"Rename", @"the menu's own items follow");
	XCTAssertTrue([self.controller validateMenuItem:visible[0]]);
	XCTAssertTrue([self.controller validateMenuItem:visible[1]]);
}

- (void)testAFavoriteDoesNotOfferThem
{
	NSMenu *menu = [self rightClickRow:[self rowOf:self.beta]];
	XCTAssertEqual([self.controller selectedFavoriteNode], self.beta);
	NSArray *titles = [[self visibleItems:menu] valueForKey:@"title"];
	XCTAssertFalse([titles containsObject:@"New Folder"]);
	XCTAssertFalse([titles containsObject:@"New Favorite"]);
	XCTAssertEqualObjects(titles.firstObject, @"Rename", @"no separator left on top");

	// Nor empty space, even with the folder still selected from before
	[self rightClickRow:[self rowOf:self.staging]];
	NSMenu *empty = [self rightClickRow:-1];
	XCTAssertEqual([self.controller selectedFavoriteNode], self.staging);
	XCTAssertFalse([[[self visibleItems:empty] valueForKey:@"title"] containsObject:@"New Folder"]);
}

- (void)testTheItemsAreAddedOnce
{
	[self.controller setUpFavoritesOutlineView];
	NSMenu *menu = [[self outline] menu];
	XCTAssertEqual([[[menu itemArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title == 'New Folder'"]] count], 1u);
}

@end
