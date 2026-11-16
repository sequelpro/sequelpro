#import <XCTest/XCTest.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "../Source/SPLoadingSheet.h"
#import "../Source/SPWindowController.h"
#import "../Source/Postgres/SPPostgresUsersController.h"
#import "../Source/Postgres/SPPostgresRoles.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"
#import "../Source/Postgres/SPPostgresPrivileges.h"
#import "../Source/Postgres/SPPostgresConsoleLogger.h"

static NSString * const SPUsersTestToolbarUsers = @"SwitchToUserManagerToolbarItemIdentifier";

/// The Users sheet (SPPostgresUsersController) and its wiring into SPPostgresDocument, on PG 12 and 18.
@interface SPPostgresUsersControllerTests : XCTestCase
@property (strong) NSWindow *window;
@property (strong) NSMutableArray<SPPostgresUsersController *> *controllers;
@property (strong) NSMutableArray<NSNumber *> *completions;
@property (strong) NSMutableArray<NSAlert *> *alerts;
@property (strong) NSMutableArray<PGPostgresConnection *> *openConnections;
// Document tests
@property (strong) SPWindowController *windowController;
@property (strong) SPPostgresDocument *document;
/// Set by a test that drops a catalog fixture object: tearDown reloads the fixture.
@property (assign) BOOL reloadCatalogFixture;
@end

@implementation SPPostgresUsersControllerTests

- (void)setUp
{
	self.continueAfterFailure = NO;
	self.controllers = [NSMutableArray array];
	self.completions = [NSMutableArray array];
	self.alerts = [NSMutableArray array];
	self.openConnections = [NSMutableArray array];
	self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 900, 700) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	self.window.releasedWhenClosed = NO;

	for (NSNumber *port in [SPPostgresTestServers ports]) {
		[SPPostgresTestServers dropTestRolesOnPort:port.unsignedIntegerValue];
		PGPostgresConnection *connection = [self connectOn:port];
		[self run:@"DROP TABLE IF EXISTS public.sp_t4_owned" on:connection];
		[self run:@"DROP TABLE IF EXISTS public.sp_t4_later" on:connection];
		[self run:@"CREATE ROLE sp_t4_group NOLOGIN" on:connection];
		[self run:@"CREATE ROLE sp_t4_login LOGIN PASSWORD 'Pw-sp_t4!' IN ROLE sp_t4_group" on:connection];
		[self run:@"CREATE ROLE sp_t4_owner LOGIN" on:connection];
		[self run:@"CREATE ROLE sp_t4_priv LOGIN" on:connection];
		[self run:@"CREATE TABLE public.sp_t4_owned (id int)" on:connection];
		[self run:@"ALTER TABLE public.sp_t4_owned OWNER TO sp_t4_owner" on:connection];
	}
}

- (void)tearDown
{
	for (SPPostgresUsersController *controller in self.controllers) [controller endSheet];
	if (self.window.attachedSheet) [self.window endSheet:self.window.attachedSheet];
	[self.window orderOut:nil];
	self.controllers = nil;

	if (self.windowController) {
		NSWindow *window = [self.windowController window];
		if (window.attachedSheet) [window endSheet:window.attachedSheet];
		NSTabView *tabView = [self.windowController valueForKey:@"tabView"];
		for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
		[window orderOut:nil];
		self.document = nil;
		self.windowController = nil;
	}

	for (PGPostgresConnection *connection in self.openConnections) [connection disconnect];
	self.openConnections = nil;
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue];
		[connection execute:@"DROP TABLE IF EXISTS public.sp_t4_owned"];
		[connection execute:@"DROP TABLE IF EXISTS public.sp_t4_later"];
		[connection disconnect];
		[SPPostgresTestServers dropTestRolesOnPort:port.unsignedIntegerValue];
		if (self.reloadCatalogFixture) [SPPostgresTestServers loadFixtureNamed:@"catalog" onPort:port.unsignedIntegerValue];
	}
	[super tearDown];
}

#pragma mark - Helpers

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return condition();
}

- (PGPostgresConnection *)connectOn:(NSNumber *)port
{
	PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue];
	XCTAssertNotNil(connection);
	[self.openConnections addObject:connection];
	return connection;
}

- (void)run:(NSString *)sql on:(PGPostgresConnection *)connection
{
	XCTAssertNotNil([connection execute:sql], @"%@: %@", sql, connection.lastError.errorPrimaryMessage);
}

- (NSString *)value:(NSString *)sql on:(PGPostgresConnection *)connection
{
	PGPostgresResult *result = [connection execute:sql];
	XCTAssertNotNil(result, @"%@: %@", sql, connection.lastError.errorPrimaryMessage);
	if (!result.numberOfRows) return nil;
	id value = [result textValueAtRow:0 column:0];
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

/// A provider handing out fresh test-server connections on port (synchronously).
- (void (^)(NSString *, void (^)(PGPostgresConnection *, NSError *)))providerOn:(NSNumber *)port
{
	return ^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:database];
		completion(connection, connection ? nil : [NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey: @"no connection"}]);
	};
}

/// The sheet, begun on the test window for pgkit_test on port; its completion's value lands in self.completions.
- (SPPostgresUsersController *)beginOn:(NSNumber *)port
{
	SPPostgresUsersController *controller = [[SPPostgresUsersController alloc] initWithDatabase:@"pgkit_test" connectionProvider:[self providerOn:port]];
	__weak SPPostgresUsersControllerTests *weakSelf = self;
	controller.alertPresenter = ^(NSAlert *alert) { [weakSelf.alerts addObject:alert]; };
	[self.controllers addObject:controller];
	[controller beginSheetForWindow:self.window completion:^(BOOL applied) { [weakSelf.completions addObject:@(applied)]; }];
	XCTAssertNotNil(controller.sheet, @"port %@: %@", port, controller.lastErrorMessage);
	XCTAssertEqual(self.window.attachedSheet, controller.sheet, @"port %@", port);
	return controller;
}

- (void)waitForEndOf:(SPPostgresUsersController *)controller
{
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil; } timeout:5]);
	XCTAssertEqual(self.completions.count, 1u);
}

- (NSInteger)rowOf:(NSString *)name in:(SPPostgresUsersController *)controller
{
	NSUInteger index = [[controller.editedRoles valueForKey:@"name"] indexOfObject:name];
	return index == NSNotFound ? -1 : (NSInteger)index;
}

- (NSTableCellView *)cellOf:(NSString *)name in:(SPPostgresUsersController *)controller
{
	NSInteger row = [self rowOf:name in:controller];
	XCTAssertGreaterThanOrEqual(row, 0, @"%@", name);
	return (NSTableCellView *)[controller tableView:controller.rolesTable viewForTableColumn:controller.rolesTable.tableColumns.firstObject row:row];
}

- (NSTextField *)subtitleIn:(NSView *)cell
{
	for (NSView *view in cell.subviews) if ([view.identifier isEqualToString:@"subtitle"]) return (NSTextField *)view;
	return nil;
}

- (void)select:(NSString *)name in:(SPPostgresUsersController *)controller
{
	XCTAssertTrue([controller selectRoleNamed:name], @"%@", name);
	XCTAssertEqualObjects(controller.selectedRole.name, name);
	XCTAssertEqualObjects(controller.nameField.stringValue, name);
}

/// The role's attributes as "login inherit super createdb createrole replication bypassrls connlimit validuntil".
- (NSString *)attributesOf:(NSString *)role on:(PGPostgresConnection *)connection
{
	return [self value:[NSString stringWithFormat:@"SELECT concat_ws(' ', rolcanlogin, rolinherit, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls, rolconnlimit, coalesce(nullif(rolvaliduntil, 'infinity')::text, 'never')) FROM pg_catalog.pg_roles WHERE rolname = '%@'", role] on:connection];
}

