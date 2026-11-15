#import "SPPostgresTransferController.h"
#import "SPPostgresDocument.h"
#import "SPPostgresSidebarController.h"
#import "SPPostgresCatalog.h"
#import "SPPostgresCheckList.h"
#import "SPPostgresTransfer.h"
#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import "SPPostgresProgressSheet.h"
#import "SPPostgresBackgroundJob.h"
#import "SPPostgresConnector.h"
#import "SPPostgresConsoleLogger.h"
#import "SPPostgresFavorite.h"
#import "SPPostgresFavoritesStore.h"
#import "SPKeychain.h"
#import "SPSSHTunnel.h"
#import <PostgresKit/PostgresKit.h>

static const NSUInteger SPPostgresTransferDefaultPort = 5432;

/// The Empty mode confirmation's text field: enables its button only while it holds exactly the expected name (as
/// typed, or as set by -setStringValue:).
@interface SPPostgresTransferConfirmationField : NSTextField
{
	NSString *expected;
	NSButton *button; // not retained: the alert holds both
}
- (void)setExpected:(NSString *)name button:(NSButton *)theButton;
@end

@implementation SPPostgresTransferConfirmationField

- (void)dealloc
{
	[expected release];
	[super dealloc];
}

- (void)_updateButton
{
	[button setEnabled:expected != nil && [[self stringValue] isEqualToString:expected]];
}

- (void)setExpected:(NSString *)name button:(NSButton *)theButton
{
	[expected release];
	expected = [name copy];
	button = theButton;
	[self _updateButton];
}

- (void)setStringValue:(NSString *)value
{
	[super setStringValue:value];
	[self _updateButton];
}

- (void)textDidChange:(NSNotification *)notification
{
	[super textDidChange:notification];
	[self _updateButton];
}

@end

/// The New Database… prompt's text field: enables its button only while it holds a name PostgreSQL accepts in length
/// (1 to 63 bytes in UTF-8) with no leading or trailing whitespace (never trimmed silently), as typed or as set by
/// -setStringValue:.
@interface SPPostgresTransferNewNameField : NSTextField
{
	NSButton *button; // not retained: the alert holds both
}
- (void)setButton:(NSButton *)theButton;
@end

@implementation SPPostgresTransferNewNameField

