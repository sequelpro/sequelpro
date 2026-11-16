#import "SPPostgresUsersController.h"
#import "SPPostgresRoles.h"
#import "SPPostgresConnector.h"
#import "SPPostgresUsersPrivilegesPane.h"
#import "SPLoadingSheet.h"
#import <PostgresKit/PostgresKit.h>

static const CGFloat SPPostgresUsersSheetWidth = 760;
static const CGFloat SPPostgresUsersSheetHeight = 520;
static const CGFloat SPPostgresUsersMinWidth = 680;
static const CGFloat SPPostgresUsersMinHeight = 460;
static const CGFloat SPPostgresUsersMargin = 20;
static const CGFloat SPPostgresUsersListWidth = 200;
static const CGFloat SPPostgresUsersLabelWidth = 110;

static NSString * const SPPostgresUsersRoleColumn = @"role";
static NSString * const SPPostgresUsersMemberColumn = @"member";
static NSString * const SPPostgresUsersNameColumn = @"name";
static NSString * const SPPostgresUsersAdminColumn = @"admin";

static BOOL SPPostgresUsersSameDate(NSDate *a, NSDate *b)
{
	return a == b || (a && b && [a isEqualToDate:b]);
}

/**
 * The data source and delegate of the membership lists: they are cell-based (checkboxes), which they wouldn't be
 * with the controller as delegate (it builds the roles list's views). Forwards to the controller.
 */
@interface SPPostgresUsersMembershipSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
	SPPostgresUsersController *owner; // not retained: the controller owns this
}
- (instancetype)initWithOwner:(SPPostgresUsersController *)owner;
@end

@implementation SPPostgresUsersMembershipSource

- (instancetype)initWithOwner:(SPPostgresUsersController *)theOwner
{
	if ((self = [super init])) owner = theOwner;
	return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
	return [owner numberOfRowsInTableView:table];
}

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	return [owner tableView:table objectValueForTableColumn:column row:row];
}

- (void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	[owner tableView:table setObjectValue:object forTableColumn:column row:row];
}

- (void)tableView:(NSTableView *)table willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	[owner tableView:table willDisplayCell:cell forTableColumn:column row:row];
}

- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	return [owner tableView:table shouldEditTableColumn:column row:row];
}

@end

@interface SPPostgresUsersController () <SPPostgresUsersPrivilegesPaneDelegate>
@end

/// How long the sheet may take to get ready before "Loading users…" is shown (fast loads show nothing in between).
static const NSTimeInterval SPPostgresUsersLoadingSheetDelay = 0.3;

@implementation SPPostgresUsersController
{
	SPLoadingSheet *loadingSheet;   // "Loading users…" while the connection opens and the roles load
	SPPostgresUsersMembershipSource *membershipSource;
	SPPostgresUsersPrivilegesPane *privilegesPane;

	NSString *database;
	void (^provider)(NSString *, void (^)(PGPostgresConnection *, NSError *));
	void (^completion)(BOOL);
	NSWindow *parentWindow; // not retained

	/// Connections by database name (the provider's), and the connectors adopted from it
	NSMutableDictionary *connections;
	NSMutableArray *connectors;

	SPPostgresRoles *rolesReader;
	/// As read from the server, and the draft (copies, plus new roles)
	NSArray *originalRoles;
	NSMutableArray *editedRoles;
	/// Every role on the server, pg_* included
	NSArray *serverRoleNames;
	NSString *sessionRoleName;

	/// The role the General and Membership tabs show (one of editedRoles, or nil)
	SPPostgresRole *shownRole;
	NSArray *memberOfCandidates;
	NSArray *membersCandidates;

	NSString *lastErrorMessage;

	BOOL began;
	BOOL sheetOpen;
	BOOL finished;
	/// Between the first transaction of an Apply and its last database
	BOOL applying;
	/// What the sheet's end reports (set by Apply before ending it)
	BOOL closingApplied;
	/// The running Apply's first transaction changed roles (what its partial-failure message starts with)
	BOOL appliedRoleChanges;

	NSWindow *sheet;
	NSTextField *rolesHeader;
	NSTableView *rolesTable;
	NSTabView *tabView;
	NSTextField *nameField;
	NSSecureTextField *passwordField;
	NSButton *clearPasswordCheckbox;
	NSButton *validUntilCheckbox;
	NSDatePicker *validUntilPicker;
	NSTextField *connectionLimitField;
	NSButton *loginCheckbox;
	NSButton *inheritCheckbox;
	NSButton *superuserCheckbox;
	NSButton *createDBCheckbox;
	NSButton *createRoleCheckbox;
	NSButton *replicationCheckbox;
	NSButton *bypassRLSCheckbox;
	NSTableView *memberOfTable;
	NSTableView *membersTable;
	NSButton *addButton;
	NSButton *removeButton;
	NSButton *duplicateButton;
	NSButton *applyButton;
	NSButton *cancelButton;
}

@synthesize alertPresenter;
@synthesize canPresent;
@synthesize serverName;
@synthesize rolesHeader;
@synthesize sheet, rolesTable, tabView, nameField, passwordField, clearPasswordCheckbox, validUntilCheckbox, validUntilPicker, connectionLimitField;
@synthesize loginCheckbox, inheritCheckbox, superuserCheckbox, createDBCheckbox, createRoleCheckbox, replicationCheckbox, bypassRLSCheckbox;
@synthesize memberOfTable, membersTable, memberOfCandidates, membersCandidates;
@synthesize addButton, removeButton, duplicateButton, applyButton, cancelButton;
@synthesize lastErrorMessage;

#pragma mark - Setup

- (instancetype)initWithDatabase:(NSString *)theDatabase connectionProvider:(void (^)(NSString *, void (^)(PGPostgresConnection *, NSError *)))theProvider
{
	if ((self = [super init])) {
		database = [theDatabase copy];
		provider = [theProvider copy];
		connections = [[NSMutableDictionary alloc] init];
		connectors = [[NSMutableArray alloc] init];
		editedRoles = [[NSMutableArray alloc] init];
		originalRoles = [@[] retain];
		serverRoleNames = [@[] retain];
		memberOfCandidates = [@[] retain];
		membersCandidates = [@[] retain];
		membershipSource = [[SPPostgresUsersMembershipSource alloc] initWithOwner:self];
		privilegesPane = [[SPPostgresUsersPrivilegesPane alloc] initWithDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[loadingSheet release];
	[rolesTable setDelegate:nil];
	[rolesTable setDataSource:nil];
	[memberOfTable setDelegate:nil];
	[memberOfTable setDataSource:nil];
	[membersTable setDelegate:nil];
	[membersTable setDataSource:nil];
	[nameField setDelegate:nil];
	[passwordField setDelegate:nil];
	[connectionLimitField setDelegate:nil];
	[tabView setDelegate:nil];
	[membershipSource release];
	[privilegesPane release];

	[self _closeConnections];

	[database release];
	[provider release];
	[completion release];
	[connections release];
	[connectors release];
	[rolesReader release];
	[originalRoles release];
	[editedRoles release];
	[serverRoleNames release];
	[sessionRoleName release];
	[memberOfCandidates release];
	[membersCandidates release];
	[lastErrorMessage release];
	[alertPresenter release];
	[canPresent release];
	[serverName release];

	[sheet release];
	[rolesHeader release];
	[rolesTable release];
	[tabView release];
	[nameField release];
	[passwordField release];
	[clearPasswordCheckbox release];
	[validUntilCheckbox release];
	[validUntilPicker release];
	[connectionLimitField release];
	[loginCheckbox release];
	[inheritCheckbox release];
	[superuserCheckbox release];
	[createDBCheckbox release];
	[createRoleCheckbox release];
	[replicationCheckbox release];
	[bypassRLSCheckbox release];
	[memberOfTable release];
	[membersTable release];
	[addButton release];
	[removeButton release];
	[duplicateButton release];
	[applyButton release];
	[cancelButton release];

	[super dealloc];
}

- (NSArray *)editedRoles
{
	return [[editedRoles copy] autorelease];
}

- (SPPostgresRole *)selectedRole
{
	NSInteger row = [rolesTable selectedRow];
	if (row < 0 || row >= (NSInteger)[editedRoles count]) return nil;
	return [editedRoles objectAtIndex:(NSUInteger)row];
}

- (NSWindow *)windowForConnectorSheets
{
	if (sheetOpen && sheet) return sheet;
	// The SSH tunnel's sheets (passphrase, host key) go on the loading sheet while it is up
	if ([loadingSheet isShown]) return [loadingSheet panel];
	return parentWindow;
}

#pragma mark - Loading sheet

- (SPLoadingSheet *)loadingSheet
{
	return [[loadingSheet retain] autorelease];
}

- (void)_showLoadingSheet
{
	if (finished || sheetOpen || loadingSheet || !parentWindow) return;
	__block SPPostgresUsersController *me = self; // not retained: the sheet ends before this controller finishes
	loadingSheet = [[SPLoadingSheet beginOnWindow:parentWindow
										  message:NSLocalizedString(@"Loading users…", @"user manager: loading sheet message")
									cancelHandler:^{ [me _loadingCancelled]; }] retain];
}

- (void)_endLoadingSheet
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showLoadingSheet) object:nil];
	[loadingSheet end];
	[loadingSheet release];
	loadingSheet = nil;
}