- (NSArray<NSString *> *)groupsOf:(NSString *)role on:(PGPostgresConnection *)connection
{
	PGPostgresResult *result = [connection execute:[NSString stringWithFormat:@"SELECT g.rolname::text FROM pg_catalog.pg_auth_members a JOIN pg_catalog.pg_roles m ON m.oid = a.member JOIN pg_catalog.pg_roles g ON g.oid = a.roleid WHERE m.rolname = '%@' ORDER BY 1", role]];
	NSMutableArray *names = [NSMutableArray array];
	for (unsigned long long row = 0; row < result.numberOfRows; row++) [names addObject:[result textValueAtRow:row column:0]];
	return names;
}

#pragma mark - The sheet

- (void)testSheetListsRolesAndShowsGeneral
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		XCTAssertTrue(NSEqualSizes(controller.sheet.contentView.frame.size, NSMakeSize(760, 520)), @"%@", NSStringFromSize(controller.sheet.contentView.frame.size));
		XCTAssertTrue(NSEqualSizes(controller.sheet.contentMinSize, NSMakeSize(680, 460)));
		XCTAssertTrue(controller.sheet.styleMask & NSWindowStyleMaskResizable);
		XCTAssertEqualObjects([controller.tabView.tabViewItems valueForKey:@"label"], (@[@"General", @"Membership", @"Privileges"]));

		NSArray *names = [controller.editedRoles valueForKey:@"name"];
		XCTAssertTrue([names containsObject:@"sp_t4_login"]);
		XCTAssertTrue([names containsObject:@"sp_t4_group"]);
		for (NSString *name in names) XCTAssertFalse([name hasPrefix:@"pg_"], @"predefined roles are hidden: %@", name);

		NSTableCellView *login = [self cellOf:@"sp_t4_login" in:controller];
		XCTAssertEqualObjects(login.textField.stringValue, @"sp_t4_login");
		XCTAssertEqualObjects([self subtitleIn:login].stringValue ?: @"", @"");
		XCTAssertEqualObjects(login.imageView.image.name, NSImageNameUser);
		NSTableCellView *group = [self cellOf:@"sp_t4_group" in:controller];
		XCTAssertEqualObjects([self subtitleIn:group].stringValue, @"group, no login");
		XCTAssertEqualObjects(group.imageView.image.name, NSImageNameUserGroup);
		XCTAssertEqualObjects([self subtitleIn:[self cellOf:@"pgkit_test" in:controller]].stringValue, @"superuser");

		[self select:@"sp_t4_login" in:controller];
		XCTAssertEqualObjects(controller.passwordField.stringValue, @"", @"the password is never shown");
		XCTAssertEqual(controller.loginCheckbox.state, NSControlStateValueOn);
		XCTAssertEqual(controller.inheritCheckbox.state, NSControlStateValueOn);
		XCTAssertEqual(controller.superuserCheckbox.state, NSControlStateValueOff);
		XCTAssertEqual(controller.createDBCheckbox.state, NSControlStateValueOff);
		XCTAssertEqual(controller.clearPasswordCheckbox.state, NSControlStateValueOff);
		XCTAssertEqual(controller.validUntilCheckbox.state, NSControlStateValueOff);
		XCTAssertFalse(controller.validUntilPicker.isEnabled);
		XCTAssertEqualObjects(controller.connectionLimitField.stringValue, @"");
		XCTAssertEqualObjects(controller.connectionLimitField.placeholderString, @"-1 = unlimited");
		XCTAssertEqualObjects(controller.passwordField.placeholderString, @"unchanged");
		XCTAssertEqualObjects(controller.bypassRLSCheckbox.title, @"Bypass row-level security");
		XCTAssertEqual(controller.selectedRole.hasMD5Password, port.unsignedIntegerValue == 55412, @"PG12 stores md5, PG18 scram");

		// Membership: sp_t4_group ticked; predefined roles offered
		NSUInteger groupRow = [controller.memberOfCandidates indexOfObject:@"sp_t4_group"];
		XCTAssertNotEqual(groupRow, NSNotFound);
		XCTAssertTrue([controller.memberOfCandidates containsObject:@"pg_monitor"]);
		XCTAssertFalse([controller.memberOfCandidates containsObject:@"sp_t4_login"], @"not itself");
		NSTableColumn *member = [controller.memberOfTable tableColumnWithIdentifier:@"member"];
		XCTAssertEqualObjects([controller tableView:controller.memberOfTable objectValueForTableColumn:member row:(NSInteger)groupRow], @YES);
		XCTAssertFalse(controller.applyButton.isEnabled, @"nothing changed");
		XCTAssertEqual(controller.sheet.defaultButtonCell, controller.applyButton.cell, @"Apply is the default button");

		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
	}
}

- (void)testAddEditApplyCreatesRole
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		NSUInteger count = controller.editedRoles.count;
		[controller addRole:nil];
		XCTAssertEqual(controller.editedRoles.count, count + 1);
		XCTAssertNil(controller.selectedRole.originalName);
		controller.nameField.stringValue = @"sp_t4_ui";
		controller.connectionLimitField.stringValue = @"4";
		[controller.createDBCheckbox performClick:nil];
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES);
		XCTAssertNil(controller.lastErrorMessage);

		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertEqualObjects([self attributesOf:@"sp_t4_ui" on:check], @"f t f t f f f 4 never");
		[self.completions removeAllObjects];
	}
}

- (void)testCancelDiscardsEverything
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_login" in:controller];
		controller.nameField.stringValue = @"sp_t4_renamed";
		[controller.superuserCheckbox performClick:nil];
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller cancel:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @NO);

		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertEqualObjects([self attributesOf:@"sp_t4_login" on:check], @"t t f f f f f -1 never");
		XCTAssertNil([self attributesOf:@"sp_t4_renamed" on:check]);
		[self.completions removeAllObjects];
	}
}

- (void)testDuplicateCopiesAttributesAndMemberships
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *check = [self connectOn:port];
		[self run:@"ALTER ROLE sp_t4_login CREATEDB CONNECTION LIMIT 3 VALID UNTIL '2031-02-03 04:05:06+00'" on:check];

		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_login" in:controller];
		[controller duplicateRole:nil];
		XCTAssertEqualObjects(controller.selectedRole.name, @"sp_t4_login_copy");
		XCTAssertEqualObjects(controller.nameField.stringValue, @"sp_t4_login_copy");
		XCTAssertNil(controller.selectedRole.originalName);
		XCTAssertEqualObjects(controller.selectedRole.memberOf, @{@"sp_t4_group": @NO});
		XCTAssertEqualObjects(controller.selectedRole.members, @{});
		XCTAssertFalse(controller.selectedRole.hasMD5Password);
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES);

		NSString *expected = [self attributesOf:@"sp_t4_login" on:check];
		XCTAssertTrue([expected hasPrefix:@"t t f t f f f 3 2031-02-03"], @"%@", expected);
		XCTAssertEqualObjects([self attributesOf:@"sp_t4_login_copy" on:check], expected);
		XCTAssertEqualObjects([self groupsOf:@"sp_t4_login_copy" on:check], @[@"sp_t4_group"]);
		XCTAssertEqualObjects([self value:@"SELECT (rolpassword IS NULL)::text FROM pg_catalog.pg_authid WHERE rolname = 'sp_t4_login_copy'" on:check], @"true", @"no password copied");

		// A second duplicate gets _copy2
		controller = [self beginOn:port];
		[self select:@"sp_t4_login" in:controller];
		[controller duplicateRole:nil];
		XCTAssertEqualObjects(controller.selectedRole.name, @"sp_t4_login_copy2");
		[controller cancel:nil];
		[self.completions removeAllObjects];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil; } timeout:5]);
		[self.completions removeAllObjects];
	}
}