- (void)_updateButton
{
	NSString *name = [self stringValue];
	NSUInteger bytes = [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	BOOL trimmed = [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:name];
	[button setEnabled:bytes > 0 && bytes <= 63 && trimmed];
}

- (void)setButton:(NSButton *)theButton
{
	button = theButton;
	[self _updateButton];
}

- (void)setStringValue:(NSString *)value
{
	[super setStringValue:value];
	[self _updateButton];
}

- (void)textDidChange:(NSNotification *)notification
{
	[super textDidChange:notification];
	[self _updateButton];
}

@end

/// The database menu's "New Database…" item
static const NSInteger SPPostgresTransferNewDatabaseTag = 1;

typedef NS_ENUM(NSInteger, SPPostgresTransferTargetState) {
	SPPostgresTransferTargetNone = 0, // no favorite
	SPPostgresTransferTargetConnecting,
	SPPostgresTransferTargetConnected,
	SPPostgresTransferTargetFailed
};

/// Closes a session: its connection, and its token when that can disconnect (the default's connector, which takes
/// its SSH tunnel down with it).
static void SPPostgresTransferCloseSession(PGPostgresConnection *connection, id token)
{
	[connection disconnect];
	if ([token respondsToSelector:@selector(disconnect)]) [token disconnect];
}

/// An SSH tunnel's password or host-key sheet (SPSSHTunnel's SSHQuestionDialog) answered as Cancel/No through its own
/// button's action, so the tunnel's worker, which waits for that answer, carries on. NO for any other window.
static BOOL SPPostgresTransferCancelTunnelSheet(NSWindow *window)
{
	NSMutableArray *views = [NSMutableArray array];
	if ([window contentView]) [views addObject:[window contentView]];
	while ([views count]) {
		NSView *view = [views lastObject];
		[views removeLastObject];
		[views addObjectsFromArray:[view subviews]];
		if (![view isKindOfClass:[NSButton class]]) continue;
		NSButton *button = (NSButton *)view;
		SEL action = [button action];
		// Tag 1 is the tunnel's OK/Yes
		if ((action == @selector(closeSSHPasswordSheet:) || action == @selector(closeSSHQuestionSheet:)) && [button tag] != 1 && [button target]) {
			[NSApp sendAction:action to:[button target] from:button];
			return YES;
		}
	}
	return NO;
}

static BOOL SPPostgresTransferErrorIs(NSError *error, NSInteger code)
{
	return [[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == code;
}

@interface SPPostgresTransferController ()
- (void)_beginProgressTo:(SPPostgresFavorite *)favorite database:(NSString *)targetDatabase mode:(SPPostgresTransferMode)mode tables:(NSArray *)tables;
- (void)_updateControls;
- (void)_applyFilterToPopup:(NSPopUpButton *)popup;
- (void)_finish;
- (void)_closeSession;
@end

@implementation SPPostgresTransferController
{
	SPPostgresDocument *document; // retained until the controller goes away
	NSString *database;

	NSPanel *sheet;
	NSButton *wholeDatabaseRadio;
	NSButton *selectedTablesRadio;
	SPPostgresCheckList *tablesList;
	NSPopUpButton *favoritePopup;
	NSTextField *targetDescriptionField;
	NSPopUpButton *databasePopup;
	NSSearchField *favoriteFilterField;
	NSSearchField *databaseFilterField;
	NSTextField *targetStatusField;
	NSButton *retryButton;
	NSButton *emptyModeRadio;
	NSButton *overwriteModeRadio;
	NSButton *transferButton;
	NSButton *cancelButton;

	NSString *selectedDatabase;

	/// The session to the chosen favorite: lists its databases, creates one, and carries the transfer's connection
	/// (its SSH tunnel and password). Open from choosing the favorite until the controller finishes.
	SPPostgresFavorite *sessionFavorite; // the favorites' element it was opened for
	NSString *sessionPassword; // asked for in this sheet (nil: the Keychain's)
	PGPostgresConnection *sessionConnection;
	id sessionToken;
	SPPostgresConnector *connectingSession; // the default targetConnect's session connector, while it connects
	/// Bumped whenever a session is closed or another opened: older answers are ignored
	NSUInteger sessionGeneration;
	SPPostgresTransferTargetState targetState;
	/// Created in this sheet (on the session's favorite): no Empty mode confirmation for these
	NSMutableSet *createdDatabases;
	/// The password or New Database… prompt is up
	BOOL prompting;
	/// This controller's alerts while they are up as sheets on the Transfer sheet (their windows)
	NSMutableArray *ownAlertWindows;

	SPPostgresProgressSheet *progressSheet;
	SPPostgresBackgroundJob *job;
	SPPostgresConnector *pendingConnector;
	NSString *lastErrorMessage;
	NSString *completionNote;
	/// Runs when the Transfer sheet has ended (it begins the progress sheet)
	void (^afterSheetEnds)(void);
	/// Cancel came after Transfer was clicked but before the progress sheet began
	BOOL cancelRequested;
	BOOL began;
	BOOL finished;
	BOOL running;
	/// Empty mode's confirmation is being asked
	BOOL confirming;
}

@synthesize didEnd;
@synthesize favorites;
@synthesize targetConnect;
@synthesize passwordPrompt;
@synthesize newDatabasePrompt;
@synthesize emptyConfirmation;
@synthesize progressObserver;
@synthesize temporaryDirectory;
@synthesize sheet;
@synthesize wholeDatabaseRadio;
@synthesize selectedTablesRadio;
@synthesize tablesList;
@synthesize favoritePopup;
@synthesize targetDescriptionField;
@synthesize databasePopup;
@synthesize favoriteFilterField;
@synthesize databaseFilterField;
@synthesize targetStatusField;
@synthesize retryButton;
@synthesize selectedDatabase;
@synthesize emptyModeRadio;
@synthesize overwriteModeRadio;
@synthesize transferButton;
@synthesize pendingConnector;
@synthesize progressSheet;
@synthesize lastErrorMessage;
@synthesize completionNote;

- (instancetype)initWithDocument:(SPPostgresDocument *)theDocument
{
	if ((self = [super init])) {
		document = [theDocument retain];
		database = [[theDocument currentDatabase] copy];
		createdDatabases = [[NSMutableSet alloc] init];
		ownAlertWindows = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[tablesList setChecksChanged:nil];
	for (NSControl *control in [NSArray arrayWithObjects:wholeDatabaseRadio, selectedTablesRadio, favoritePopup, databasePopup, favoriteFilterField, databaseFilterField, retryButton, emptyModeRadio, overwriteModeRadio, transferButton, cancelButton, nil]) [control setTarget:nil];
	// Normally closed by -_finish; a connecting session holds the controller, so none is pending here
	SPPostgresTransferCloseSession(sessionConnection, sessionToken);

	[didEnd release];
	[favorites release];
	[targetConnect release];
	[passwordPrompt release];
	[newDatabasePrompt release];
	[emptyConfirmation release];
	[progressObserver release];
	[temporaryDirectory release];
	[sheet release];
	[wholeDatabaseRadio release];
	[selectedTablesRadio release];
	[tablesList release];
	[favoritePopup release];
	[targetDescriptionField release];
	[databasePopup release];
	[favoriteFilterField release];
	[databaseFilterField release];
	[targetStatusField release];
	[retryButton release];
	[selectedDatabase release];
	[sessionFavorite release];
	[sessionPassword release];
	[sessionConnection release];
	[sessionToken release];
	[connectingSession release];
	[createdDatabases release];
	[ownAlertWindows release];
	[emptyModeRadio release];
	[overwriteModeRadio release];
	[transferButton release];
	[cancelButton release];
	[progressSheet release];
	[afterSheetEnds release];
	[job release];
	[pendingConnector release];
	[lastErrorMessage release];
	[completionNote release];
	[database release];
	[document release];
	[super dealloc];
}

- (void)_setLastErrorMessage:(NSString *)message
{
	if (message == lastErrorMessage) return;
	[lastErrorMessage release];
	lastErrorMessage = [message copy];
}

- (void)_setCompletionNote:(NSString *)note
{
	if (note == completionNote) return;
	[completionNote release];
	completionNote = [note copy];
}

- (void)_setPendingConnector:(SPPostgresConnector *)connector
{
	if (connector == pendingConnector) return;
	[pendingConnector release];
	pendingConnector = [connector retain];
}

/// Shows one of this controller's alerts as a sheet on the Transfer sheet (Cancel ends it as its second button).
- (void)_beginAlert:(NSAlert *)alert completion:(void (^)(NSModalResponse response))handler
{
	NSWindow *alertWindow = [alert window];
	[ownAlertWindows addObject:alertWindow];
	void (^theHandler)(NSModalResponse) = [[handler copy] autorelease];
	[alert beginSheetModalForWindow:sheet completionHandler:^(NSModalResponse response) {
		[ownAlertWindows removeObject:alertWindow];
		if (theHandler) theHandler(response);
	}];
}

#pragma mark - Target description

+ (NSString *)targetDescriptionForFavorite:(SPPostgresFavorite *)favorite
{
	if (!favorite) return @"";
	NSString *user = [favorite user] ?: @"";
	if ([favorite type] == SPPostgresSocketConnection) {
		NSString *directory = [[favorite socketPath] length] ? [favorite socketPath] : NSLocalizedString(@"local socket", @"Postgres transfer: target line for a socket favorite without a socket directory");
		return [NSString stringWithFormat:@"%@@%@", user, directory];
	}
	NSString *line = [NSString stringWithFormat:@"%@@%@:%lu", user, [favorite host] ?: @"", (unsigned long)([favorite port] ?: SPPostgresTransferDefaultPort)];
	if ([favorite type] == SPPostgresSSHConnection) {
		line = [NSString stringWithFormat:NSLocalizedString(@"%@ via SSH %@@%@", @"Postgres transfer: target line through an SSH tunnel (user@host:port, SSH user, SSH host)"), line, [favorite sshUser] ?: @"", [favorite sshHost] ?: @""];
	}
	return line;
}

#pragma mark - Building

- (NSTextField *)_labelWithFrame:(NSRect)frame text:(NSString *)text
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	[label setStringValue:text];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setAlignment:NSTextAlignmentRight];
	return label;
}

/// A filter field beside a menu: its action runs as it's typed in.
- (NSSearchField *)_filterFieldWithFrame:(NSRect)frame
{
	NSSearchField *field = [[NSSearchField alloc] initWithFrame:frame];
	[field setPlaceholderString:NSLocalizedString(@"Filter", @"Postgres transfer sheet: placeholder of the fields filtering the target favorite and database menus")];
	[[field cell] setSendsSearchStringImmediately:YES];
	[[field cell] setSendsWholeSearchString:NO];
	[field setTarget:self];
	[field setAction:@selector(_filterChanged:)];
	[field setAutoresizingMask:NSViewMaxYMargin];
	return field;
}

- (NSButton *)_radioWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action on:(BOOL)on
{
	NSButton *radio = [[NSButton alloc] initWithFrame:frame];
	[radio setButtonType:NSButtonTypeRadio];
	[radio setTitle:title];
	[radio setState:on ? NSControlStateValueOn : NSControlStateValueOff];
	[radio setTarget:self];
	[radio setAction:action];
	[radio setAutoresizingMask:NSViewMinYMargin];
	return radio;
}

- (void)_buildSheet
{
	if (sheet) return;

	CGFloat width = 520, height = 500;
	sheet = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[sheet setReleasedWhenClosed:NO];
	[sheet setContentMinSize:NSMakeSize(width, height)];
	[sheet setTitle:NSLocalizedString(@"Transfer", @"Postgres transfer sheet: title")];
	NSView *content = [sheet contentView];

	NSTextField *heading = [self _labelWithFrame:NSMakeRect(20, height - 36, width - 40, 18) text:NSLocalizedString(@"Transfer", @"Postgres transfer sheet: title")];
	[heading setAlignment:NSTextAlignmentLeft];
	[heading setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
	[heading setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:heading];

	// Scope
	wholeDatabaseRadio = [self _radioWithFrame:NSMakeRect(20, height - 66, width - 40, 20)
										 title:[NSString stringWithFormat:NSLocalizedString(@"Whole database “%@”", @"Postgres transfer sheet: scope (database)"), database ?: @""]
										action:@selector(_scopeChanged:) on:YES];
	[content addSubview:wholeDatabaseRadio];
	selectedTablesRadio = [self _radioWithFrame:NSMakeRect(20, height - 90, width - 40, 20) title:NSLocalizedString(@"Selected tables", @"Postgres transfer sheet: scope") action:@selector(_scopeChanged:) on:NO];
	[content addSubview:selectedTablesRadio];

	CGFloat listBottom = 258;
	tablesList = [[SPPostgresCheckList alloc] initWithFrame:NSMakeRect(40, listBottom, width - 60, height - 98 - listBottom) inView:content];
	[tablesList setGroupsByFirstElement:YES];
	// Not capturing self: the list keeps the block, and the controller keeps the list
	__block SPPostgresTransferController *controller = self;
	[tablesList setChecksChanged:^{ [controller _updateControls]; }];

	// Target
	NSTextField *toLabel = [self _labelWithFrame:NSMakeRect(20, 216, 80, 18) text:NSLocalizedString(@"To:", @"Postgres transfer sheet: target favorite label")];
	[toLabel setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:toLabel];
	favoritePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(104, 211, 280, 26) pullsDown:NO];
	[favoritePopup setTarget:self];
	[favoritePopup setAction:@selector(_favoriteChanged:)];
	[favoritePopup setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:favoritePopup];
	favoriteFilterField = [self _filterFieldWithFrame:NSMakeRect(392, 213, width - 20 - 392, 22)];
	[content addSubview:favoriteFilterField];

	targetDescriptionField = [[self _labelWithFrame:NSMakeRect(108, 192, width - 128, 16) text:@""] retain];
	[targetDescriptionField setAlignment:NSTextAlignmentLeft];
	[targetDescriptionField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[targetDescriptionField setTextColor:[NSColor secondaryLabelColor]];
	[targetDescriptionField setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[targetDescriptionField setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
	[content addSubview:targetDescriptionField];

	NSTextField *databaseLabel = [self _labelWithFrame:NSMakeRect(20, 160, 80, 18) text:NSLocalizedString(@"Database:", @"Postgres transfer sheet: target database label")];
	[databaseLabel setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:databaseLabel];
	databasePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(104, 155, 280, 26) pullsDown:NO];
	[[databasePopup menu] setAutoenablesItems:NO];
	[databasePopup setTarget:self];
	[databasePopup setAction:@selector(_databaseChanged:)];
	[databasePopup setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:databasePopup];
	databaseFilterField = [self _filterFieldWithFrame:NSMakeRect(392, 157, width - 20 - 392, 22)];
	[content addSubview:databaseFilterField];

	// The session's error, and Retry next to it
	targetStatusField = [[self _labelWithFrame:NSMakeRect(108, 118, width - 128 - 96, 32) text:@""] retain];
	[targetStatusField setAlignment:NSTextAlignmentLeft];
	[targetStatusField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[targetStatusField setTextColor:[NSColor systemRedColor]];
	[[targetStatusField cell] setWraps:YES];
	[[targetStatusField cell] setTruncatesLastVisibleLine:YES];
	[targetStatusField setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
	[content addSubview:targetStatusField];
	retryButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 20 - 90, 120, 90, 28)];
	[retryButton setBezelStyle:NSBezelStyleRounded];
	[retryButton setTitle:NSLocalizedString(@"Retry", @"Postgres transfer sheet: connect to the target again")];
	[retryButton setTarget:self];
	[retryButton setAction:@selector(_retry:)];
	[retryButton setHidden:YES];
	[retryButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:retryButton];

	// Mode
	emptyModeRadio = [self _radioWithFrame:NSMakeRect(20, 88, width - 40, 20) title:NSLocalizedString(@"Empty the target database first", @"Postgres transfer sheet: mode") action:@selector(_modeChanged:) on:YES];
	[emptyModeRadio setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:emptyModeRadio];
	overwriteModeRadio = [self _radioWithFrame:NSMakeRect(20, 64, width - 40, 20) title:NSLocalizedString(@"Overwrite tables that already exist on the target", @"Postgres transfer sheet: mode") action:@selector(_modeChanged:) on:NO];
	[overwriteModeRadio setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:overwriteModeRadio];

	// Buttons
	transferButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 20 - 100, 12, 100, 32)];
	[transferButton setBezelStyle:NSBezelStyleRounded];
	[transferButton setTitle:NSLocalizedString(@"Transfer", @"Postgres transfer sheet: transfer button")];
	[transferButton setKeyEquivalent:@"\r"];
	[transferButton setTarget:self];
	[transferButton setAction:@selector(transfer:)];
	[transferButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:transferButton];

	cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 20 - 100 - 100, 12, 100, 32)];
	[cancelButton setBezelStyle:NSBezelStyleRounded];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancelButton setKeyEquivalent:@"\e"];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(cancel:)];
	[cancelButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:cancelButton];
}