/// Cancel on the loading sheet: the sheet never opens (a connection that comes later is closed).
- (void)_loadingCancelled
{
	[loadingSheet release];
	loadingSheet = nil;
	[self _finish:NO];
}

- (PGPostgresConnection *)openConnectionForDatabase:(NSString *)theDatabase
{
	return theDatabase ? [connections objectForKey:theDatabase] : nil;
}

- (NSArray *)adoptedConnectors
{
	return [[connectors copy] autorelease];
}

- (void)adoptConnector:(SPPostgresConnector *)connector
{
	if (!connector) return;
	if (finished) {
		[connector disconnect];
		return;
	}
	[connectors addObject:connector];
}

#pragma mark - Connections

/// A connection of the controller's own to theDatabase (kept for the sheet's life), from the provider.
- (void)_connectionForDatabase:(NSString *)theDatabase completion:(void (^)(PGPostgresConnection *connection, NSError *error))done
{
	PGPostgresConnection *existing = [connections objectForKey:theDatabase];
	if (existing) {
		done(existing, nil);
		return;
	}
	if (!provider) {
		done(nil, nil);
		return;
	}

	void (^after)(PGPostgresConnection *, NSError *) = [[done copy] autorelease];
	provider(theDatabase, ^(PGPostgresConnection *connection, NSError *error) {
		if (finished) {
			[connection disconnect];
			return;
		}
		if (connection) [connections setObject:connection forKey:theDatabase];
		after(connection, error);
	});
}

- (void)_closeConnections
{
	for (PGPostgresConnection *connection in [connections allValues]) [connection disconnect];
	[connections removeAllObjects];
	for (SPPostgresConnector *connector in connectors) [connector disconnect];
	[connectors removeAllObjects];
}

#pragma mark - Begin and end

- (void)beginSheetForWindow:(NSWindow *)window completion:(void (^)(BOOL))theCompletion
{
	if (began) {
		if (theCompletion) theCompletion(NO);
		return;
	}
	began = YES;
	completion = [theCompletion copy];
	parentWindow = window;
	[self retain]; // until -_finish:

	if (!window || [window attachedSheet] || ![database length]) {
		[self _finish:NO];
		return;
	}

	// Opening the connection (maybe through SSH) and reading the roles can take seconds: say so if it does
	[self performSelector:@selector(_showLoadingSheet) withObject:nil afterDelay:SPPostgresUsersLoadingSheetDelay];

	[self _connectionForDatabase:database completion:^(PGPostgresConnection *connection, NSError *error) {
		if (finished) return;
		if (!connection) {
			[self _showErrorTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not open database “%@”", @"Postgres users: connection failed title"), database]
						  message:[error localizedDescription] ?: NSLocalizedString(@"The connection failed.", @"Postgres users: connection failed, no reason")];
			[self _finish:NO];
			return;
		}
		NSError *loadError = nil;
		if (![self _loadRolesFrom:connection error:&loadError]) {
			[self _showErrorTitle:NSLocalizedString(@"Could not load the roles", @"Postgres users: load failed title") message:[loadError localizedDescription] ?: @""];
			[self _finish:NO];
			return;
		}
		[self _endLoadingSheet];
		// The roles may take seconds to load (e.g. over SSH): by now the tab may be another one, or in another window
		if (!parentWindow || [parentWindow attachedSheet] || (canPresent && !canPresent())) {
			[self _finish:NO];
			return;
		}
		[self _build];
		sheetOpen = YES;
		[parentWindow beginSheet:sheet completionHandler:^(NSModalResponse returnCode) {
			// Ended by -_close: or by someone else (e.g. the window closing: as Cancel)
			sheetOpen = NO;
			[self _finish:closingApplied];
		}];
		[sheet makeFirstResponder:rolesTable];
	}];
}

- (BOOL)_loadRolesFrom:(PGPostgresConnection *)connection error:(NSError **)error
{
	SPPostgresRoles *reader = [[[SPPostgresRoles alloc] initWithConnection:connection] autorelease];
	NSArray *roles = [reader roles:error];
	if (!roles) return NO;
	NSArray *names = [reader allRoleNames:error];
	if (!names) return NO;

	[rolesReader release];
	rolesReader = [reader retain];
	[originalRoles release];
	originalRoles = [roles copy];
	[serverRoleNames release];
	serverRoleNames = [names copy];
	[sessionRoleName release];
	sessionRoleName = [[reader sessionRoleName] copy];

	[editedRoles removeAllObjects];
	for (SPPostgresRole *role in roles) [editedRoles addObject:[[role copy] autorelease]];
	return YES;
}

/// Ends the sheet (or, before it opened, finishes): applied is what the completion gets.
- (void)_close:(BOOL)applied
{
	if (finished) return;
	if (sheetOpen) {
		sheetOpen = NO; // nothing more is done in the sheet meanwhile
		closingApplied = applied;
		[parentWindow endSheet:sheet returnCode:applied ? NSModalResponseOK : NSModalResponseCancel];
		return;
	}
	[self _finish:applied];
}

- (void)_finish:(BOOL)applied
{
	if (finished) return;
	finished = YES;
	sheetOpen = NO;
	[self _endLoadingSheet];

	[sheet orderOut:nil];
	[self _closeConnections];

	void (^done)(BOOL) = [[completion retain] autorelease];
	[completion release];
	completion = nil;
	if (done) done(applied);
	[self autorelease]; // balances -beginSheetForWindow:completion:
}

- (void)endSheet
{
	if (!began) return;
	[self _close:NO];
}

- (void)cancel:(id)sender
{
	[self _close:NO];
}

#pragma mark - Errors

- (void)_showErrorTitle:(NSString *)title message:(NSString *)message
{
	[self _endLoadingSheet]; // so the alert can go on the window
	[lastErrorMessage release];
	lastErrorMessage = [message copy];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleWarning];
	[alert setMessageText:title];
	[alert setInformativeText:message ?: @""];

	if (alertPresenter) {
		alertPresenter(alert);
		return;
	}
	NSWindow *host = sheetOpen ? sheet : parentWindow;
	if (host && ![host attachedSheet]) [alert beginSheetModalForWindow:host completionHandler:nil];
	else [alert runModal];
}

#pragma mark - Building