- (void)testRemoveMarksThenApplyDrops
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];

		// − on a new role just removes it
		NSUInteger count = controller.editedRoles.count;
		[controller addRole:nil];
		[controller removeRole:nil];
		XCTAssertEqual(controller.editedRoles.count, count);
		XCTAssertFalse(controller.applyButton.isEnabled);

		[self select:@"sp_t4_group" in:controller];
		XCTAssertTrue(controller.removeButton.isEnabled);
		[controller removeRole:nil];
		XCTAssertTrue(controller.selectedRole.markedForDeletion);
		XCTAssertEqual(controller.editedRoles.count, count, @"still listed until Apply");
		NSTableCellView *cell = [self cellOf:@"sp_t4_group" in:controller];
		NSNumber *strike = [cell.textField.attributedStringValue attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:NULL];
		XCTAssertEqual(strike.integerValue, NSUnderlineStyleSingle, @"marked for deletion: struck through");
		XCTAssertFalse(controller.nameField.isEnabled, @"a role marked for deletion isn't edited");
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES);
		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertNil([self attributesOf:@"sp_t4_group" on:check]);
		XCTAssertNotNil([self attributesOf:@"sp_t4_login" on:check]);
		[self.completions removeAllObjects];
	}
}

- (void)testRemoveDisabledForSessionRole
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"pgkit_test" in:controller];
		XCTAssertFalse(controller.removeButton.isEnabled, @"the connected role can't be removed");
		[controller removeRole:nil];
		XCTAssertFalse(controller.selectedRole.markedForDeletion);
		[self select:@"sp_t4_login" in:controller];
		XCTAssertTrue(controller.removeButton.isEnabled);
		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
	}
}

- (void)testApplyFailureKeepsSheetAndEdits
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_owner" in:controller];
		[controller removeRole:nil];
		[self select:@"sp_t4_login" in:controller];
		[controller.createRoleCheckbox performClick:nil];

		[controller apply:nil];
		XCTAssertTrue([controller.lastErrorMessage containsString:@"\"sp_t4_owner\" cannot be dropped"], @"%@", controller.lastErrorMessage);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"owner of table sp_t4_owned"], @"the DETAIL list: %@", controller.lastErrorMessage);
		XCTAssertEqual(self.alerts.count, 1u, @"the error is shown");
		XCTAssertTrue([self.alerts.firstObject.informativeText containsString:@"cannot be dropped"], @"%@", self.alerts.firstObject.informativeText);
		[self spinUntil:^BOOL{ return NO; } timeout:0.2];
		XCTAssertEqual(self.window.attachedSheet, controller.sheet, @"the sheet stays");
		XCTAssertEqual(self.completions.count, 0u);

		// Both edits still pending, nothing applied
		SPPostgresRole *owner = controller.editedRoles[(NSUInteger)[self rowOf:@"sp_t4_owner" in:controller]];
		SPPostgresRole *login = controller.editedRoles[(NSUInteger)[self rowOf:@"sp_t4_login" in:controller]];
		XCTAssertTrue(owner.markedForDeletion);
		XCTAssertTrue(login.createRole);
		XCTAssertTrue(controller.applyButton.isEnabled);
		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertNotNil([self attributesOf:@"sp_t4_owner" on:check]);
		XCTAssertEqualObjects([self attributesOf:@"sp_t4_login" on:check], @"t t f f f f f -1 never");

		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
		[self.alerts removeAllObjects];
	}
}

/// R2: on PG12 (password_encryption md5) a rename silently clears an MD5 password, so the sheet asks for a new one.
- (void)testRenameMD5LoginNeedsNewPassword
{
	NSNumber *port = @55412;
	PGPostgresConnection *raw = [self connectOn:port];
	[self run:@"SET password_encryption = 'md5'" on:raw];
	[self run:@"ALTER ROLE sp_t4_login PASSWORD 'Old-pw-1'" on:raw];
	XCTAssertEqualObjects([self value:@"SELECT left(rolpassword, 3) FROM pg_catalog.pg_authid WHERE rolname = 'sp_t4_login'" on:raw], @"md5");

	SPPostgresUsersController *controller = [self beginOn:port];
	[self select:@"sp_t4_login" in:controller];
	XCTAssertTrue(controller.selectedRole.hasMD5Password);
	controller.nameField.stringValue = @"sp_t4_login2";

	[controller apply:nil];
	XCTAssertEqualObjects(controller.lastErrorMessage, @"Renaming “sp_t4_login” clears its MD5 password. Enter a new password for “sp_t4_login2” too.");
	XCTAssertEqual(self.alerts.count, 1u);
	XCTAssertEqual(self.window.attachedSheet, controller.sheet);
	XCTAssertEqual(self.completions.count, 0u);
	XCTAssertNotNil([self attributesOf:@"sp_t4_login" on:raw], @"nothing sent");
	XCTAssertNil([self attributesOf:@"sp_t4_login2" on:raw]);

	// With a new password it goes ahead
	controller.passwordField.stringValue = @"New-pw-2";
	[controller apply:nil];
	[self waitForEndOf:controller];
	XCTAssertEqualObjects(self.completions.firstObject, @YES);
	XCTAssertNil([self attributesOf:@"sp_t4_login" on:raw]);
	XCTAssertEqualObjects([self value:@"SELECT (rolpassword IS NOT NULL)::text FROM pg_catalog.pg_authid WHERE rolname = 'sp_t4_login2'" on:raw], @"true");
}

#pragma mark - Privileges

/// The grid row index of the object of kind named name, or -1.
- (NSInteger)privilegeRowOf:(NSString *)kind named:(NSString *)name in:(SPPostgresUsersController *)controller
{
	NSArray<SPPostgresPrivilegeObject *> *rows = [controller privilegeRowsShown];
	for (NSUInteger i = 0; i < rows.count; i++) {
		if ([rows[i].kind isEqualToString:kind] && [rows[i].name isEqualToString:name]) return (NSInteger)i;
	}
	return -1;
}

- (id)privilege:(NSString *)privilege of:(NSString *)kind named:(NSString *)name in:(SPPostgresUsersController *)controller
{
	NSInteger row = [self privilegeRowOf:kind named:name in:controller];
	XCTAssertGreaterThanOrEqual(row, 0, @"%@ %@", kind, name);
	NSTableColumn *column = [controller.privilegesTable tableColumnWithIdentifier:privilege];
	XCTAssertNotNil(column, @"%@", privilege);
	return [controller.privilegesTable.dataSource tableView:controller.privilegesTable objectValueForTableColumn:column row:row];
}

/// Ticks (or unticks) a cell of the grid, as a click would.
- (void)set:(BOOL)value privilege:(NSString *)privilege of:(NSString *)kind named:(NSString *)name in:(SPPostgresUsersController *)controller
{
	NSInteger row = [self privilegeRowOf:kind named:name in:controller];
	XCTAssertGreaterThanOrEqual(row, 0, @"%@ %@", kind, name);
	NSTableColumn *column = [controller.privilegesTable tableColumnWithIdentifier:privilege];
	XCTAssertTrue([controller.privilegesTable.delegate tableView:controller.privilegesTable shouldEditTableColumn:column row:row], @"%@ on %@ %@", privilege, kind, name);
	[controller.privilegesTable.dataSource tableView:controller.privilegesTable setObjectValue:@(value) forTableColumn:column row:row];
	XCTAssertEqualObjects([self privilege:privilege of:kind named:name in:controller], @(value));
}