/// The tables of this tab's database (catalog queries on the tab's connection), preset to the sidebar's selected table;
/// the favorites, the first that isn't this tab's selected. Returns the error reading the tables, if any (the list is
/// then empty).
- (NSError *)_loadContents
{
	SPPostgresCatalog *catalog = [[[SPPostgresCatalog alloc] initWithConnection:[document connection]] autorelease];
	NSError *error = nil;
	NSArray *rows = [SPPostgresCheckList groupedRowsForCatalog:catalog error:&error];
	if (error) [self _setLastErrorMessage:[error localizedDescription]];
	[tablesList setRows:rows ?: @[]];

	SPPostgresSidebarController *sidebar = [document sidebar];
	NSString *selectedSchema = [sidebar selectedSchema];
	NSString *selectedTable = [sidebar selectionIsTable] ? [sidebar selectedTableName] : nil;
	if (selectedTable && selectedSchema && [[tablesList rows] containsObject:@[selectedSchema, selectedTable]]) {
		[tablesList setChecked:YES item:@[selectedSchema, selectedTable]];
	}

	if (!favorites) [self setFavorites:[[SPPostgresFavoritesStore sharedStore] favorites] ?: @[]];

	// addItemWithTitle: would merge favorites with the same name: one menu item per favorite
	[favoritePopup removeAllItems];
	NSString *ownID = [[document favorite] favoriteID];
	NSInteger preselected = -1;
	for (NSUInteger index = 0; index < [favorites count]; index++) {
		SPPostgresFavorite *favorite = [favorites objectAtIndex:index];
		[[favoritePopup menu] addItemWithTitle:[favorite name] ?: @"" action:NULL keyEquivalent:@""];
		BOOL own = [ownID length] && [[favorite favoriteID] isEqualToString:ownID];
		if (preselected < 0 && !own) preselected = (NSInteger)index;
	}
	if ([favorites count]) [favoritePopup selectItemAtIndex:preselected >= 0 ? preselected : 0];
	[self _applyFilterToPopup:favoritePopup];
	[self _showFavorite];
	return error;
}