- (NSTextField *)_label:(NSString *)text frame:(NSRect)frame
{
	NSTextField *label = [NSTextField labelWithString:text];
	[label setFrame:frame];
	[label setAlignment:NSTextAlignmentRight];
	[label setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	return label;
}

- (NSButton *)_checkbox:(NSString *)title identifier:(NSString *)identifier frame:(NSRect)frame action:(SEL)action
{
	NSButton *checkbox = [[NSButton checkboxWithTitle:title target:self action:action] retain];
	[checkbox setIdentifier:identifier];
	[checkbox setFrame:frame];
	[checkbox setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	return checkbox;
}

- (void)_setupTextField:(NSTextField *)field identifier:(NSString *)identifier placeholder:(NSString *)placeholder
{
	[field setIdentifier:identifier];
	[[field cell] setScrollable:YES];
	[[field cell] setUsesSingleLineMode:YES];
	if (placeholder) [field setPlaceholderString:placeholder];
	[field setDelegate:self];
	[field setTarget:self];
	[field setAction:@selector(_fieldChanged:)];
	[field setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
}

- (NSButton *)_listButtonWithImage:(NSImage *)image title:(NSString *)title frame:(NSRect)frame action:(SEL)action identifier:(NSString *)identifier toolTip:(NSString *)toolTip
{
	NSButton *button = [[NSButton alloc] initWithFrame:frame];
	[button setBezelStyle:NSBezelStyleSmallSquare];
	[button setButtonType:NSButtonTypeMomentaryPushIn];
	if (image) {
		[button setImage:image];
		[button setImagePosition:NSImageOnly];
		[button setTitle:@""];
	}
	else {
		[button setTitle:title];
	}
	[button setTarget:self];
	[button setAction:action];
	[button setIdentifier:identifier];
	[button setToolTip:toolTip];
	[button setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
	return button;
}

/// A membership list: checkbox, role name, Admin checkbox.
- (NSTableView *)_membershipTableWithIdentifier:(NSString *)identifier scrollView:(NSScrollView **)scrollView frame:(NSRect)frame
{
	*scrollView = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
	[*scrollView setHasVerticalScroller:YES];
	[*scrollView setAutohidesScrollers:YES];
	[*scrollView setBorderType:NSBezelBorder];
	[*scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

	NSTableView *table = [[NSTableView alloc] initWithFrame:[[*scrollView contentView] bounds]];
	[table setIdentifier:identifier];
	[table setRowHeight:18];
	[table setFocusRingType:NSFocusRingTypeNone];
	[table setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	[table setAllowsEmptySelection:YES];

	NSTableColumn *member = [[[NSTableColumn alloc] initWithIdentifier:SPPostgresUsersMemberColumn] autorelease];
	NSButtonCell *check = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
	[check setButtonType:NSButtonTypeSwitch];
	[check setImagePosition:NSImageOnly];
	[member setDataCell:check];
	[member setWidth:22];
	[member setMinWidth:22];
	[member setMaxWidth:22];
	[[member headerCell] setStringValue:@""];
	[table addTableColumn:member];

	NSTableColumn *name = [[[NSTableColumn alloc] initWithIdentifier:SPPostgresUsersNameColumn] autorelease];
	[name setEditable:NO];
	[name setWidth:200];
	[name setResizingMask:NSTableColumnAutoresizingMask];
	[[name headerCell] setStringValue:NSLocalizedString(@"Role", @"Postgres users: membership role column")];
	[table addTableColumn:name];

	NSTableColumn *admin = [[[NSTableColumn alloc] initWithIdentifier:SPPostgresUsersAdminColumn] autorelease];
	NSButtonCell *adminCheck = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
	[adminCheck setButtonType:NSButtonTypeSwitch];
	[adminCheck setImagePosition:NSImageOnly];
	[admin setDataCell:adminCheck];
	[admin setWidth:60];
	[admin setMinWidth:60];
	[admin setMaxWidth:60];
	[[admin headerCell] setStringValue:NSLocalizedString(@"Admin", @"Postgres users: membership admin option column")];
	[admin setHeaderToolTip:NSLocalizedString(@"With admin option: may grant this membership to others", @"Postgres users: admin option tooltip")];
	[table addTableColumn:admin];

	[table setDataSource:membershipSource];
	[table setDelegate:membershipSource];
	[*scrollView setDocumentView:table];
	return table;
}

- (void)_build
{
	sheet = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, SPPostgresUsersSheetWidth, SPPostgresUsersSheetHeight)
										styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[sheet setReleasedWhenClosed:NO];
	[sheet setTitle:NSLocalizedString(@"Users", @"Postgres users sheet title")];
	[sheet setContentMinSize:NSMakeSize(SPPostgresUsersMinWidth, SPPostgresUsersMinHeight)];
	NSView *content = [sheet contentView];

	// Left: the roles
	// Its header names the server: the sheet may outlive a glance at which tab it came from
	NSString *header = [serverName length]
		? [NSString stringWithFormat:NSLocalizedString(@"Users on %@", @"Postgres users: roles list title naming the server"), serverName]
		: NSLocalizedString(@"ROLES", @"Postgres users: roles list title");
	rolesHeader = [[NSTextField labelWithString:header] retain];
	[rolesHeader setIdentifier:@"usersHeader"];
	[rolesHeader setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	[rolesHeader setTextColor:[NSColor secondaryLabelColor]];
	[rolesHeader setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[rolesHeader setToolTip:header];
	[rolesHeader setFrame:NSMakeRect(SPPostgresUsersMargin, SPPostgresUsersSheetHeight - SPPostgresUsersMargin - 14, SPPostgresUsersListWidth, 14)];
	[rolesHeader setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	[content addSubview:rolesHeader];

	CGFloat listBottom = 44;
	NSScrollView *rolesScroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(SPPostgresUsersMargin, listBottom, SPPostgresUsersListWidth, SPPostgresUsersSheetHeight - SPPostgresUsersMargin - 20 - listBottom)] autorelease];
	[rolesScroll setHasVerticalScroller:YES];
	[rolesScroll setAutohidesScrollers:YES];
	[rolesScroll setBorderType:NSBezelBorder];
	[rolesScroll setAutoresizingMask:NSViewHeightSizable | NSViewMaxXMargin];
	rolesTable = [[NSTableView alloc] initWithFrame:[[rolesScroll contentView] bounds]];
	[rolesTable setIdentifier:@"usersRoles"];
	[rolesTable setHeaderView:nil];
	[rolesTable setRowHeight:32];
	[rolesTable setAllowsEmptySelection:NO];
	[rolesTable setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
	NSTableColumn *roleColumn = [[[NSTableColumn alloc] initWithIdentifier:SPPostgresUsersRoleColumn] autorelease];
	[roleColumn setWidth:SPPostgresUsersListWidth - 4];
	[roleColumn setEditable:NO];
	[rolesTable addTableColumn:roleColumn];
	[rolesTable setDataSource:self];
	[rolesTable setDelegate:self];
	[rolesScroll setDocumentView:rolesTable];
	[content addSubview:rolesScroll];

	// Under the list: +, − and duplicate
	CGFloat buttonY = listBottom - 23;
	addButton = [self _listButtonWithImage:[NSImage imageNamed:NSImageNameAddTemplate] title:@"+" frame:NSMakeRect(SPPostgresUsersMargin, buttonY, 28, 23)
									action:@selector(addRole:) identifier:@"usersAdd" toolTip:NSLocalizedString(@"Add a role", @"Postgres users: add tooltip")];
	removeButton = [self _listButtonWithImage:[NSImage imageNamed:NSImageNameRemoveTemplate] title:@"−" frame:NSMakeRect(SPPostgresUsersMargin + 27, buttonY, 28, 23)
									   action:@selector(removeRole:) identifier:@"usersRemove" toolTip:NSLocalizedString(@"Remove the selected role (when you apply)", @"Postgres users: remove tooltip")];
	duplicateButton = [self _listButtonWithImage:[NSImage imageWithSystemSymbolName:@"plus.square.on.square" accessibilityDescription:NSLocalizedString(@"Duplicate", @"Postgres users: duplicate accessibility")]
										   title:@"⧉" frame:NSMakeRect(SPPostgresUsersMargin + 54, buttonY, 28, 23)
										  action:@selector(duplicateRole:) identifier:@"usersDuplicate" toolTip:NSLocalizedString(@"Duplicate the selected role", @"Postgres users: duplicate tooltip")];
	[content addSubview:addButton];
	[content addSubview:removeButton];
	[content addSubview:duplicateButton];

	// Right: General, Membership, Privileges
	CGFloat tabX = SPPostgresUsersMargin + SPPostgresUsersListWidth + 12;
	CGFloat tabBottom = 48;
	tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(tabX, tabBottom, SPPostgresUsersSheetWidth - tabX - SPPostgresUsersMargin + 6, SPPostgresUsersSheetHeight - tabBottom - 12)];
	[tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[tabView setDelegate:self];
	[content addSubview:tabView];
	[self _buildGeneralTab];
	[self _buildMembershipTab];
	[self _buildPrivilegesTab];

	// Bottom right: Cancel, Apply
	cancelButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Cancel", @"cancel button") target:self action:@selector(cancel:)] retain];
	[cancelButton setIdentifier:@"usersCancel"];
	[cancelButton setKeyEquivalent:@"\e"];
	[cancelButton setFrame:NSMakeRect(SPPostgresUsersSheetWidth - SPPostgresUsersMargin - 190, 12, 92, 28)];
	[cancelButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:cancelButton];
	applyButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Apply", @"Postgres users: apply button") target:self action:@selector(apply:)] retain];
	[applyButton setIdentifier:@"usersApply"];
	[applyButton setKeyEquivalent:@"\r"];
	[applyButton setFrame:NSMakeRect(SPPostgresUsersSheetWidth - SPPostgresUsersMargin - 94, 12, 92, 28)];
	[applyButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:applyButton];
	[sheet setDefaultButtonCell:[applyButton cell]];

	NSError *privilegesError = nil;
	if (![privilegesPane startWithDatabase:database connection:[connections objectForKey:database] error:&privilegesError]) {
		[self _showErrorTitle:NSLocalizedString(@"Could not read the privileges", @"Postgres users: privileges read failed title") message:[privilegesError localizedDescription] ?: @""];
	}

	[rolesTable reloadData];
	if ([editedRoles count]) [rolesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[self _selectionDidChange];
}

/// A view for a tab, as big as the tab view's content area.
- (NSView *)_tabContentView
{
	NSRect bounds = [tabView contentRect];
	NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(bounds), NSHeight(bounds))] autorelease];
	[view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	return view;
}

- (void)_buildGeneralTab
{
	NSView *view = [self _tabContentView];
	CGFloat height = NSHeight([view frame]);
	CGFloat labelX = 8, controlX = labelX + SPPostgresUsersLabelWidth + 8;
	CGFloat y = height - 16 - 22;

	[view addSubview:[self _label:NSLocalizedString(@"Role name:", @"Postgres users: role name label") frame:NSMakeRect(labelX, y + 2, SPPostgresUsersLabelWidth, 17)]];
	nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(controlX, y, 240, 22)];
	[self _setupTextField:nameField identifier:@"usersName" placeholder:nil];
	[view addSubview:nameField];

	y -= 32;
	[view addSubview:[self _label:NSLocalizedString(@"Password:", @"Postgres users: password label") frame:NSMakeRect(labelX, y + 2, SPPostgresUsersLabelWidth, 17)]];
	passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(controlX, y, 180, 22)];
	[self _setupTextField:passwordField identifier:@"usersPassword" placeholder:NSLocalizedString(@"unchanged", @"Postgres users: password placeholder")];
	[view addSubview:passwordField];
	clearPasswordCheckbox = [self _checkbox:NSLocalizedString(@"Clear password", @"Postgres users: clear password checkbox") identifier:@"usersClearPassword"
									 frame:NSMakeRect(controlX + 192, y + 2, 150, 18) action:@selector(_clearPasswordChanged:)];
	[view addSubview:clearPasswordCheckbox];

	y -= 32;
	[view addSubview:[self _label:NSLocalizedString(@"Valid until:", @"Postgres users: valid until label") frame:NSMakeRect(labelX, y + 3, SPPostgresUsersLabelWidth, 17)]];
	validUntilCheckbox = [self _checkbox:NSLocalizedString(@"Expires", @"Postgres users: expires checkbox") identifier:@"usersExpires"
								  frame:NSMakeRect(controlX, y + 3, 76, 18) action:@selector(_validUntilChanged:)];
	[view addSubview:validUntilCheckbox];
	validUntilPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(controlX + 80, y, 190, 24)];
	[validUntilPicker setIdentifier:@"usersValidUntil"];
	[validUntilPicker setDatePickerStyle:NSDatePickerStyleTextFieldAndStepper];
	[validUntilPicker setDatePickerElements:NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute];
	[validUntilPicker setTarget:self];
	[validUntilPicker setAction:@selector(_validUntilChanged:)];
	[validUntilPicker setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	[view addSubview:validUntilPicker];

	y -= 32;
	[view addSubview:[self _label:NSLocalizedString(@"Connection limit:", @"Postgres users: connection limit label") frame:NSMakeRect(labelX, y + 2, SPPostgresUsersLabelWidth, 17)]];
	connectionLimitField = [[NSTextField alloc] initWithFrame:NSMakeRect(controlX, y, 110, 22)];
	[self _setupTextField:connectionLimitField identifier:@"usersConnectionLimit" placeholder:NSLocalizedString(@"-1 = unlimited", @"Postgres users: connection limit placeholder")];
	[view addSubview:connectionLimitField];

	// The attributes, in two columns
	y -= 40;
	CGFloat column2 = controlX + 170;
	SEL changed = @selector(_attributeChanged:);
	loginCheckbox = [self _checkbox:NSLocalizedString(@"Can log in", @"Postgres users: login attribute") identifier:@"usersLogin" frame:NSMakeRect(controlX, y, 165, 18) action:changed];
	createRoleCheckbox = [self _checkbox:NSLocalizedString(@"Create roles", @"Postgres users: createrole attribute") identifier:@"usersCreateRole" frame:NSMakeRect(column2, y, 200, 18) action:changed];
	y -= 24;
	inheritCheckbox = [self _checkbox:NSLocalizedString(@"Inherit privileges", @"Postgres users: inherit attribute") identifier:@"usersInherit" frame:NSMakeRect(controlX, y, 165, 18) action:changed];
	replicationCheckbox = [self _checkbox:NSLocalizedString(@"Replication", @"Postgres users: replication attribute") identifier:@"usersReplication" frame:NSMakeRect(column2, y, 200, 18) action:changed];
	y -= 24;
	superuserCheckbox = [self _checkbox:NSLocalizedString(@"Superuser", @"Postgres users: superuser attribute") identifier:@"usersSuperuser" frame:NSMakeRect(controlX, y, 165, 18) action:changed];
	bypassRLSCheckbox = [self _checkbox:NSLocalizedString(@"Bypass row-level security", @"Postgres users: bypassrls attribute") identifier:@"usersBypassRLS" frame:NSMakeRect(column2, y, 200, 18) action:changed];
	y -= 24;
	createDBCheckbox = [self _checkbox:NSLocalizedString(@"Create databases", @"Postgres users: createdb attribute") identifier:@"usersCreateDB" frame:NSMakeRect(controlX, y, 165, 18) action:changed];
	for (NSButton *checkbox in @[loginCheckbox, inheritCheckbox, superuserCheckbox, createDBCheckbox, createRoleCheckbox, replicationCheckbox, bypassRLSCheckbox]) {
		[view addSubview:checkbox];
	}

	NSTabViewItem *item = [[[NSTabViewItem alloc] initWithIdentifier:@"general"] autorelease];
	[item setLabel:NSLocalizedString(@"General", @"Postgres users: general tab")];
	[item setView:view];
	[tabView addTabViewItem:item];
}

/// A pane of the Membership split view: a title above a membership list.
- (NSView *)_membershipPane:(NSString *)title identifier:(NSString *)identifier width:(CGFloat)width table:(NSTableView **)table
{
	CGFloat height = 160;
	NSView *pane = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)] autorelease];
	NSTextField *label = [NSTextField labelWithString:title];
	[label setFrame:NSMakeRect(0, height - 18, width, 17)];
	[label setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[pane addSubview:label];
	NSScrollView *scroll = nil;
	*table = [self _membershipTableWithIdentifier:identifier scrollView:&scroll frame:NSMakeRect(0, 4, width, height - 26)];
	[pane addSubview:scroll];
	return pane;
}

- (void)_buildMembershipTab
{
	NSView *view = [self _tabContentView];
	NSRect frame = NSInsetRect([view bounds], 12, 10);
	NSSplitView *split = [[[NSSplitView alloc] initWithFrame:frame] autorelease];
	[split setVertical:NO];
	[split setDividerStyle:NSSplitViewDividerStyleThin];
	[split setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[split addSubview:[self _membershipPane:NSLocalizedString(@"Member of:", @"Postgres users: member of label") identifier:@"usersMemberOf" width:NSWidth(frame) table:&memberOfTable]];
	[split addSubview:[self _membershipPane:NSLocalizedString(@"Members of this role:", @"Postgres users: members label") identifier:@"usersMembers" width:NSWidth(frame) table:&membersTable]];
	[split adjustSubviews];
	[view addSubview:split];

	NSTabViewItem *item = [[[NSTabViewItem alloc] initWithIdentifier:@"membership"] autorelease];
	[item setLabel:NSLocalizedString(@"Membership", @"Postgres users: membership tab")];
	[item setView:view];
	[tabView addTabViewItem:item];
}

- (void)_buildPrivilegesTab
{
	NSRect bounds = [tabView contentRect];
	NSView *view = [privilegesPane viewWithFrame:NSMakeRect(0, 0, NSWidth(bounds), NSHeight(bounds))];
	NSTabViewItem *item = [[[NSTabViewItem alloc] initWithIdentifier:@"privileges"] autorelease];
	[item setLabel:NSLocalizedString(@"Privileges", @"Postgres users: privileges tab")];
	[item setView:view];
	[tabView addTabViewItem:item];
}

#pragma mark - The draft

- (SPPostgresRole *)_draftRoleNamed:(NSString *)name
{
	for (SPPostgresRole *role in editedRoles) if ([[role name] isEqualToString:name]) return role;
	return nil;
}

- (SPPostgresRole *)_originalOf:(SPPostgresRole *)role
{
	if (![role originalName]) return nil;
	for (SPPostgresRole *original in originalRoles) if ([[original originalName] isEqualToString:[role originalName]]) return original;
	return nil;
}

- (BOOL)_isSessionRole:(SPPostgresRole *)role
{
	return [role originalName] && [[role originalName] isEqualToString:sessionRoleName];
}

/// A name no role has (on the server or in the draft): base, else base2, base3…
- (NSString *)_unusedNameFrom:(NSString *)base
{
	NSMutableSet *used = [NSMutableSet setWithArray:serverRoleNames];
	for (SPPostgresRole *role in editedRoles) if ([role name]) [used addObject:[role name]];
	if (![used containsObject:base]) return base;
	for (NSUInteger i = 2; ; i++) {
		NSString *name = [NSString stringWithFormat:@"%@%lu", base, (unsigned long)i];
		if (![used containsObject:name]) return name;
	}
}

static NSDictionary *SPPostgresUsersRenameKey(NSDictionary *dictionary, NSString *from, NSString *to)
{
	id value = [dictionary objectForKey:from];
	if (!value) return dictionary;
	NSMutableDictionary *renamed = [[dictionary mutableCopy] autorelease];
	[renamed removeObjectForKey:from];
	[renamed setObject:value forKey:to];
	return renamed;
}

static NSDictionary *SPPostgresUsersRemoveKey(NSDictionary *dictionary, NSString *key)
{
	if (![dictionary objectForKey:key]) return dictionary;
	NSMutableDictionary *removed = [[dictionary mutableCopy] autorelease];
	[removed removeObjectForKey:key];
	return removed;
}

/// Renames a draft role, and the memberships that name it (drafts refer to roles by their draft names).
- (void)_renameDraftRole:(SPPostgresRole *)role to:(NSString *)name
{
	NSString *old = [[[role name] copy] autorelease];
	[role setName:name];
	[privilegesPane renameRole:old to:name];
	for (SPPostgresRole *other in editedRoles) {
		[other setMemberOf:SPPostgresUsersRenameKey([other memberOf], old, name)];
		[other setMembers:SPPostgresUsersRenameKey([other members], old, name)];
	}
}

/// Sets (or removes) one membership on both sides of the draft: the member's memberOf and the group's members.
- (void)_setMember:(NSString *)member ofGroup:(NSString *)group isMember:(BOOL)isMember admin:(BOOL)admin
{
	SPPostgresRole *memberRole = [self _draftRoleNamed:member];
	SPPostgresRole *groupRole = [self _draftRoleNamed:group];
	if (memberRole) {
		NSMutableDictionary *memberOf = [[[memberRole memberOf] mutableCopy] autorelease];
		if (isMember) [memberOf setObject:@(admin) forKey:group];
		else [memberOf removeObjectForKey:group];
		[memberRole setMemberOf:memberOf];
	}
	if (groupRole) {
		NSMutableDictionary *members = [[[groupRole members] mutableCopy] autorelease];
		if (isMember) [members setObject:@(admin) forKey:member];
		else [members removeObjectForKey:member];
		[groupRole setMembers:members];
	}
}

- (BOOL)_role:(SPPostgresRole *)role differsFrom:(SPPostgresRole *)original
{
	if (!original) return YES;
	if ([role markedForDeletion]) return YES;
	if (![[role name] isEqualToString:[original name]]) return YES;
	if ([role canLogin] != [original canLogin] || [role inherit] != [original inherit] || [role superuser] != [original superuser]
		|| [role createDB] != [original createDB] || [role createRole] != [original createRole] || [role replication] != [original replication]
		|| [role bypassRLS] != [original bypassRLS]) return YES;
	if ([role connectionLimit] != [original connectionLimit]) return YES;
	if (!SPPostgresUsersSameDate([role validUntil], [original validUntil])) return YES;
	if ([[role newPassword] length] || [role clearPassword]) return YES;
	if (![[role memberOf] isEqualToDictionary:[original memberOf] ?: @{}]) return YES;
	if (![[role members] isEqualToDictionary:[original members] ?: @{}]) return YES;
	return NO;
}

/// The connection limit a field's text means: empty is -1; NO for text that isn't a whole number.
static BOOL SPPostgresUsersParseLimit(NSString *text, NSInteger *limit)
{
	NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (![trimmed length]) {
		*limit = -1;
		return YES;
	}
	NSScanner *scanner = [NSScanner scannerWithString:trimmed];
	NSInteger value = 0;
	if (![scanner scanInteger:&value] || ![scanner isAtEnd]) return NO;
	*limit = value;
	return YES;
}

/// YES when the shown role's text fields hold something not committed yet.
- (BOOL)_fieldsDiffer
{
	if (!shownRole || [shownRole markedForDeletion]) return NO;
	if (![[nameField stringValue] isEqualToString:[shownRole name] ?: @""]) return YES;
	if (![[passwordField stringValue] isEqualToString:[shownRole newPassword] ?: @""]) return YES;
	NSInteger limit = 0;
	if (!SPPostgresUsersParseLimit([connectionLimitField stringValue], &limit) || limit != [shownRole connectionLimit]) return YES;
	return NO;
}

- (BOOL)_hasChanges
{
	if ([self _fieldsDiffer] || [privilegesPane hasPendingEdits]) return YES;
	for (SPPostgresRole *role in editedRoles) {
		if ([self _role:role differsFrom:[self _originalOf:role]]) return YES;
	}
	return NO;
}

/// Takes the shown role's text fields into the draft. NO (the field put back, the error shown) for a name another
/// role in the list has.
- (BOOL)_commitFields
{
	SPPostgresRole *role = shownRole;
	if (!role || [role markedForDeletion] || ![editedRoles containsObject:role]) return YES;

	BOOL ok = YES;
	NSString *name = [[[nameField stringValue] copy] autorelease];
	if (![name isEqualToString:[role name] ?: @""]) {
		SPPostgresRole *other = [self _draftRoleNamed:name];
		if (other && other != role) {
			[nameField setStringValue:[role name] ?: @""];
			[self _showErrorTitle:NSLocalizedString(@"The role wasn't renamed", @"Postgres users: duplicate name title")
						  message:[NSString stringWithFormat:NSLocalizedString(@"There is already a role named “%@”.", @"Postgres users: duplicate name message"), name]];
			ok = NO;
		}
		else {
			[self _renameDraftRole:role to:name];
		}
	}

	NSString *password = [passwordField stringValue];
	[role setNewPassword:[password length] ? password : nil];

	NSInteger limit = 0;
	if (SPPostgresUsersParseLimit([connectionLimitField stringValue], &limit)) [role setConnectionLimit:limit];
	else [connectionLimitField setStringValue:([role connectionLimit] < 0) ? @"" : [NSString stringWithFormat:@"%ld", (long)[role connectionLimit]]];

	[self _reloadRowOf:role]; // its name
	return ok;
}

#pragma mark - Showing a role

/// Redraws one row of the roles list (a full reload during a selection change would undo it).
- (void)_reloadRowOf:(SPPostgresRole *)role
{
	NSUInteger row = [editedRoles indexOfObject:role];
	if (row == NSNotFound || (NSInteger)row >= [rolesTable numberOfRows]) return;
	[rolesTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)_selectionDidChange
{
	SPPostgresRole *selected = [self selectedRole];
	if (selected == shownRole) {
		[self _updateButtons];
		return;
	}
	[self _commitFields];
	[self _showRole:[self selectedRole]];
}

- (void)_showRole:(SPPostgresRole *)role
{
	shownRole = role;
	BOOL editable = role && ![role markedForDeletion];

	[nameField setStringValue:[role name] ?: @""];
	[passwordField setStringValue:[role newPassword] ?: @""];
	[clearPasswordCheckbox setState:[role clearPassword] ? NSControlStateValueOn : NSControlStateValueOff];
	[connectionLimitField setStringValue:(!role || [role connectionLimit] < 0) ? @"" : [NSString stringWithFormat:@"%ld", (long)[role connectionLimit]]];
	[validUntilCheckbox setState:[role validUntil] ? NSControlStateValueOn : NSControlStateValueOff];
	if ([role validUntil]) {
		[validUntilPicker setDateValue:[role validUntil]];
	}
	else {
		// What Expires starts with: a year from today
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDate *today = [calendar startOfDayForDate:[NSDate date]];
		[validUntilPicker setDateValue:[calendar dateByAddingUnit:NSCalendarUnitYear value:1 toDate:today options:0]];
	}

	struct { NSButton *checkbox; BOOL value; } attributes[] = {
		{ loginCheckbox, [role canLogin] }, { inheritCheckbox, [role inherit] }, { superuserCheckbox, [role superuser] },
		{ createDBCheckbox, [role createDB] }, { createRoleCheckbox, [role createRole] }, { replicationCheckbox, [role replication] },
		{ bypassRLSCheckbox, [role bypassRLS] },
	};
	for (size_t i = 0; i < sizeof(attributes) / sizeof(attributes[0]); i++) {
		[attributes[i].checkbox setState:attributes[i].value ? NSControlStateValueOn : NSControlStateValueOff];
		[attributes[i].checkbox setEnabled:editable];
	}
	[nameField setEnabled:editable];
	[passwordField setEnabled:editable && ![role clearPassword]];
	[clearPasswordCheckbox setEnabled:editable];
	[connectionLimitField setEnabled:editable];
	[validUntilCheckbox setEnabled:editable];
	[validUntilPicker setEnabled:editable && [role validUntil] != nil];

	[self _reloadMemberships];
	[privilegesPane showRole:role];
	[self _updateButtons];
}

- (void)_reloadMemberships
{
	NSString *name = [shownRole name];
	NSMutableArray *draftNames = [NSMutableArray array];
	for (SPPostgresRole *role in editedRoles) {
		if ([role name] && role != shownRole) [draftNames addObject:[role name]];
	}
	[draftNames sortUsingSelector:@selector(compare:)];

	// "Member of" also offers the predefined roles (e.g. pg_read_all_data), after the others
	NSMutableArray *predefined = [NSMutableArray array];
	for (NSString *serverName in serverRoleNames) {
		if ([serverName hasPrefix:@"pg_"] && ![draftNames containsObject:serverName] && ![serverName isEqualToString:name]) [predefined addObject:serverName];
	}
	[predefined sortUsingSelector:@selector(compare:)];

	[memberOfCandidates release];
	memberOfCandidates = shownRole ? [[draftNames arrayByAddingObjectsFromArray:predefined] retain] : [@[] retain];
	[membersCandidates release];
	membersCandidates = shownRole ? [draftNames copy] : [@[] retain];
	[memberOfTable reloadData];
	[membersTable reloadData];
}

- (void)_updateButtons
{
	SPPostgresRole *role = [self selectedRole];
	[addButton setEnabled:YES];
	[removeButton setEnabled:role && ![self _isSessionRole:role]];
	[duplicateButton setEnabled:role && ![role markedForDeletion]];
	[applyButton setEnabled:[self _hasChanges]];
}

#pragma mark - Edits

- (void)_fieldChanged:(id)sender
{
	[self _commitFields];
	[self _updateButtons];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _updateButtons];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	[self _commitFields];
	[self _updateButtons];
}

- (void)_attributeChanged:(id)sender
{
	[self _commitFields];
	SPPostgresRole *role = shownRole;
	if (!role || [role markedForDeletion]) return;
	[role setCanLogin:[loginCheckbox state] == NSControlStateValueOn];
	[role setInherit:[inheritCheckbox state] == NSControlStateValueOn];
	[role setSuperuser:[superuserCheckbox state] == NSControlStateValueOn];
	[role setCreateDB:[createDBCheckbox state] == NSControlStateValueOn];
	[role setCreateRole:[createRoleCheckbox state] == NSControlStateValueOn];
	[role setReplication:[replicationCheckbox state] == NSControlStateValueOn];
	[role setBypassRLS:[bypassRLSCheckbox state] == NSControlStateValueOn];
	[self _reloadRowOf:role]; // the subtitle and icon follow login and superuser
	[privilegesPane roleAttributesChanged];
	[self _updateButtons];
}

- (void)_clearPasswordChanged:(id)sender
{
	[self _commitFields];
	SPPostgresRole *role = shownRole;
	if (!role || [role markedForDeletion]) return;
	BOOL clear = [clearPasswordCheckbox state] == NSControlStateValueOn;
	[role setClearPassword:clear];
	[passwordField setEnabled:!clear];
	[self _updateButtons];
}

- (void)_validUntilChanged:(id)sender
{
	[self _commitFields];
	SPPostgresRole *role = shownRole;
	if (!role || [role markedForDeletion]) return;
	BOOL expires = [validUntilCheckbox state] == NSControlStateValueOn;
	[role setValidUntil:expires ? [validUntilPicker dateValue] : nil];
	[validUntilPicker setEnabled:expires];
	[self _updateButtons];
}

- (void)_selectRole:(SPPostgresRole *)role
{
	[rolesTable reloadData];
	NSUInteger row = [editedRoles indexOfObject:role];
	if (row == NSNotFound) return;
	[rolesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[rolesTable scrollRowToVisible:(NSInteger)row];
	[self _selectionDidChange];
}

- (BOOL)selectRoleNamed:(NSString *)name
{
	SPPostgresRole *role = [self _draftRoleNamed:name];
	if (!role) return NO;
	[self _selectRole:role];
	return [self selectedRole] == role;
}

- (void)_focusName
{
	if ([sheet isVisible]) {
		[sheet makeFirstResponder:nameField];
		[[nameField currentEditor] selectAll:nil];
	}
}

- (void)addRole:(id)sender
{
	if (!sheet || finished) return;
	[self _commitFields];
	SPPostgresRole *role = [SPPostgresRole roleWithName:[self _unusedNameFrom:@"new_role"]];
	[editedRoles addObject:role];
	[self _selectRole:role];
	[self _focusName];
}

- (void)duplicateRole:(id)sender
{
	if (!sheet || finished) return;
	[self _commitFields];
	SPPostgresRole *source = [self selectedRole];
	if (!source || [source markedForDeletion]) return;

	// Attributes, connection limit, valid until and "member of"; not the password, members or privileges
	SPPostgresRole *role = [SPPostgresRole roleWithName:[self _unusedNameFrom:[[source name] stringByAppendingString:@"_copy"]]];
	[role setCanLogin:[source canLogin]];
	[role setInherit:[source inherit]];
	[role setSuperuser:[source superuser]];
	[role setCreateDB:[source createDB]];
	[role setCreateRole:[source createRole]];
	[role setReplication:[source replication]];
	[role setBypassRLS:[source bypassRLS]];
	[role setConnectionLimit:[source connectionLimit]];
	[role setValidUntil:[source validUntil]];
	[editedRoles addObject:role];
	for (NSString *group in [source memberOf]) {
		[self _setMember:[role name] ofGroup:group isMember:YES admin:[[[source memberOf] objectForKey:group] boolValue]];
	}
	[self _selectRole:role];
	[self _focusName];
}

- (void)removeRole:(id)sender
{
	if (!sheet || finished) return;
	[self _commitFields];
	SPPostgresRole *role = [self selectedRole];
	if (!role || [self _isSessionRole:role]) return;

	if (![role originalName]) {
		// Not created yet: just goes, with the memberships naming it
		NSUInteger row = [editedRoles indexOfObject:role];
		NSString *name = [role name];
		[[role retain] autorelease];
		shownRole = nil;
		[privilegesPane dropEditsForRole:name];
		[editedRoles removeObject:role];
		for (SPPostgresRole *other in editedRoles) {
			[other setMemberOf:SPPostgresUsersRemoveKey([other memberOf], name)];
			[other setMembers:SPPostgresUsersRemoveKey([other members], name)];
		}
		[rolesTable reloadData];
		if ([editedRoles count]) {
			[rolesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:MIN(row, [editedRoles count] - 1)] byExtendingSelection:NO];
		}
		[self _showRole:[self selectedRole]];
		return;
	}

	// Marked (struck through) until Apply; − again unmarks it. Its privilege edits go either way.
	[role setMarkedForDeletion:![role markedForDeletion]];
	[privilegesPane dropEditsForRole:[role name]];
	[self _reloadRowOf:role];
	[self _showRole:role];
}

#pragma mark - Apply

- (void)apply:(id)sender
{
	if (!sheetOpen || finished || applying) return;
	[lastErrorMessage release];
	lastErrorMessage = nil;

	if (![self _commitFields]) return;
	if (![self _hasChanges]) {
		NSBeep();
		return;
	}

	NSString *title = NSLocalizedString(@"The changes were not applied", @"Postgres users: apply failed title");

	// PostgreSQL clears an MD5 password when its role is renamed (only a NOTICE says so): ask for a new one
	for (SPPostgresRole *role in editedRoles) {
		if (![role originalName] || [role markedForDeletion] || [[role name] isEqualToString:[role originalName]]) continue;
		if ([role canLogin] && [role hasMD5Password] && ![[role newPassword] length] && ![role clearPassword]) {
			[self _selectRole:role];
			[self _showErrorTitle:title message:[NSString stringWithFormat:NSLocalizedString(@"Renaming “%@” clears its MD5 password. Enter a new password for “%@” too.", @"Postgres users: rename clears md5 password"), [role originalName], [role name]]];
			return;
		}
	}

	// 1. The roles and every database-level grant (databases are shared objects), in one transaction
	NSError *error = nil;
	NSArray *statements = [rolesReader statementsForOriginalRoles:originalRoles edited:editedRoles error:&error];
	BOOL roleChanges = [statements count] > 0;
	if (statements) statements = [statements arrayByAddingObjectsFromArray:[privilegesPane databaseStatements]];
	if (!statements || ![rolesReader applyStatements:statements error:&error]) {
		[self _showErrorTitle:title message:[error localizedDescription] ?: @""];
		return;
	}
	[privilegesPane forgetDatabaseEdits];
	appliedRoleChanges = roleChanges;

	// 2. Each database's other edits on its own connection: the document's database first, then the others by name
	NSMutableArray *order = [[[privilegesPane databasesWithPendingStatements] mutableCopy] autorelease];
	if ([order containsObject:database]) {
		[order removeObject:database];
		[order insertObject:database atIndex:0];
	}
	applying = YES;
	[self _applyPrivilegesIn:order done:[NSMutableArray array]];
}

/// Applies the pending privilege edits of each of databases in turn (connecting when needed); closes the sheet once
/// all are saved, or stops at the first failure.
- (void)_applyPrivilegesIn:(NSArray *)databases done:(NSMutableArray *)done
{
	if (finished) return;
	if (![databases count]) {
		applying = NO;
		[self _close:YES];
		return;
	}
	NSString *name = [databases firstObject];
	NSArray *rest = [databases subarrayWithRange:NSMakeRange(1, [databases count] - 1)];
	[self _connectionForDatabase:name completion:^(PGPostgresConnection *connection, NSError *error) {
		if (finished) return;
		NSError *applyError = error;
		if (connection && SPPostgresApplyInTransaction(connection, [privilegesPane statementsForDatabase:name], &applyError)) {
			[privilegesPane forgetEditsInDatabase:name];
			[done addObject:name];
			[self _applyPrivilegesIn:rest done:done];
			return;
		}
		applying = NO;
		NSString *reason = [applyError localizedDescription] ?: NSLocalizedString(@"The connection failed.", @"Postgres users: connection failed, no reason");
		// What was saved first: the roles (when the Apply changed any), then the databases done
		NSString *saved = [done componentsJoinedByString:@", "];
		NSString *message = nil;
		if (appliedRoleChanges && [done count]) {
			message = [NSString stringWithFormat:NSLocalizedString(@"Roles and %@ were saved; changes in %@ were not: %@", @"Postgres users: apply failed in a later database"), saved, name, reason];
		}
		else if (appliedRoleChanges) {
			message = [NSString stringWithFormat:NSLocalizedString(@"Roles were saved; changes in %@ were not: %@", @"Postgres users: apply failed in the first database"), name, reason];
		}
		else if ([done count]) {
			message = [NSString stringWithFormat:NSLocalizedString(@"%@ were saved; changes in %@ were not: %@", @"Postgres users: apply without role changes failed in a later database"), saved, name, reason];
		}
		else {
			message = [NSString stringWithFormat:NSLocalizedString(@"Changes in %@ were not saved: %@", @"Postgres users: apply without role changes failed in the first database"), name, reason];
		}
		[self _reloadAfterPartialApply];
		[self _showErrorTitle:NSLocalizedString(@"Not all changes were applied", @"Postgres users: partial apply title") message:message];
		[self _updateButtons];
	}];
}

/// Re-reads the roles (what the first transaction saved) and the privileges, keeping the edits still pending.
- (void)_reloadAfterPartialApply
{
	NSString *selectedName = [[[[self selectedRole] name] copy] autorelease];
	shownRole = nil;
	NSError *error = nil;
	PGPostgresConnection *connection = [connections objectForKey:database];
	if (!connection || ![self _loadRolesFrom:connection error:&error]) {
		NSLog(@"Postgres users: could not re-read the roles: %@", [error localizedDescription]);
	}
	[rolesTable reloadData];
	[privilegesPane reload];
	SPPostgresRole *role = selectedName ? [self _draftRoleNamed:selectedName] : nil;
	if (!role && [editedRoles count]) role = [editedRoles firstObject];
	if (role) [self _selectRole:role];
	else [self _showRole:nil];
}

#pragma mark - Tables

- (NSString *)subtitleForRole:(SPPostgresRole *)role
{
	if ([role superuser]) return NSLocalizedString(@"superuser", @"Postgres users: superuser role subtitle");
	if ([role isGroup]) return NSLocalizedString(@"group, no login", @"Postgres users: group role subtitle");
	return @"";
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table
{
	if (table == rolesTable) return (NSInteger)[editedRoles count];
	if (table == memberOfTable) return (NSInteger)[memberOfCandidates count];
	if (table == membersTable) return (NSInteger)[membersCandidates count];
	return 0;
}

- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	if (table != rolesTable || row < 0 || row >= (NSInteger)[editedRoles count]) return nil;
	SPPostgresRole *role = [editedRoles objectAtIndex:(NSUInteger)row];
	CGFloat width = [column width];

	NSTableCellView *cell = [[[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, width, 32)] autorelease];
	NSImageView *icon = [[[NSImageView alloc] initWithFrame:NSMakeRect(4, 8, 16, 16)] autorelease];
	[icon setImage:[NSImage imageNamed:[role isGroup] ? NSImageNameUserGroup : NSImageNameUser]];
	[icon setImageScaling:NSImageScaleProportionallyUpOrDown];
	[cell addSubview:icon];
	[cell setImageView:icon];

	NSString *subtitle = [self subtitleForRole:role];
	NSTextField *name = [NSTextField labelWithString:@""];
	[name setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[name setFrame:[subtitle length] ? NSMakeRect(24, 15, width - 28, 16) : NSMakeRect(24, 8, width - 28, 16)];
	[name setAutoresizingMask:NSViewWidthSizable];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:[NSFont systemFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];
	if ([role markedForDeletion]) {
		// As MySQL marks deleted users, until Apply
		[attributes setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
		[attributes setObject:[NSColor secondaryLabelColor] forKey:NSForegroundColorAttributeName];
	}
	[name setAttributedStringValue:[[[NSAttributedString alloc] initWithString:[role name] ?: @"" attributes:attributes] autorelease]];
	[cell addSubview:name];
	[cell setTextField:name];

	NSTextField *detail = [NSTextField labelWithString:subtitle];
	[detail setIdentifier:@"subtitle"];
	[detail setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize] - 1]];
	[detail setTextColor:[NSColor secondaryLabelColor]];
	[detail setFrame:NSMakeRect(24, 2, width - 28, 13)];
	[detail setAutoresizingMask:NSViewWidthSizable];
	[detail setHidden:![subtitle length]];
	[cell addSubview:detail];

	return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == rolesTable) [self _selectionDidChange];
}

/// A membership row can be edited: the shown role and the row's role are both still there (not marked for removal:
/// Apply leaves the memberships of a dropped role alone, so they are shown disabled).
- (BOOL)_membershipRowEditable:(NSTableView *)table row:(NSInteger)row
{
	if (!shownRole || [shownRole markedForDeletion]) return NO;
	NSArray *candidates = (table == memberOfTable) ? memberOfCandidates : membersCandidates;
	if (row < 0 || row >= (NSInteger)[candidates count]) return NO;
	return ![[self _draftRoleNamed:[candidates objectAtIndex:(NSUInteger)row]] markedForDeletion];
}

/// Membership rows: whether the pair exists and with admin option, from the shown role's side.
- (NSNumber *)_membershipForTable:(NSTableView *)table row:(NSInteger)row admin:(BOOL)admin
{
	NSArray *candidates = (table == memberOfTable) ? memberOfCandidates : membersCandidates;
	if (row < 0 || row >= (NSInteger)[candidates count]) return nil;
	NSDictionary *dictionary = (table == memberOfTable) ? [shownRole memberOf] : [shownRole members];
	NSNumber *value = [dictionary objectForKey:[candidates objectAtIndex:(NSUInteger)row]];
	return admin ? @([value boolValue]) : @(value != nil);
}

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	if (table == rolesTable) return nil;
	NSArray *candidates = (table == memberOfTable) ? memberOfCandidates : membersCandidates;
	if (row < 0 || row >= (NSInteger)[candidates count]) return nil;
	NSString *identifier = [column identifier];
	if ([identifier isEqualToString:SPPostgresUsersNameColumn]) return [candidates objectAtIndex:(NSUInteger)row];
	return [self _membershipForTable:table row:row admin:[identifier isEqualToString:SPPostgresUsersAdminColumn]];
}

- (void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	if (table == rolesTable || ![self _membershipRowEditable:table row:row]) return;
	[self _commitFields];
	NSArray *candidates = (table == memberOfTable) ? memberOfCandidates : membersCandidates;
	if (row < 0 || row >= (NSInteger)[candidates count]) return;
	NSString *other = [candidates objectAtIndex:(NSUInteger)row];
	NSString *identifier = [column identifier];

	BOOL isMember = [[self _membershipForTable:table row:row admin:NO] boolValue];
	BOOL admin = [[self _membershipForTable:table row:row admin:YES] boolValue];
	if ([identifier isEqualToString:SPPostgresUsersMemberColumn]) {
		isMember = [object boolValue];
		if (!isMember) admin = NO;
	}
	else if ([identifier isEqualToString:SPPostgresUsersAdminColumn]) {
		admin = [object boolValue];
		if (admin) isMember = YES; // the admin option comes with the membership
	}
	else {
		return;
	}

	if (table == memberOfTable) [self _setMember:[shownRole name] ofGroup:other isMember:isMember admin:admin];
	else [self _setMember:other ofGroup:[shownRole name] isMember:isMember admin:admin];
	[table reloadData];
	[self _updateButtons];
}

- (void)tableView:(NSTableView *)table willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	if (table == rolesTable || ![cell respondsToSelector:@selector(setEnabled:)]) return;
	[cell setEnabled:[self _membershipRowEditable:table row:row]];
}

- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	if (table == rolesTable) return NO;
	return [self _membershipRowEditable:table row:row] && ![[column identifier] isEqualToString:SPPostgresUsersNameColumn];
}

#pragma mark - Privileges

- (NSPopUpButton *)databasePopup { return [privilegesPane databasePopup]; }
- (NSPopUpButton *)schemaPopup { return [privilegesPane schemaPopup]; }
- (NSPopUpButton *)creatorPopup { return [privilegesPane creatorPopup]; }
- (NSTableView *)privilegesTable { return [privilegesPane privilegesTable]; }
- (NSTextField *)superuserNote { return [privilegesPane superuserNote]; }
- (NSArray *)privilegeRowsShown { return [privilegesPane rowsShown]; }

- (NSArray *)pendingPrivilegeEditsInDatabase:(NSString *)theDatabase
{
	return [privilegesPane pendingEditsInDatabase:theDatabase];
}

- (void)privilegesPane:(SPPostgresUsersPrivilegesPane *)pane connectionForDatabase:(NSString *)theDatabase completion:(void (^)(PGPostgresConnection *, NSError *))done
{
	[self _connectionForDatabase:theDatabase completion:done];
}

- (void)privilegesPane:(SPPostgresUsersPrivilegesPane *)pane showErrorTitle:(NSString *)title message:(NSString *)message
{
	if (finished) return;
	[self _showErrorTitle:title message:message];
}

- (void)privilegesPaneWillEdit:(SPPostgresUsersPrivilegesPane *)pane
{
	[self _commitFields];
}

- (void)privilegesPaneDidChange:(SPPostgresUsersPrivilegesPane *)pane
{
	[self _updateButtons];
}

#pragma mark - Tab view

- (BOOL)tabView:(NSTabView *)theTabView shouldSelectTabViewItem:(NSTabViewItem *)item
{
	[self _commitFields];
	return YES;
}

@end