- (void)choose:(NSString *)title in:(NSPopUpButton *)popup
{
	XCTAssertNotNil([popup itemWithTitle:title], @"%@ in %@", title, [popup itemTitles]);
	[popup selectItemWithTitle:title];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertTrue([self spinUntil:^BOOL{ return popup.isEnabled; } timeout:10]);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, title);
}

/// Whether role holds privilege on database directly (PUBLIC's default CONNECT doesn't count).
- (BOOL)role:(NSString *)role holds:(NSString *)privilege onDatabase:(NSString *)database on:(PGPostgresConnection *)connection
{
	NSString *sql = [NSString stringWithFormat:@"SELECT count(*)::text FROM pg_catalog.pg_database d, pg_catalog.aclexplode(d.datacl) a "
					 "WHERE d.datname = '%@' AND a.grantee = (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = '%@') AND a.privilege_type = '%@'", database, role, privilege];
	return [[self value:sql on:connection] isEqualToString:@"1"];
}

- (BOOL)role:(NSString *)role holds:(NSString *)privilege onTable:(NSString *)table on:(PGPostgresConnection *)connection
{
	return [[self value:[NSString stringWithFormat:@"SELECT has_table_privilege('%@', '%@', '%@')::text", role, table, privilege] on:connection] isEqualToString:@"true"];
}

- (void)testGridShowsKindsAndOnlyApplicableCells
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_test");
		XCTAssertTrue([controller.databasePopup.itemTitles containsObject:@"pgkit_nopublic"]);
		XCTAssertEqualObjects(controller.schemaPopup.titleOfSelectedItem, @"public");
		// The schema's owner; for pg_database_owner (public on PG 15+) the database's owner it stands for
		NSString *creatorSQL = @"SELECT CASE WHEN pg_get_userbyid(nspowner) = 'pg_database_owner' THEN (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database()) "
			"ELSE pg_get_userbyid(nspowner) END::text FROM pg_namespace WHERE nspname = 'public'";
		XCTAssertEqualObjects(controller.creatorPopup.titleOfSelectedItem, [self value:creatorSQL on:[self connectOn:port]], @"the schema's owner");

		NSArray<SPPostgresPrivilegeObject *> *rows = [controller privilegeRowsShown];
		XCTAssertGreaterThan(rows.count, 5u);
		XCTAssertEqualObjects(rows[0].kind, @"database");
		XCTAssertEqualObjects(rows[0].name, @"pgkit_test");
		XCTAssertEqualObjects(rows[1].kind, @"schema");
		XCTAssertEqualObjects(rows[1].name, @"public");
		XCTAssertGreaterThan([self privilegeRowOf:@"table" named:@"customers" in:controller], 1);
		XCTAssertGreaterThan([self privilegeRowOf:@"view" named:@"v_customers" in:controller], 1);
		NSArray *lastKinds = [[rows subarrayWithRange:NSMakeRange(rows.count - 3, 3)] valueForKey:@"kind"];
		XCTAssertEqualObjects(lastKinds, (@[@"default tables", @"default sequences", @"default functions"]));

		// Columns: Object, then the privileges in the spec's order
		NSArray *identifiers = [controller.privilegesTable.tableColumns valueForKey:@"identifier"];
		XCTAssertEqualObjects(identifiers, (@[@"object", @"SELECT", @"INSERT", @"UPDATE", @"DELETE", @"TRUNCATE", @"REFERENCES", @"TRIGGER", @"USAGE", @"CREATE", @"CONNECT", @"TEMP", @"EXECUTE"]));
		NSTableColumn *object = [controller.privilegesTable tableColumnWithIdentifier:@"object"];
		NSInteger customers = [self privilegeRowOf:@"table" named:@"customers" in:controller];
		XCTAssertEqualObjects([controller.privilegesTable.dataSource tableView:controller.privilegesTable objectValueForTableColumn:object row:customers], @"table customers");
		XCTAssertEqualObjects([controller.privilegesTable.dataSource tableView:controller.privilegesTable objectValueForTableColumn:object row:0], @"database pgkit_test");

		// CONNECT exists on the database row only
		NSTableColumn *connect = [controller.privilegesTable tableColumnWithIdentifier:@"CONNECT"];
		for (NSInteger row = 0; row < (NSInteger)rows.count; row++) {
			NSCell *cell = [controller.privilegesTable preparedCellAtColumn:[controller.privilegesTable columnWithIdentifier:@"CONNECT"] row:row];
			BOOL shown = [cell isKindOfClass:[NSButtonCell class]];
			XCTAssertEqual(shown, row == 0, @"row %ld", (long)row);
			XCTAssertEqual([controller.privilegesTable.delegate tableView:controller.privilegesTable shouldEditTableColumn:connect row:row], row == 0, @"row %ld", (long)row);
			if (row) XCTAssertNil([controller.privilegesTable.dataSource tableView:controller.privilegesTable objectValueForTableColumn:connect row:row]);
		}
		XCTAssertEqualObjects([self privilege:@"CONNECT" of:@"database" named:@"pgkit_test" in:controller], @NO);
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"table" named:@"customers" in:controller], @NO);

		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
	}
}

- (void)testTickApplyGrants
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		XCTAssertFalse(controller.applyButton.isEnabled);
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		[self set:YES privilege:@"CONNECT" of:@"database" named:@"pgkit_test" in:controller];
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);

		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"public.customers" on:check]);
		XCTAssertFalse([self role:@"sp_t4_priv" holds:@"INSERT" onTable:@"public.customers" on:check]);
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"CONNECT" onDatabase:@"pgkit_test" on:check]);
		[self.completions removeAllObjects];
	}
}

- (void)testEditsInTwoDatabasesApplyToBoth
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		[self choose:@"pgkit_nopublic" in:controller.databasePopup];
		XCTAssertEqualObjects(controller.schemaPopup.titleOfSelectedItem, @"app", @"no public schema there");
		XCTAssertEqualObjects([controller.privilegeRowsShown.firstObject name], @"pgkit_nopublic");
		[self set:YES privilege:@"SELECT" of:@"table" named:@"items" in:controller];
		[self set:YES privilege:@"USAGE" of:@"schema" named:@"app" in:controller];

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);

		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"public.customers" on:check]);
		PGPostgresConnection *nopublic = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_nopublic"];
		[self.openConnections addObject:nopublic];
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"app.items" on:nopublic]);
		XCTAssertEqualObjects([self value:@"SELECT has_schema_privilege('sp_t4_priv', 'app', 'USAGE')::text" on:nopublic], @"true");
		[self.completions removeAllObjects];
	}
}