#pragma mark - Controls

- (SPPostgresFavorite *)_selectedFavorite
{
	NSInteger index = [favoritePopup indexOfSelectedItem];
	return (index >= 0 && (NSUInteger)index < [favorites count]) ? [favorites objectAtIndex:index] : nil;
}

- (BOOL)_wholeDatabase
{
	return [wholeDatabaseRadio state] == NSControlStateValueOn;
}

- (SPPostgresTransferMode)_mode
{
	return [overwriteModeRadio state] == NSControlStateValueOn ? SPPostgresTransferOverwrite : SPPostgresTransferEmptyTarget;
}

- (BOOL)_canTransfer
{
	if (finished || running || confirming) return NO;
	if (prompting || ![self _selectedFavorite] || targetState != SPPostgresTransferTargetConnected || ![selectedDatabase length]) return NO;
	return [self _wholeDatabase] || [[tablesList checkedItems] count] > 0;
}

- (void)_updateControls
{
	[[tablesList tableView] setEnabled:![self _wholeDatabase]];
	[favoritePopup setEnabled:[favorites count] > 0 && !prompting];
	[databasePopup setEnabled:targetState != SPPostgresTransferTargetNone && !prompting];
	[retryButton setHidden:targetState != SPPostgresTransferTargetFailed];
	[transferButton setEnabled:[self _canTransfer]];
}

- (void)_scopeChanged:(id)sender
{
	BOOL whole = (sender == wholeDatabaseRadio);
	[wholeDatabaseRadio setState:whole ? NSControlStateValueOn : NSControlStateValueOff];
	[selectedTablesRadio setState:whole ? NSControlStateValueOff : NSControlStateValueOn];
	[self _updateControls];
}

- (void)_modeChanged:(id)sender
{
	BOOL empty = (sender == emptyModeRadio);
	[emptyModeRadio setState:empty ? NSControlStateValueOn : NSControlStateValueOff];
	[overwriteModeRadio setState:empty ? NSControlStateValueOff : NSControlStateValueOn];
	[self _updateControls];
}

#pragma mark - Filters

/// Hides the names in popup's menu (favorites, or databases) that don't hold its filter field's text; separators,
/// "New Database…" and the disabled state items ("Connecting…", "Not connected") are never hidden. The selected item
/// stays selected (and shown in the button) even when hidden: nothing is chosen, nor connected to, while typing.
- (void)_applyFilterToPopup:(NSPopUpButton *)popup
{
	NSSearchField *field = (popup == favoritePopup) ? favoriteFilterField : databaseFilterField;
	NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	for (NSMenuItem *item in [popup itemArray]) {
		BOOL filtered = [item isSeparatorItem] || [item tag] == SPPostgresTransferNewDatabaseTag || (popup == databasePopup && ![item representedObject]);
		BOOL matches = ![text length] || [[item title] rangeOfString:text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
		[item setHidden:!filtered && !matches];
	}
}

- (void)_filterChanged:(id)sender
{
	[self _applyFilterToPopup:(sender == favoriteFilterField) ? favoritePopup : databasePopup];
}

- (void)_showFavorite
{
	[targetDescriptionField setStringValue:[[self class] targetDescriptionForFavorite:[self _selectedFavorite]]];
}

/// The target line follows the favorite; a session to it replaces the previous favorite's.
- (void)_favoriteChanged:(id)sender
{
	[self _showFavorite];
	SPPostgresFavorite *favorite = [self _selectedFavorite];
	if (favorite == sessionFavorite && targetState != SPPostgresTransferTargetFailed && targetState != SPPostgresTransferTargetNone) {
		[self _updateControls];
		return;
	}
	[self _closeSession];
	[sessionFavorite release];
	sessionFavorite = [favorite retain];
	[sessionPassword release];
	sessionPassword = nil;
	[createdDatabases removeAllObjects];
	[self _openSession];
}

#pragma mark - Session

- (void)_setSelectedDatabase:(NSString *)name
{
	if (name == selectedDatabase) return;
	[selectedDatabase release];
	selectedDatabase = [name copy];
}

/// One disabled item ("Connecting…", "Not connected") or none, and the line under the menu.
- (void)_setTargetState:(SPPostgresTransferTargetState)state message:(NSString *)message
{
	targetState = state;
	[self _setSelectedDatabase:nil];
	[databasePopup removeAllItems];
	NSString *title = nil;
	if (state == SPPostgresTransferTargetConnecting) title = NSLocalizedString(@"Connecting…", @"Postgres transfer sheet: database menu while the target connects");
	else if (state == SPPostgresTransferTargetFailed) title = NSLocalizedString(@"Not connected", @"Postgres transfer sheet: database menu when the target couldn't be connected");
	if (title) {
		NSMenuItem *item = [[databasePopup menu] addItemWithTitle:title action:NULL keyEquivalent:@""];
		[item setEnabled:NO];
		[databasePopup selectItem:item];
	}
	[targetStatusField setStringValue:message ?: @""];
	[self _updateControls];
}

/// The session's databases, a separator and "New Database…"; selects name when listed, else nothing (no database is
/// chosen for the user: Transfer stays disabled until one is picked).
- (void)_showDatabases:(NSArray *)names selecting:(NSString *)name
{
	targetState = SPPostgresTransferTargetConnected;
	[databasePopup removeAllItems];
	NSMenu *menu = [databasePopup menu];
	NSMenuItem *selected = nil;
	for (NSString *each in names) {
		// One item per name (the pop-up's own -addItemWithTitle: would merge equal titles)
		NSMenuItem *item = [menu addItemWithTitle:each action:NULL keyEquivalent:@""];
		[item setRepresentedObject:each];
		if (!selected && [each isEqualToString:name]) selected = item;
	}
	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *newItem = [menu addItemWithTitle:NSLocalizedString(@"New Database…", @"Postgres transfer sheet: database menu item creating a database on the target") action:NULL keyEquivalent:@""];
	[newItem setTag:SPPostgresTransferNewDatabaseTag];
	[self _applyFilterToPopup:databasePopup];
	[databasePopup selectItem:selected];
	[self _setSelectedDatabase:[selected representedObject]];
	[targetStatusField setStringValue:@""];
	[self _updateControls];
}

/// Selects the database name again (after New Database… was cancelled or failed).
- (void)_reselectDatabase:(NSString *)name
{
	NSInteger index = name ? [databasePopup indexOfItemWithRepresentedObject:name] : -1;
	if (index >= 0) [databasePopup selectItemAtIndex:index];
	else [databasePopup selectItem:nil];
	[self _setSelectedDatabase:index >= 0 ? name : nil];
	[self _updateControls];
}

/// Closes the session (and abandons one connecting); answers still on their way are ignored.
- (void)_closeSession
{
	sessionGeneration++;
	SPPostgresConnector *connecting = connectingSession;
	connectingSession = nil;
	[connecting cancel];
	[connecting release];
	PGPostgresConnection *connection = sessionConnection;
	id token = sessionToken;
	sessionConnection = nil;
	sessionToken = nil;
	SPPostgresTransferCloseSession(connection, token);
	[connection release];
	[token release];
}

/// The favorite's database, or postgres when it has none.
- (NSString *)_sessionDatabase
{
	NSString *name = [sessionFavorite database];
	return [name length] ? name : @"postgres";
}

/// Connects the session for sessionFavorite (with sessionPassword, if one was asked for).
- (void)_openSession
{
	[self _closeSession];
	if (!sessionFavorite || finished) {
		[self _setTargetState:SPPostgresTransferTargetNone message:nil];
		return;
	}
	[self _setTargetState:SPPostgresTransferTargetConnecting message:nil];
	NSString *name = [self _sessionDatabase];
	[self _connectSessionTo:name retryOnPostgres:![name isEqualToString:@"postgres"]];
}

- (void)_connectSessionTo:(NSString *)name retryOnPostgres:(BOOL)retry
{
	NSUInteger generation = sessionGeneration;
	[self _connectFavorite:sessionFavorite database:name password:sessionPassword sessionToken:nil completion:^(PGPostgresConnection *connection, id token, NSError *error) {
		if (finished || generation != sessionGeneration) {
			// Another favorite was chosen, or the controller has finished: this answer is too late
			SPPostgresTransferCloseSession(connection, token);
			return;
		}
		if (connection) {
			[self _sessionOpened:connection token:token];
		}
		else if (SPPostgresTransferErrorIs(error, SPPostgresErrorPasswordRequired)) {
			[self _askPasswordAfter:error];
		}
		else if (retry && !SPPostgresTransferErrorIs(error, SPPostgresErrorSSHTunnelFailed) && !SPPostgresTransferErrorIs(error, SPPostgresErrorCancelled)) {
			// The favorite's database may be gone: postgres usually isn't
			[self _connectSessionTo:@"postgres" retryOnPostgres:NO];
		}
		else {
			[self _setTargetState:SPPostgresTransferTargetFailed message:[error localizedDescription]];
		}
	}];
}

- (void)_sessionOpened:(PGPostgresConnection *)connection token:(id)token
{
	sessionConnection = [connection retain];
	sessionToken = [token retain];
	NSError *error = nil;
	SPPostgresCatalog *catalog = [[[SPPostgresCatalog alloc] initWithConnection:connection] autorelease];
	NSArray *names = [catalog databaseNames:&error];
	if (!names) {
		[self _closeSession];
		[self _setTargetState:SPPostgresTransferTargetFailed message:[error localizedDescription]];
		return;
	}
	[self _showDatabases:names selecting:[sessionFavorite database]];
}

/// The server wants a password: ask (once per failed attempt); Cancel leaves "Not connected" with Retry.
- (void)_askPasswordAfter:(NSError *)error
{
	NSUInteger generation = sessionGeneration;
	SPPostgresFavorite *favorite = [[sessionFavorite retain] autorelease];
	NSString *message = [[[error localizedDescription] copy] autorelease];
	prompting = YES;
	[self _updateControls];
	__block BOOL answered = NO;
	void (^answer)(NSString *) = [[^(NSString *password) {
		if (answered) return;
		answered = YES;
		prompting = NO;
		if (finished || generation != sessionGeneration) return;
		if (!password) {
			[self _setTargetState:SPPostgresTransferTargetFailed message:message];
			return;
		}
		// For this sheet's session and transfer only: never saved
		[sessionPassword release];
		sessionPassword = [password copy];
		[self _setTargetState:SPPostgresTransferTargetConnecting message:nil];
		NSString *name = [self _sessionDatabase];
		[self _connectSessionTo:name retryOnPostgres:![name isEqualToString:@"postgres"]];
	} copy] autorelease];

	if (passwordPrompt) {
		passwordPrompt(favorite, answer);
		return;
	}
	NSAlert *alert = [self passwordAlertForFavorite:favorite];
	NSTextField *field = (NSTextField *)[alert accessoryView];
	[self _beginAlert:alert completion:^(NSModalResponse response) {
		answer(response == NSAlertFirstButtonReturn ? [[[field stringValue] copy] autorelease] : nil);
	}];
	[[alert window] makeFirstResponder:field];
}

- (void)_retry:(id)sender
{
	if (finished || targetState != SPPostgresTransferTargetFailed) return;
	[self _openSession];
}

- (NSAlert *)passwordAlertForFavorite:(SPPostgresFavorite *)favorite
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Password for %@ on “%@”", @"Postgres transfer: password prompt title (user, favorite)"), [favorite user] ?: @"", [favorite name] ?: @""]];
	[alert setInformativeText:NSLocalizedString(@"The server asked for a password. It is used for this transfer only and isn't saved.", @"Postgres transfer: password prompt text")];
	[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Postgres transfer: password prompt button")];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];
	NSSecureTextField *field = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease];
	[alert setAccessoryView:field];
	return alert;
}

#pragma mark - Target database

- (void)_databaseChanged:(id)sender
{
	NSMenuItem *item = [databasePopup selectedItem];
	if ([item tag] == SPPostgresTransferNewDatabaseTag) {
		[self _newDatabase];
		return;
	}
	[self _setSelectedDatabase:[item representedObject]];
	[self _updateControls];
}

- (void)_newDatabase
{
	NSString *previous = [[selectedDatabase copy] autorelease];
	if (targetState != SPPostgresTransferTargetConnected || prompting || finished) {
		[self _reselectDatabase:previous];
		return;
	}
	NSUInteger generation = sessionGeneration;
	SPPostgresFavorite *favorite = [[sessionFavorite retain] autorelease];
	prompting = YES;
	[self _updateControls];
	__block BOOL answered = NO;
	void (^answer)(NSString *) = [[^(NSString *name) {
		if (answered) return;
		answered = YES;
		prompting = NO;
		if (finished || generation != sessionGeneration) return;
		if (![name length]) {
			[self _reselectDatabase:previous];
			return;
		}
		[self _createDatabase:name favorite:favorite previous:previous];
	} copy] autorelease];

	if (newDatabasePrompt) {
		newDatabasePrompt(favorite, answer);
		return;
	}
	NSAlert *alert = [self createDatabaseAlertForFavorite:favorite];
	NSTextField *field = (NSTextField *)[alert accessoryView];
	[self _beginAlert:alert completion:^(NSModalResponse response) {
		answer(response == NSAlertFirstButtonReturn ? [[[field stringValue] copy] autorelease] : nil);
	}];
	[[alert window] makeFirstResponder:field];
}