- (void)testEditsSurviveSwitchingBack
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		NSString *owner = controller.creatorPopup.titleOfSelectedItem;
		[self set:YES privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller];

		// Another database, and back
		[self choose:@"pgkit_nopublic" in:controller.databasePopup];
		XCTAssertLessThan([self privilegeRowOf:@"table" named:@"customers" in:controller], 0);
		[self choose:@"pgkit_test" in:controller.databasePopup];
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"table" named:@"customers" in:controller], @YES, @"still pending");

		// Another role, and back
		[self select:@"sp_t4_login" in:controller];
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"table" named:@"customers" in:controller], @NO);
		[self select:@"sp_t4_priv" in:controller];
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"table" named:@"customers" in:controller], @YES);

		// Another creator: its own default rows; the first creator's edit comes back with it
		[self choose:@"sp_t4_owner" in:controller.creatorPopup];
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller], @NO);
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"table" named:@"customers" in:controller], @YES);
		[self set:YES privilege:@"INSERT" of:@"default tables" named:@"Tables created later" in:controller];
		[self choose:owner in:controller.creatorPopup];
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller], @YES);
		XCTAssertEqualObjects([self privilege:@"INSERT" of:@"default tables" named:@"Tables created later" in:controller], @NO);
		XCTAssertTrue(controller.applyButton.isEnabled);

		// Each creator's defaults are applied with that creator
		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);
		PGPostgresConnection *check = [self connectOn:port];
		NSString *sql = @"SELECT string_agg(x, ',' ORDER BY x) FROM (SELECT pg_get_userbyid(d.defaclrole) || ':' || a.privilege_type AS x FROM pg_default_acl d, aclexplode(d.defaclacl) a "
			"WHERE a.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'sp_t4_priv') AND d.defaclnamespace = 'public'::regnamespace) s";
		XCTAssertEqualObjects([self value:sql on:check], ([@[[owner stringByAppendingString:@":SELECT"], @"sp_t4_owner:INSERT"] componentsJoinedByString:@","]));
		[self.completions removeAllObjects];
	}
}

- (void)testNewRoleGetsItsPrivileges
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[controller addRole:nil];
		controller.nameField.stringValue = @"sp_t4_fresh";
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		XCTAssertEqualObjects(controller.selectedRole.name, @"sp_t4_fresh");

		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);
		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertTrue([self role:@"sp_t4_fresh" holds:@"SELECT" onTable:@"public.customers" on:check]);
		[self.completions removeAllObjects];
	}
}

- (void)testRenameAndRemoveCarryPrivilegeEdits
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		// A new role ticked, then renamed: its edit follows the new name
		[controller addRole:nil];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		controller.nameField.stringValue = @"sp_t4_renamed";
		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);
		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertTrue([self role:@"sp_t4_renamed" holds:@"SELECT" onTable:@"public.customers" on:check]);
		[self.completions removeAllObjects];

		// Removing a role drops its edits
		controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		XCTAssertEqual([controller pendingPrivilegeEditsInDatabase:@"pgkit_test"].count, 1u);
		[controller removeRole:nil];
		XCTAssertEqual([controller pendingPrivilegeEditsInDatabase:@"pgkit_test"].count, 0u);
		[controller removeRole:nil];
		XCTAssertFalse(controller.applyButton.isEnabled);
		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
	}
}

- (void)testApplyFailureInSecondDatabaseKeepsItsEdits
{
	self.reloadCatalogFixture = YES;
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[controller.createDBCheckbox performClick:nil];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		[self choose:@"pgkit_nopublic" in:controller.databasePopup];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"items" in:controller];

		// Dropped behind the sheet's back
		PGPostgresConnection *nopublic = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_nopublic"];
		[self.openConnections addObject:nopublic];
		[self run:@"DROP TABLE app.items" on:nopublic];

		[controller apply:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return controller.lastErrorMessage != nil; } timeout:10]);
		NSString *prefix = @"Roles and pgkit_test were saved; changes in pgkit_nopublic were not:";
		XCTAssertTrue([controller.lastErrorMessage hasPrefix:prefix], @"%@", controller.lastErrorMessage);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"items"], @"the server's message: %@", controller.lastErrorMessage);
		XCTAssertEqual(self.alerts.count, 1u);
		[self spinUntil:^BOOL{ return NO; } timeout:0.2];
		XCTAssertEqual(self.window.attachedSheet, controller.sheet, @"the sheet stays");
		XCTAssertEqual(self.completions.count, 0u);

		PGPostgresConnection *check = [self connectOn:port];
		XCTAssertEqualObjects([self attributesOf:@"sp_t4_priv" on:check], @"t t f t f f f -1 never", @"the General change is saved");
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"public.customers" on:check]);

		// Re-read: the saved edits are no longer pending; pgkit_nopublic's still is
		XCTAssertEqual([controller pendingPrivilegeEditsInDatabase:@"pgkit_test"].count, 0u);
		NSArray<SPPostgresPrivilegeObject *> *pending = [controller pendingPrivilegeEditsInDatabase:@"pgkit_nopublic"];
		XCTAssertEqual(pending.count, 1u);
		XCTAssertEqualObjects(pending.firstObject.name, @"items");
		XCTAssertTrue([pending.firstObject.granted containsObject:@"SELECT"]);
		XCTAssertTrue(controller.selectedRole.createDB);
		XCTAssertNotNil(controller.selectedRole.originalName);
		XCTAssertTrue(controller.applyButton.isEnabled);

		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
		[self.alerts removeAllObjects];
		[SPPostgresTestServers loadFixtureNamed:@"catalog" onPort:port.unsignedIntegerValue];
	}
}

- (void)testSuperuserNote
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		XCTAssertNotNil(controller.superuserNote);
		XCTAssertEqualObjects(controller.superuserNote.stringValue, @"Superusers bypass all privilege checks.");
		[self select:@"pgkit_test" in:controller];
		XCTAssertFalse(controller.superuserNote.isHidden);
		[self select:@"sp_t4_priv" in:controller];
		XCTAssertTrue(controller.superuserNote.isHidden);
		[controller.superuserCheckbox performClick:nil];
		XCTAssertFalse(controller.superuserNote.isHidden, @"follows the draft");
		[controller cancel:nil];
		[self waitForEndOf:controller];
		[self.completions removeAllObjects];
	}
}

#pragma mark - The document

- (void)buildDocument
{
	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = @"pg18 users";
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = 55418;
	favorite.user = @"pgkit_test";
	favorite.database = @"pgkit_test";

	self.windowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self.windowController window]);

	SPPostgresConnector *connector = [[SPPostgresConnector alloc] initWithFavorite:favorite password:@"pgkit" sshPassword:nil parentWindow:nil];
	__block PGPostgresConnection *connection = nil;
	__block BOOL done = NO;
	[connector connectWithCompletion:^(PGPostgresConnection *theConnection, NSError *error) {
		connection = theConnection;
		done = YES;
	}];
	XCTAssertTrue([self spinUntil:^BOOL{ return done; } timeout:20]);
	XCTAssertNotNil(connection);

	self.document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	__weak SPPostgresUsersControllerTests *weakSelf = self;
	self.document.alertPresenter = ^(NSAlert *alert) { [weakSelf.alerts addObject:alert]; };
	[self.windowController addTabDocument:self.document atIndex:0 select:YES];
	// The first loads run on the tab's runner
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

	// As SPPostgresDocumentTests: a sheet attaches to the nib's window once it has been shown (kept off screen)
	[[self.windowController window] setFrameOrigin:NSMakePoint(-10000, -10000)];
	[self.windowController showWindow:nil];
}