/// CREATE DATABASE on the session (the server's default template and encoding, owned by the favorite's user), then
/// the menu again with it selected. A server error is shown and the previous selection comes back.
- (void)_createDatabase:(NSString *)name favorite:(SPPostgresFavorite *)favorite previous:(NSString *)previous
{
	SPPostgresCatalog *catalog = [[[SPPostgresCatalog alloc] initWithConnection:sessionConnection] autorelease];
	NSError *error = nil;
	if (![catalog createDatabase:name error:&error]) {
		[self _reselectDatabase:previous];
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"“%@” couldn't be created on “%@”", @"Postgres transfer: CREATE DATABASE failed (database, favorite)"), name, [favorite name] ?: @""]];
		[alert setInformativeText:[error localizedDescription] ?: @""];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
		// On the sheet (no presenter set); otherwise as the document shows its alerts
		if ([sheet sheetParent] && ![document alertPresenter]) [self _beginAlert:alert completion:nil];
		else [document presentAlert:alert];
		return;
	}
	[createdDatabases addObject:name];
	NSArray *names = [catalog databaseNames:&error];
	if (!names) {
		// Listed before, so the menu's names plus the new one
		NSMutableArray *listed = [NSMutableArray array];
		for (NSMenuItem *item in [databasePopup itemArray]) if ([item representedObject]) [listed addObject:[item representedObject]];
		if (![listed containsObject:name]) [listed addObject:name];
		names = [listed sortedArrayUsingSelector:@selector(compare:)];
	}
	[self _showDatabases:names selecting:name];
}

- (NSAlert *)createDatabaseAlertForFavorite:(SPPostgresFavorite *)favorite
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"New database on “%@”", @"Postgres transfer: New Database… prompt title (favorite)"), [favorite name] ?: @""]];
	[alert setInformativeText:NSLocalizedString(@"The database is created now, owned by the favorite's user, with the server's default template and encoding.", @"Postgres transfer: New Database… prompt text")];
	NSButton *create = [alert addButtonWithTitle:NSLocalizedString(@"Create", @"Postgres transfer: New Database… prompt button")];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];
	SPPostgresTransferNewNameField *field = [[[SPPostgresTransferNewNameField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease];
	[field setButton:create];
	[alert setAccessoryView:field];
	return alert;
}

#pragma mark - Target connections

/// targetConnect, or the default (see the property).
- (void)_connectFavorite:(SPPostgresFavorite *)favorite database:(NSString *)name password:(NSString *)password sessionToken:(id)token completion:(void (^)(PGPostgresConnection *, id, NSError *))completion
{
	if (targetConnect) {
		targetConnect(favorite, name, password, token, completion);
		return;
	}
	void (^done)(PGPostgresConnection *, id, NSError *) = [[completion copy] autorelease];
	SPPostgresFavorite *target = [[favorite copy] autorelease];
	[target setDatabase:name];
	NSString *favoriteName = [[([favorite name] ?: @"") copy] autorelease];

	if (!token) {
		// The session: the Keychain's password (read now) unless one was asked for; its SSH prompts on this sheet.
		// The Keychain items are named after the favorite as saved (its database included)
		NSString *thePassword = password;
		if (![thePassword length]) {
			SPKeychain *keychain = [[[SPKeychain alloc] init] autorelease];
			thePassword = [keychain getPasswordForName:[favorite keychainName] account:[favorite keychainAccount]];
		}
		SPPostgresConnector *connector = [[[SPPostgresConnector alloc] initWithFavorite:target password:[thePassword length] ? thePassword : nil sshPassword:nil parentWindow:sheet] autorelease];
		[connectingSession release];
		connectingSession = [connector retain];
		[connector connectWithCompletion:^(PGPostgresConnection *connection, NSError *error) {
			if (connectingSession == connector) {
				[connectingSession autorelease];
				connectingSession = nil;
			}
			if (connection) {
				// Its statements go to the Console under the favorite's name
				SPPostgresConsoleLogger *logger = [[[SPPostgresConsoleLogger alloc] initWithConnectionName:favoriteName database:name] autorelease];
				[logger attachToConnection:connection];
			}
			done(connection, connection ? connector : nil, error);
		}];
		return;
	}

	// The transfer's connection: through the session's SSH tunnel, with its password; kept until the job ends
	NSString *thePassword = [password length] ? password : ([token isKindOfClass:[SPPostgresConnector class]] ? [(SPPostgresConnector *)token password] : nil);
	SPPostgresConnector *connector = [token isKindOfClass:[SPPostgresConnector class]]
		? [[[SPPostgresConnector alloc] initWithFavorite:target password:thePassword sharingTunnelOf:token] autorelease]
		: [[[SPPostgresConnector alloc] initWithFavorite:target password:thePassword sshPassword:nil parentWindow:nil] autorelease];
	[self _setPendingConnector:connector];
	[connector connectWithCompletion:^(PGPostgresConnection *connection, NSError *error) {
		if (connection) {
			// Its statements go to the Console under the target favorite's name (COPY data never does)
			SPPostgresConsoleLogger *logger = [[[SPPostgresConsoleLogger alloc] initWithConnectionName:favoriteName database:name] autorelease];
			[logger attachToConnection:connection];
			[SPPostgresBackgroundJob keepOwner:connector untilJobEndsOnConnection:connection];
		}
		if (pendingConnector == connector) [self _setPendingConnector:nil];
		done(connection, token, error);
	}];
}

#pragma mark - Sheet

- (void)beginSheet
{
	NSWindow *window = [document parentWindow];
	if (began || !window || [window attachedSheet]) {
		began = YES;
		[self _finish];
		return;
	}
	began = YES;
	[self retain]; // until -_finish

	[self _buildSheet];
	NSError *tablesError = [self _loadContents];
	[self _updateControls];
	[window beginSheet:sheet completionHandler:^(NSModalResponse response) {
		void (^next)(void) = [afterSheetEnds autorelease];
		afterSheetEnds = nil;
		if (next) next();
	}];
	// The session to the chosen favorite (its SSH prompts, if any, on this sheet)
	[self _favoriteChanged:nil];

	// The tables couldn't be read: say why, rather than show an empty list. On the sheet (no presenter set);
	// otherwise as the document shows its alerts
	if (tablesError) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"The tables couldn't be read", @"Postgres transfer: error title, the tables list failed to load")];
		[alert setInformativeText:[tablesError localizedDescription] ?: @""];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
		if ([sheet sheetParent] && ![document alertPresenter]) [self _beginAlert:alert completion:nil];
		else [document presentAlert:alert];
	}
}

/// Takes the sheet off the window (the controller stays).
- (void)_endSheet
{
	if ([sheet sheetParent]) [[sheet sheetParent] endSheet:sheet];
	[sheet orderOut:nil];
}

- (IBAction)cancel:(id)sender
{
	if (finished) return;
	if (running) {
		// The job sees it and stops (the target's transaction rolls back), then the controller ends
		if (progressSheet) {
			[progressSheet cancel:nil];
			return;
		}
		// The Transfer sheet is still ending: the progress sheet and the job never begin
		cancelRequested = YES;
		running = NO;
		[afterSheetEnds release];
		afterSheetEnds = nil;
		[self _finish];
		return;
	}
	NSWindow *attached = [sheet attachedSheet];
	if (attached && [ownAlertWindows containsObject:attached]) {
		// The confirmation, a prompt or an error of this controller ends as Cancel (its answer is ignored once finished)
		[sheet endSheet:attached returnCode:NSAlertSecondButtonReturn];
	}
	else if (attached) {
		// The session's SSH password or host-key sheet: answered as Cancel through the tunnel, so its worker stops
		// waiting; then the connecting session (and its tunnel) is cancelled
		SPPostgresTransferCancelTunnelSheet(attached);
	}
	[self _closeSession];
	// Anything else still on the sheet
	attached = [sheet attachedSheet];
	if (attached) {
		[sheet endSheet:attached];
		[attached orderOut:nil];
	}
	[self _endSheet];
	[self _finish];
}