- (void)testUsersSheetNeverUsesTheDocumentConnection
{
	[self buildDocument];
	PGPostgresConnection *documentConnection = self.document.connection;
	[self run:@"BEGIN" on:documentConnection];
	[self run:@"CREATE TEMPORARY TABLE sp_t4_pending (id int)" on:documentConnection];
	[self run:@"INSERT INTO sp_t4_pending VALUES (1)" on:documentConnection];
	XCTAssertEqual(documentConnection.transactionStatus, PGPostgresTransactionInTransaction);

	__block NSUInteger provided = 0;
	void (^provider)(NSString *, void (^)(PGPostgresConnection *, NSError *)) = [self providerOn:@55418];
	self.document.connectionProvider = ^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		provided++;
		XCTAssertEqualObjects(database, @"pgkit_test");
		provider(database, completion);
	};
	NSWindow *window = [self.windowController window];
	[self.document showUserManager:nil];
	SPPostgresUsersController *controller = self.document.usersController;
	XCTAssertNotNil(controller);
	XCTAssertEqual(provided, 1u);
	XCTAssertEqual(window.attachedSheet, controller.sheet);

	[self select:@"sp_t4_login" in:controller];
	[controller.createDBCheckbox performClick:nil];
	[controller apply:nil];
	XCTAssertNil(controller.lastErrorMessage);
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil && self.document.usersController == nil; } timeout:5]);

	PGPostgresConnection *check = [self connectOn:@55418];
	XCTAssertEqualObjects([self attributesOf:@"sp_t4_login" on:check], @"t t f t f f f -1 never");
	XCTAssertEqual(documentConnection.transactionStatus, PGPostgresTransactionInTransaction, @"the user's transaction is untouched");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM sp_t4_pending" on:documentConnection], @"1");
	[self run:@"ROLLBACK" on:documentConnection];
}

- (void)testUsersToolbarItemAndMenuEnabled
{
	[self buildDocument];
	NSToolbarItem *item = [self.document toolbar:self.document.toolbar itemForItemIdentifier:SPUsersTestToolbarUsers willBeInsertedIntoToolbar:NO];
	XCTAssertEqual(item.action, @selector(showUserManager:));
	XCTAssertEqual(item.target, self.document);
	XCTAssertTrue([self.document validateToolbarItem:item]);
	NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"User Accounts…" action:@selector(showUserManager:) keyEquivalent:@""];
	XCTAssertTrue([self.document validateMenuItem:menuItem]);

	// The default provider: a connector of its own for the same favorite and password (connects later)
	NSWindow *window = [self.windowController window];
	[self.document showUserManager:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet != nil; } timeout:20], @"%@", self.alerts);
	SPPostgresUsersController *controller = self.document.usersController;
	XCTAssertEqual(window.attachedSheet, controller.sheet);
	XCTAssertTrue([[controller.editedRoles valueForKey:@"name"] containsObject:@"sp_t4_login"]);

	// Not while a sheet is attached
	XCTAssertFalse([self.document validateToolbarItem:item]);
	XCTAssertFalse([self.document validateMenuItem:menuItem]);
	[controller endSheet];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil && self.document.usersController == nil; } timeout:5]);
	XCTAssertTrue([self.document validateToolbarItem:item]);
}

#pragma mark - Final fix wave

/// F1: on PG 15+ public belongs to pg_database_owner; the default creator is the database's owner, so defaults apply.
- (void)testDefaultCreatorForPublicOwnedByDatabaseOwnerApplies
{
	NSNumber *port = @55418;
	PGPostgresConnection *check = [self connectOn:port];
	XCTAssertEqualObjects([self value:@"SELECT pg_get_userbyid(nspowner)::text FROM pg_namespace WHERE nspname = 'public'" on:check], @"pg_database_owner");
	NSString *databaseOwner = [self value:@"SELECT pg_get_userbyid(datdba)::text FROM pg_database WHERE datname = current_database()" on:check];
	XCTAssertEqualObjects(databaseOwner, @"pgkit_test");

	SPPostgresUsersController *controller = [self beginOn:port];
	[self select:@"sp_t4_priv" in:controller];
	XCTAssertEqualObjects(controller.creatorPopup.titleOfSelectedItem, databaseOwner, @"the default creator");
	[self set:YES privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller];
	[controller apply:nil];
	[self waitForEndOf:controller];
	XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);

	// A table the database's owner (this connection's role) creates later
	[self run:@"CREATE TABLE public.sp_t4_later (id int)" on:check];
	XCTAssertEqualObjects([self value:@"SELECT pg_get_userbyid(relowner)::text FROM pg_class WHERE oid = 'public.sp_t4_later'::regclass" on:check], databaseOwner);
	XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"public.sp_t4_later" on:check]);
	[self run:@"DROP TABLE public.sp_t4_later" on:check];
}

/// F2: the sheet only attaches when the gate still allows it once the roles have loaded; it names the server.
- (void)testSheetAttachesOnlyWhenCanPresent
{
	NSNumber *port = @55418;
	for (NSNumber *allowedAtAttach in @[@NO, @YES]) {
		[self.completions removeAllObjects];
		__block void (^pendingCompletion)(PGPostgresConnection *, NSError *) = nil;
		__block NSWindow *hostWhileLoading = nil;
		__block SPPostgresUsersController *controller = nil;
		controller = [[SPPostgresUsersController alloc] initWithDatabase:@"pgkit_test" connectionProvider:^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
			hostWhileLoading = controller.windowForConnectorSheets;
			pendingCompletion = completion; // deferred, as a connector's
		}];
		__weak SPPostgresUsersControllerTests *weakSelf = self;
		controller.alertPresenter = ^(NSAlert *alert) { [weakSelf.alerts addObject:alert]; };
		controller.serverName = @"pg18 users";
		__block BOOL allowed = YES;
		__block NSUInteger asked = 0;
		controller.canPresent = ^BOOL{ asked++; return allowed; };
		[self.controllers addObject:controller];
		[controller beginSheetForWindow:self.window completion:^(BOOL applied) { [weakSelf.completions addObject:@(applied)]; }];
		XCTAssertNotNil(pendingCompletion);
		XCTAssertNil(self.window.attachedSheet);
		XCTAssertEqual(hostWhileLoading, self.window, @"before the sheet is attached, connectors use the parent window");

		// Meanwhile the tab was switched (or moved to another window)
		allowed = allowedAtAttach.boolValue;
		PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_test"];
		[self.openConnections addObject:connection];
		pendingCompletion(connection, nil);
		XCTAssertEqual(asked, 1u);

		if (!allowed) {
			XCTAssertNil(self.window.attachedSheet, @"no sheet over whatever the window shows now");
			XCTAssertEqualObjects(self.completions, @[@NO]);
			XCTAssertFalse(connection.isConnected, @"its connections are closed");
			XCTAssertEqual(self.alerts.count, 0u, @"quietly");
			continue;
		}
		XCTAssertEqual(self.window.attachedSheet, controller.sheet);
		XCTAssertEqualObjects(controller.rolesHeader.stringValue, @"Users on pg18 users");
		XCTAssertEqual(controller.windowForConnectorSheets, controller.sheet, @"once attached, connectors' sheets go on the Users sheet");
		XCTAssertEqual(self.completions.count, 0u);
		[controller cancel:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions, @[@NO]);
	}
}