- (void)_finish
{
	if (finished) return;
	finished = YES;
	[self _endSheet];
	// After any job has ended: the transfer's connection used the session's tunnel
	[self _closeSession];

	void (^theDidEnd)(void) = [didEnd autorelease];
	didEnd = nil; // it may hold the document, which holds this controller
	if (theDidEnd) theDidEnd();
	if (began && sheet) [self autorelease]; // balances -beginSheet's retain
}

#pragma mark - Confirmation

- (NSAlert *)emptyConfirmationAlertForDatabase:(NSString *)theDatabase targetDescription:(NSString *)description
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Empty “%@” and transfer into it?", @"Postgres transfer: empty confirmation title (database)"), theDatabase ?: @""]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Everything in database “%@” on %@ will be deleted: all schemas (including public), tables, views, functions, types and extensions. Other databases on that server aren't touched.\n\nType the database's name to confirm.", @"Postgres transfer: empty confirmation text (database, target description)"), theDatabase ?: @"", description ?: @""]];
	NSButton *confirm = [alert addButtonWithTitle:NSLocalizedString(@"Empty and Transfer", @"Postgres transfer: empty confirmation button")];
	[confirm setHasDestructiveAction:YES];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];

	SPPostgresTransferConfirmationField *field = [[[SPPostgresTransferConfirmationField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease];
	[field setPlaceholderString:theDatabase];
	[field setExpected:theDatabase button:confirm];
	[alert setAccessoryView:field];
	return alert;
}

#pragma mark - Transferring

- (IBAction)transfer:(id)sender
{
	if (![self _canTransfer]) return;

	SPPostgresFavorite *favorite = [[[self _selectedFavorite] copy] autorelease];
	NSString *targetDatabase = [[selectedDatabase copy] autorelease];
	SPPostgresTransferMode mode = [self _mode];
	NSArray *tables = [self _wholeDatabase] ? nil : [[[tablesList checkedItems] copy] autorelease];

	// A database created in this sheet has nothing to lose: no confirmation
	if (mode != SPPostgresTransferEmptyTarget || [createdDatabases containsObject:targetDatabase]) {
		[self _startTransferTo:favorite database:targetDatabase mode:mode tables:tables];
		return;
	}

	// Empty mode: confirmed first, before the transfer's connections are opened
	confirming = YES;
	[self _updateControls];
	__block BOOL answered = NO;
	void (^answer)(BOOL) = [[^(BOOL confirmed) {
		if (answered) return;
		answered = YES;
		confirming = NO;
		if (finished) return;
		if (confirmed) [self _startTransferTo:favorite database:targetDatabase mode:mode tables:tables];
		else [self _updateControls];
	} copy] autorelease];

	// Names the favorite and where it points: “<favorite>” (user@host:port…)
	NSString *description = [NSString stringWithFormat:NSLocalizedString(@"“%@” (%@)", @"Postgres transfer: empty confirmation's target (favorite name, target line)"), [favorite name] ?: @"", [[self class] targetDescriptionForFavorite:favorite]];
	if (emptyConfirmation) {
		emptyConfirmation(targetDatabase, description, answer);
		return;
	}
	NSAlert *alert = [self emptyConfirmationAlertForDatabase:targetDatabase targetDescription:description];
	[self _beginAlert:alert completion:^(NSModalResponse response) {
		answer(response == NSAlertFirstButtonReturn);
	}];
	[[alert window] makeFirstResponder:[alert accessoryView]];
}

static NSError *SPPostgresTransferCancelledError(void)
{
	return SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The transfer was cancelled.", @"Postgres transfer: cancelled"), nil);
}

- (void)_startTransferTo:(SPPostgresFavorite *)favorite database:(NSString *)targetDatabase mode:(SPPostgresTransferMode)mode tables:(NSArray *)tables
{
	running = YES;
	[self _setLastErrorMessage:nil];
	[self _setCompletionNote:nil];

	// The progress sheet begins once the Transfer sheet has ended (AppKit queues a sheet begun while another is attached)
	void (^next)(void) = ^{
		[self _beginProgressTo:favorite database:targetDatabase mode:mode tables:tables];
	};
	if ([sheet sheetParent]) {
		[afterSheetEnds release];
		afterSheetEnds = [next copy];
		[self _endSheet];
	} else {
		[self _endSheet];
		next();
	}
}

- (void)_beginProgressTo:(SPPostgresFavorite *)favorite database:(NSString *)targetDatabase mode:(SPPostgresTransferMode)mode tables:(NSArray *)tables
{
	if (finished || cancelRequested) return;
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Transferring “%@” to “%@”…", @"Postgres transfer: progress title (source database, target database)"), database, targetDatabase];
	[progressSheet release];
	progressSheet = [[SPPostgresProgressSheet beginOnWindow:[document parentWindow] title:title] retain];
	SPPostgresProgressSheet *progress = progressSheet;
	[progress setStatus:NSLocalizedString(@"Connecting…", @"Postgres transfer: progress status while connecting") fraction:0];
	NSWindow *progressWindow = [progress panel];

	// The job's blocks hold the controller only while the job runs (it lets go of them when it ends)
	SPPostgresConnectionProvider sourceProvider = [document connectionProviderForJobWithSheetWindow:^NSWindow *{
		return progressWindow;
	} connecting:^(SPPostgresConnector *connector) {
		[self _setPendingConnector:connector];
	}];
	// The target through the session (its SSH tunnel and password: no prompt), which stays open until the job ends
	id token = [[sessionToken retain] autorelease];
	NSString *password = [[sessionPassword copy] autorelease];
	SPPostgresConnectionProvider targetProvider = ^(NSString *theDatabase, void (^completion)(PGPostgresConnection *, NSError *)) {
		void (^done)(PGPostgresConnection *, NSError *) = [[completion copy] autorelease];
		[self _connectFavorite:favorite database:theDatabase password:password sessionToken:token completion:^(PGPostgresConnection *connection, id theToken, NSError *error) {
			done(connection, error);
		}];
	};

	// Cleared by the progress sheet's -end: not capturing self
	__block SPPostgresTransferController *controller = self;
	[progress setCancelHandler:^{
		// While connecting: the job ends at once. Once it runs: the engine sees the sheet's flag, and the statements
		// both connections are running are interrupted
		SPPostgresBackgroundJob *theJob = controller->job;
		SPPostgresConnector *connecting = [theJob waitingForConnection] ? [[controller->pendingConnector retain] autorelease] : nil;
		[theJob cancel];
		[connecting cancel];
	}];

	NSString *directory = [[temporaryDirectory copy] autorelease];
	void (^observer)(SPPostgresProgressSheet *) = [[progressObserver copy] autorelease];
	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	BOOL (^work)(PGPostgresConnection *, PGPostgresConnection *, NSError **) = ^BOOL(PGPostgresConnection *source, PGPostgresConnection *target, NSError **error) {
		if ([progress cancelled]) {
			if (error) *error = SPPostgresTransferCancelledError();
			return NO;
		}
		SPPostgresTransfer *transfer = [[[SPPostgresTransfer alloc] initWithSource:source target:target] autorelease];
		if (tables) [transfer setTables:tables];
		else [transfer setWholeDatabase:YES];
		[transfer setMode:mode];
		if (directory) [transfer setTemporaryDirectory:directory];
		__block SPPostgresTransfer *engine = transfer; // the engine keeps the block
		[transfer setProgress:^BOOL(SPPostgresTransferPhase phase, double fraction, NSString *detail) {
			NSString *status = nil;
			double bar = 0;
			switch (phase) {
				case SPPostgresTransferChecking:
					status = NSLocalizedString(@"Checking the target…", @"Postgres transfer: progress status");
					break;
				case SPPostgresTransferReading:
					status = [NSString stringWithFormat:NSLocalizedString(@"Reading table %lu of %lu: %@", @"Postgres transfer: progress status (index, count, table)"), (unsigned long)[engine readingTableIndex], (unsigned long)[engine readingTableCount], detail ?: @""];
					bar = fraction * 0.5;
					break;
				case SPPostgresTransferWriting:
					status = [NSString stringWithFormat:NSLocalizedString(@"Writing to “%@”…", @"Postgres transfer: progress status (target database)"), targetDatabase];
					bar = 0.5 + fraction * 0.5;
					break;
			}
			[progress setStatus:status fraction:bar];
			if (observer) observer(progress);
			return ![progress cancelled];
		}];
		BOOL ok = [transfer run:error];
		[transfer setProgress:nil];
		if (ok) {
			// Read on the main thread once the job has ended
			[results setObject:@([transfer tablesCopied]) forKey:@"tablesCopied"];
			[results setObject:[transfer replacedObjects] ?: @[] forKey:@"replacedObjects"];
			[results setObject:[transfer dependenciesCreated] ?: @[] forKey:@"dependenciesCreated"];
			[results setObject:[transfer foreignTablesSkipped] ?: @[] forKey:@"foreignTablesSkipped"];
			[results setObject:[transfer skippedSettings] ?: @[] forKey:@"skippedSettings"];
		}
		return ok;
	};

	NSString *favoriteName = [favorite name] ?: @"";
	[job release];
	job = [[SPPostgresBackgroundJob runOnDatabase:database provider:sourceProvider targetDatabase:targetDatabase targetProvider:targetProvider work:work completion:^(BOOL ok, NSError *error) {
		// Whatever failed after Cancel (e.g. the statement the cancel interrupted) is the cancel
		NSError *outcome = error;
		if (!ok && [progress cancelled] && !([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorCancelled)) {
			outcome = SPPostgresTransferCancelledError();
		}
		[self _jobEndedWithSuccess:ok error:outcome results:results database:targetDatabase favoriteName:favoriteName];
	}] retain];
}

/// "“<db>” on “<favorite>”"
static NSString *SPPostgresTransferPlace(NSString *targetDatabase, NSString *favoriteName)
{
	return [NSString stringWithFormat:NSLocalizedString(@"“%@” on “%@”", @"Postgres transfer: target database on favorite"), targetDatabase, favoriteName];
}

/// "Copied <n> tables to “<db>” on “<favorite>”." and, when any, what was replaced, created, left out or skipped.
- (NSString *)_completionNoteForResults:(NSDictionary *)results database:(NSString *)targetDatabase favoriteName:(NSString *)favoriteName
{
	NSUInteger count = [[results objectForKey:@"tablesCopied"] unsignedIntegerValue];
	NSString *place = SPPostgresTransferPlace(targetDatabase, favoriteName);
	NSMutableArray *lines = [NSMutableArray array];
	[lines addObject:(count == 1)
		? [NSString stringWithFormat:NSLocalizedString(@"Copied 1 table to %@.", @"Postgres transfer: completion (target)"), place]
		: [NSString stringWithFormat:NSLocalizedString(@"Copied %lu tables to %@.", @"Postgres transfer: completion (count, target)"), (unsigned long)count, place]];

	NSArray *replaced = [results objectForKey:@"replacedObjects"];
	if ([replaced count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Replaced: %@.", @"Postgres transfer: completion, objects replaced on the target"), [replaced componentsJoinedByString:@", "]]];
	NSArray *created = [results objectForKey:@"dependenciesCreated"];
	if ([created count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Also created, as the tables need them: %@.", @"Postgres transfer: completion, dependencies created"), [created componentsJoinedByString:@", "]]];
	NSArray *foreign = [results objectForKey:@"foreignTablesSkipped"];
	if ([foreign count]) {
		NSMutableArray *names = [NSMutableArray array];
		for (NSArray *pair in foreign) [names addObject:[NSString stringWithFormat:@"%@.%@", SPPostgresQuoteIdentifier([pair objectAtIndex:0]), SPPostgresQuoteIdentifier([pair objectAtIndex:1])]];
		[lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Foreign tables aren't copied (nor their servers and user mappings): %@.", @"Postgres transfer: completion, foreign tables left out"), [names componentsJoinedByString:@", "]]];
	}
	NSArray *settings = [results objectForKey:@"skippedSettings"];
	if ([settings count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Settings the target doesn't know were skipped: %@.", @"Postgres transfer: completion, settings skipped"), [settings componentsJoinedByString:@", "]]];
	return [lines componentsJoinedByString:@"\n\n"];
}

- (void)_jobEndedWithSuccess:(BOOL)ok error:(NSError *)error results:(NSDictionary *)results database:(NSString *)targetDatabase favoriteName:(NSString *)favoriteName
{
	if (finished) return;
	[progressSheet end];
	[job release];
	job = nil;
	[self _setPendingConnector:nil];
	running = NO;

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	if (ok) {
		[self _setCompletionNote:[self _completionNoteForResults:results database:targetDatabase favoriteName:favoriteName]];
		[alert setMessageText:NSLocalizedString(@"Transfer complete", @"Postgres transfer: success title")];
		[alert setInformativeText:completionNote];
	}
	else if ([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorCancelled) {
		// A cancel isn't an error: nothing to show (the target's transaction, if any, rolled back)
		[self _setLastErrorMessage:[error localizedDescription] ?: [SPPostgresTransferCancelledError() localizedDescription]];
		alert = nil;
	}
	else {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The transfer failed. %@ wasn't changed.", @"Postgres transfer: failure title (target)"), SPPostgresTransferPlace(targetDatabase, favoriteName)];
		NSMutableString *text = [NSMutableString stringWithString:[error localizedDescription] ?: @""];
		NSArray *dependents = [[error userInfo] objectForKey:SPPostgresDependentsErrorKey];
		if ([dependents count]) {
			[text appendFormat:@"\n\n%@\n%@", NSLocalizedString(@"In the way:", @"Postgres transfer: failure, the target's objects depending on objects the transfer would replace"), [dependents componentsJoinedByString:@"\n"]];
		}
		[self _setLastErrorMessage:[NSString stringWithFormat:@"%@\n\n%@", message, text]];
		[alert setMessageText:message];
		[alert setInformativeText:text];
	}
	if (alert) {
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
		// As the document shows its alerts: never dropped, it waits while the tab isn't shown
		[document presentAlert:alert];
	}
	[self _finish];
}

@end