/// F5: default-privilege edits follow their creator's rename, and go with its removal.
- (void)testRenamedOrRemovedCreatorCarriesDefaultEdits
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresUsersController *controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[self choose:@"sp_t4_owner" in:controller.creatorPopup];
		[self set:YES privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller];

		// The creator renamed in the same session: the edit stays visible and is applied for the new name
		[self select:@"sp_t4_owner" in:controller];
		controller.nameField.stringValue = @"sp_t4_owner2";
		[self select:@"sp_t4_priv" in:controller];
		XCTAssertEqualObjects(controller.creatorPopup.titleOfSelectedItem, @"sp_t4_owner");
		XCTAssertEqualObjects([self privilege:@"SELECT" of:@"default tables" named:@"Tables created later" in:controller], @YES, @"still shown");
		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);
		PGPostgresConnection *check = [self connectOn:port];
		NSString *sql = @"SELECT string_agg(x, ',' ORDER BY x) FROM (SELECT pg_get_userbyid(d.defaclrole) || ':' || a.privilege_type AS x FROM pg_default_acl d, aclexplode(d.defaclacl) a "
			"WHERE a.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'sp_t4_priv') AND d.defaclnamespace = 'public'::regnamespace) s";
		XCTAssertEqualObjects([self value:sql on:check], @"sp_t4_owner2:SELECT");
		[self.completions removeAllObjects];

		// The creator removed: its default edits go, and Apply isn't stuck on them
		controller = [self beginOn:port];
		[self select:@"sp_t4_priv" in:controller];
		[self choose:@"sp_t4_owner2" in:controller.creatorPopup];
		[self set:YES privilege:@"INSERT" of:@"default tables" named:@"Tables created later" in:controller];
		[self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
		XCTAssertEqual([controller pendingPrivilegeEditsInDatabase:@"pgkit_test"].count, 2u);
		[self select:@"sp_t4_owner2" in:controller];
		[controller removeRole:nil];
		NSArray<SPPostgresPrivilegeObject *> *pending = [controller pendingPrivilegeEditsInDatabase:@"pgkit_test"];
		XCTAssertEqual(pending.count, 1u, @"only the creator's default edit goes");
		XCTAssertEqualObjects(pending.firstObject.name, @"customers");
		[controller removeRole:nil]; // unmarked again
		[controller apply:nil];
		[self waitForEndOf:controller];
		XCTAssertEqualObjects(self.completions.firstObject, @YES, @"%@", controller.lastErrorMessage);
		XCTAssertTrue([self role:@"sp_t4_priv" holds:@"SELECT" onTable:@"public.customers" on:check]);
		XCTAssertEqualObjects([self value:sql on:check], @"sp_t4_owner2:SELECT", @"the removed creator's INSERT was dropped");
		[self.completions removeAllObjects];
	}
}

/// F6: a partial apply without role changes doesn't claim roles were saved.
- (void)testPartialApplyWithoutRoleChangesNamesWhatWasSaved
{
	self.reloadCatalogFixture = YES;
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		for (NSNumber *firstToo in @[@YES, @NO]) {
			SPPostgresUsersController *controller = [self beginOn:port];
			[self select:@"sp_t4_priv" in:controller];
			if (firstToo.boolValue) [self set:YES privilege:@"SELECT" of:@"table" named:@"customers" in:controller];
			[self choose:@"pgkit_nopublic" in:controller.databasePopup];
			[self set:YES privilege:@"SELECT" of:@"table" named:@"items" in:controller];
			PGPostgresConnection *nopublic = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_nopublic"];
			[self.openConnections addObject:nopublic];
			[self run:@"DROP TABLE app.items" on:nopublic];

			[controller apply:nil];
			XCTAssertTrue([self spinUntil:^BOOL{ return controller.lastErrorMessage != nil; } timeout:10]);
			NSString *prefix = firstToo.boolValue ? @"pgkit_test were saved; changes in pgkit_nopublic were not:" : @"Changes in pgkit_nopublic were not saved:";
			XCTAssertTrue([controller.lastErrorMessage hasPrefix:prefix], @"%@", controller.lastErrorMessage);
			XCTAssertEqual(self.window.attachedSheet, controller.sheet, @"the sheet stays");

			[controller cancel:nil];
			[self waitForEndOf:controller];
			[self.completions removeAllObjects];
			[self.alerts removeAllObjects];
			[SPPostgresTestServers loadFixtureNamed:@"catalog" onPort:port.unsignedIntegerValue];
		}
	}
}

/// F7: roles marked for removal are listed disabled in both membership tables.
- (void)testRolesMarkedForRemovalAreDisabledInMembership
{
	SPPostgresUsersController *controller = [self beginOn:@55418];
	[self select:@"sp_t4_group" in:controller];
	[controller removeRole:nil];
	XCTAssertTrue(controller.selectedRole.markedForDeletion);

	NSTableView *tables[] = { controller.memberOfTable, controller.membersTable };
	[self select:@"sp_t4_login" in:controller];
	for (int i = 0; i < 2; i++) {
		NSTableView *table = tables[i];
		NSArray *candidates = (i == 0) ? controller.memberOfCandidates : controller.membersCandidates;
		NSInteger group = (NSInteger)[candidates indexOfObject:@"sp_t4_group"];
		NSInteger owner = (NSInteger)[candidates indexOfObject:@"sp_t4_owner"];
		XCTAssertNotEqual(group, (NSInteger)NSNotFound);
		XCTAssertNotEqual(owner, (NSInteger)NSNotFound);
		NSTableColumn *member = [table tableColumnWithIdentifier:@"member"];
		NSTableColumn *admin = [table tableColumnWithIdentifier:@"admin"];
		XCTAssertFalse([table.delegate tableView:table shouldEditTableColumn:member row:group]);
		XCTAssertFalse([table.delegate tableView:table shouldEditTableColumn:admin row:group]);
		XCTAssertTrue([table.delegate tableView:table shouldEditTableColumn:member row:owner]);
		NSCell *cell = [table preparedCellAtColumn:[table columnWithIdentifier:@"member"] row:group];
		XCTAssertFalse(cell.isEnabled, @"shown disabled");
		XCTAssertTrue([[table preparedCellAtColumn:[table columnWithIdentifier:@"member"] row:owner] isEnabled]);

		// A tick that gets through anyway changes nothing
		id before = [table.dataSource tableView:table objectValueForTableColumn:member row:group];
		[table.dataSource tableView:table setObjectValue:@(![before boolValue]) forTableColumn:member row:group];
		XCTAssertEqualObjects([table.dataSource tableView:table objectValueForTableColumn:member row:group], before);
	}
	XCTAssertEqualObjects([controller.selectedRole.memberOf objectForKey:@"sp_t4_group"], @NO, @"still a member, as on the server");
	[controller cancel:nil];
	[self waitForEndOf:controller];
}

/// F3 and F4: the default provider's connections log to the Console under the tab's name (passwords only as
/// verifiers), and a connector opened while the sheet is up hosts its SSH sheets on the Users sheet.
- (void)testDefaultProviderLogsToConsoleAndUsesUsersSheetForConnectors
{
	// As SPPostgresDocumentTests: the volatile argument domain only, restored even on failure
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSDictionary *original = [prefs volatileDomainForName:NSArgumentDomain] ?: @{};
	NSMutableDictionary *domain = [original mutableCopy];
	domain[@"ConsoleEnableLogging"] = @YES;
	domain[@"ConsoleEnableInterfaceLogging"] = @YES;
	[prefs removeVolatileDomainForName:NSArgumentDomain];
	[prefs setVolatileDomain:domain forName:NSArgumentDomain];
	[self addTeardownBlock:^{
		[prefs removeVolatileDomainForName:NSArgumentDomain];
		[prefs setVolatileDomain:original forName:NSArgumentDomain];
	}];

	[self buildDocument];
	NSWindow *window = [self.windowController window];
	[self.document showUserManager:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet != nil; } timeout:20], @"%@", self.alerts);
	SPPostgresUsersController *controller = self.document.usersController;
	XCTAssertEqual(window.attachedSheet, controller.sheet);
	XCTAssertEqualObjects(controller.rolesHeader.stringValue, @"Users on pg18 users");
	XCTAssertEqual(controller.adoptedConnectors.count, 1u);

	// F4: another database's connector, opened while the sheet is up
	NSPopUpButton *popup = controller.databasePopup;
	[popup selectItemWithTitle:@"pgkit_nopublic"];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertEqual(controller.adoptedConnectors.count, 2u);
	XCTAssertEqual([(SPPostgresConnector *)controller.adoptedConnectors.lastObject parentWindow], controller.sheet);
	XCTAssertTrue([self spinUntil:^BOOL{ return popup.isEnabled; } timeout:20]);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_nopublic", @"%@", controller.lastErrorMessage);

	// F3: each connection has a logger like the tab's
	for (NSString *database in @[@"pgkit_test", @"pgkit_nopublic"]) {
		SPPostgresConsoleLogger *logger = [SPPostgresConsoleLogger loggerForConnection:[controller openConnectionForDatabase:database]];
		XCTAssertNotNil(logger, @"%@", database);
		XCTAssertEqualObjects(logger.connectionName, @"pg18 users");
		XCTAssertEqualObjects(logger.database, database);
	}

	NSString *password = @"Plain-sp_t4-Console!";
	[self select:@"sp_t4_login" in:controller];
	controller.passwordField.stringValue = password;
	[controller apply:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil && self.document.usersController == nil; } timeout:10], @"%@", controller.lastErrorMessage);

	// Test-only read of the console's existing storage (no public accessor)
	id queryController = [(id)NSClassFromString(@"SPQueryController") valueForKey:@"sharedQueryController"];
	NSArray *messages = [queryController valueForKey:@"messagesFullSet"];
	id alter = nil;
	for (id message in messages) {
		NSString *text = [message valueForKey:@"message"];
		XCTAssertFalse([text containsString:password], @"%@", text);
		if ([text containsString:@"sp_t4_login"] && [text containsString:@"PASSWORD"]) alter = message;
	}
	XCTAssertNotNil(alter, @"the role statement is in the console");
	XCTAssertEqualObjects([alter valueForKey:@"messageConnection"], @"pg18 users");
	XCTAssertEqualObjects([alter valueForKey:@"messageDatabase"], @"pgkit_test");
	XCTAssertTrue([[alter valueForKey:@"message"] containsString:@"SCRAM-SHA-256$"] || [[alter valueForKey:@"message"] containsString:@"md5"], @"%@", [alter valueForKey:@"message"]);
}

#pragma mark - Loading sheet

/// A slow connection (as over SSH): "Loading users…" shows after 0.3 s, hosts the connector's sheets, and gives way to
/// the Users sheet once the roles have loaded.
- (void)testLoadingSheetShowsWhileTheConnectionIsSlow
{
	__block void (^pendingCompletion)(PGPostgresConnection *, NSError *) = nil;
	SPPostgresUsersController *controller = [[SPPostgresUsersController alloc] initWithDatabase:@"pgkit_test" connectionProvider:^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		pendingCompletion = completion; // deferred, as a connector's
	}];
	__weak SPPostgresUsersControllerTests *weakSelf = self;
	controller.alertPresenter = ^(NSAlert *alert) { [weakSelf.alerts addObject:alert]; };
	[self.controllers addObject:controller];
	[controller beginSheetForWindow:self.window completion:^(BOOL applied) { [weakSelf.completions addObject:@(applied)]; }];

	// Nothing at first (a fast load never flashes it), then the loading sheet
	XCTAssertNil(controller.loadingSheet);
	XCTAssertNil(self.window.attachedSheet);
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet != nil; } timeout:2]);
	SPLoadingSheet *loading = controller.loadingSheet;
	XCTAssertNotNil(loading);
	XCTAssertEqual(self.window.attachedSheet, [loading panel]);
	XCTAssertEqualObjects([[loading messageField] stringValue], @"Loading users…");
	XCTAssertTrue([[loading spinner] usesThreadedAnimation]);
	XCTAssertNotNil([loading cancelButton]);
	XCTAssertEqual(controller.windowForConnectorSheets, [loading panel], @"an SSH sheet goes on the loading sheet");

	// The connection comes: the Users sheet replaces it
	PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:55418 database:@"pgkit_test"];
	[self.openConnections addObject:connection];
	pendingCompletion(connection, nil);
	XCTAssertNil(controller.loadingSheet);
	XCTAssertFalse([loading isShown]);
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == controller.sheet; } timeout:5], @"%@", controller.lastErrorMessage);
	XCTAssertGreaterThan(controller.editedRoles.count, 0u);
	XCTAssertEqual(self.completions.count, 0u);
}

/// Cancel on "Loading users…": the Users sheet never opens and a connection that comes later is closed.
- (void)testCancellingTheLoadingSheet
{
	__block void (^pendingCompletion)(PGPostgresConnection *, NSError *) = nil;
	SPPostgresUsersController *controller = [[SPPostgresUsersController alloc] initWithDatabase:@"pgkit_test" connectionProvider:^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		pendingCompletion = completion;
	}];
	__weak SPPostgresUsersControllerTests *weakSelf = self;
	controller.alertPresenter = ^(NSAlert *alert) { [weakSelf.alerts addObject:alert]; };
	[self.controllers addObject:controller];
	[controller beginSheetForWindow:self.window completion:^(BOOL applied) { [weakSelf.completions addObject:@(applied)]; }];
	XCTAssertTrue([self spinUntil:^BOOL{ return controller.loadingSheet != nil; } timeout:2]);

	[[(SPLoadingSheet *)controller.loadingSheet cancelButton] performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil; } timeout:5]);
	XCTAssertEqualObjects(self.completions, @[@NO]);
	XCTAssertNil(controller.loadingSheet);

	PGPostgresConnection *late = [SPPostgresTestServers connectedConnectionOnPort:55418 database:@"pgkit_test"];
	pendingCompletion(late, nil);
	XCTAssertFalse([late isConnected], @"closed: nobody wants it now");
	XCTAssertNil(self.window.attachedSheet);
	XCTAssertEqual(self.completions.count, 1u);
	XCTAssertEqual(self.alerts.count, 0u);
}

/// A slow connection that fails: the loading sheet ends before the error is shown.
- (void)testLoadingSheetEndsBeforeAnError
{
	__block void (^pendingCompletion)(PGPostgresConnection *, NSError *) = nil;
	SPPostgresUsersController *controller = [[SPPostgresUsersController alloc] initWithDatabase:@"pgkit_test" connectionProvider:^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		pendingCompletion = completion;
	}];
	__weak SPPostgresUsersControllerTests *weakSelf = self;
	__block NSWindow *sheetWhenAlerted = (NSWindow *)[NSNull null];
	controller.alertPresenter = ^(NSAlert *alert) { sheetWhenAlerted = weakSelf.window.attachedSheet; [weakSelf.alerts addObject:alert]; };
	[self.controllers addObject:controller];
	[controller beginSheetForWindow:self.window completion:^(BOOL applied) { [weakSelf.completions addObject:@(applied)]; }];
	XCTAssertTrue([self spinUntil:^BOOL{ return controller.loadingSheet != nil; } timeout:2]);

	pendingCompletion(nil, [NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey: @"no route to host"}]);
	XCTAssertEqual(self.alerts.count, 1u);
	XCTAssertNil(sheetWhenAlerted, @"the loading sheet was gone when the error came");
	XCTAssertEqualObjects(self.completions, @[@NO]);
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil; } timeout:5]);
}

/// A fast load (the connection at once) shows no loading sheet, even after the delay.
- (void)testFastLoadShowsNoLoadingSheet
{
	SPPostgresUsersController *controller = [self beginOn:@55418];
	[self spinUntil:^BOOL{ return NO; } timeout:0.5];
	XCTAssertNil(controller.loadingSheet);
	XCTAssertEqual(self.window.attachedSheet, controller.sheet);
}

@end

