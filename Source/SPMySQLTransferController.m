//
//  SPMySQLTransferController.m
//  Sequel Plus
//

#import "SPMySQLTransferController.h"
#import "SPMySQLTransfer.h"
#import "SPMySQLFavoriteConnector.h"
#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "SPTablesList.h"
#import "SPConstants.h"
#import "SPSSHTunnel.h"
#import "Postgres/SPPostgresProgressSheet.h"
#import "Postgres/SPPostgresCheckList.h"
#import <SPMySQL/SPMySQL.h>

/// The "New Database…" item of the Database: menu
static const NSInteger SPMySQLTransferNewDatabaseTag = 1;
/// How long typing in a filter pauses before its menu opens
static const NSTimeInterval SPMySQLTransferFilterMenuDelay = 0.5;

typedef NS_ENUM(NSInteger, SPMySQLTransferTargetState) {
	SPMySQLTransferTargetNone = 0,
	SPMySQLTransferTargetConnecting,
	SPMySQLTransferTargetConnected,
	SPMySQLTransferTargetFailed
};

/// The task list, in order
enum {
	SPMySQLTransferTaskConnect = 0,
	SPMySQLTransferTaskCheck,
	SPMySQLTransferTaskRead,
	SPMySQLTransferTaskCreate,
	SPMySQLTransferTaskCopy,
	SPMySQLTransferTaskSwap,
	SPMySQLTransferTaskFinish,
	SPMySQLTransferTaskCount
};

/// The databases a server keeps for itself (never offered as a target)
static NSSet *SPMySQLTransferSystemDatabases(void)
{
	return [NSSet setWithObjects:@"information_schema", @"mysql", @"performance_schema", @"sys", nil];
}

static NSString *SPMySQLTransferCount(unsigned long long count, NSString *one, NSString *many)
{
	NSString *number = [NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle];
	return [NSString stringWithFormat:(count == 1) ? one : many, number];
}

static NSString *SPMySQLTransferList(NSArray *names, NSUInteger shown)
{
	if ([names count] <= shown) return [names componentsJoinedByString:@", "];
	NSString *first = [[names subarrayWithRange:NSMakeRange(0, shown)] componentsJoinedByString:@", "];
	return [NSString stringWithFormat:NSLocalizedString(@"%@ and %lu more", @"MySQL transfer: a shortened list (names, how many more)"), first, (unsigned long)([names count] - shown)];
}

/// A text field enabling a button only while it holds exactly the expected text (the Empty confirmation) or, with no
/// expected text, any name without leading or trailing whitespace of at most 64 characters (New Database…).
@interface SPMySQLTransferNameField : NSTextField
@property (copy) NSString *expected;
@property (nonatomic, assign) NSButton *button;
@end

@implementation SPMySQLTransferNameField

- (void)dealloc
{
	[_expected release];
	[super dealloc];
}

- (void)_check
{
	NSString *value = [self stringValue];
	BOOL ok = _expected ? [value isEqualToString:_expected]
						: ([value length] && [value length] <= 64 && [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:value]);
	[_button setEnabled:ok];
}

- (void)setButton:(NSButton *)button
{
	_button = button;
	[self _check];
}

- (void)setStringValue:(NSString *)value
{
	[super setStringValue:value];
	[self _check];
}

- (void)textDidChange:(NSNotification *)notification
{
	[super textDidChange:notification];
	[self _check];
}

@end

@interface SPMySQLTransferController ()
{
	SPDatabaseDocument *document;
	NSString *database;

	NSPanel *sheet;
	NSButton *wholeDatabaseRadio, *selectedTablesRadio;
	SPPostgresCheckList *tablesList;
	NSPopUpButton *favoritePopup, *databasePopup;
	NSSearchField *favoriteFilterField, *databaseFilterField;
	NSTextField *targetDescriptionField, *ownershipNoteField, *targetStatusField;
	NSButton *retryButton, *emptyModeRadio, *overwriteModeRadio, *transferButton, *cancelButton;

	SPMySQLTransferTargetState targetState;
	NSUInteger sessionGeneration;
	NSDictionary *sessionFavorite;
	NSString *sessionPassword;
	SPMySQLConnection *sessionConnection;
	SPMySQLFavoriteConnector *sessionConnector;
	NSString *selectedDatabase;
	NSMutableSet *createdDatabases;
	NSMutableArray *ownAlertWindows;

	BOOL began, finished, running, confirming, prompting, cancelRequested;
	void (^afterSheetEnds)(void);
	SPPostgresProgressSheet *progressSheet;
	NSString *lastErrorMessage;
	NSString *completionNote;
}
@end

@implementation SPMySQLTransferController

@synthesize didEnd, favorites, ownFavoriteID, targetConnect, sourceConnect, passwordPrompt, newDatabasePrompt, emptyConfirmation, filteredMenuOpener, progressObserver;
@synthesize sheet, wholeDatabaseRadio, selectedTablesRadio, tablesList, favoritePopup, targetDescriptionField, ownershipNoteField, databasePopup;
@synthesize favoriteFilterField, databaseFilterField, targetStatusField, retryButton, emptyModeRadio, overwriteModeRadio, transferButton;
@synthesize selectedDatabase, progressSheet, lastErrorMessage, completionNote;

- (instancetype)initWithDocument:(SPDatabaseDocument *)theDocument
{
	if ((self = [super init])) {
		document = [theDocument retain];
		database = [[theDocument database] copy];
		createdDatabases = [[NSMutableSet alloc] init];
		ownAlertWindows = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self _closeSession];
	[document release];
	[database release];
	[didEnd release];
	[favorites release];
	[ownFavoriteID release];
	[targetConnect release];
	[sourceConnect release];
	[passwordPrompt release];
	[newDatabasePrompt release];
	[emptyConfirmation release];
	[filteredMenuOpener release];
	[progressObserver release];
	[sheet release];
	[wholeDatabaseRadio release];
	[selectedTablesRadio release];
	[tablesList release];
	[favoritePopup release];
	[databasePopup release];
	[favoriteFilterField release];
	[databaseFilterField release];
	[targetDescriptionField release];
	[ownershipNoteField release];
	[targetStatusField release];
	[retryButton release];
	[emptyModeRadio release];
	[overwriteModeRadio release];
	[transferButton release];
	[cancelButton release];
	[sessionFavorite release];
	[sessionPassword release];
	[selectedDatabase release];
	[createdDatabases release];
	[ownAlertWindows release];
	[afterSheetEnds release];
	[progressSheet release];
	[lastErrorMessage release];
	[completionNote release];
	[super dealloc];
}

- (void)_setLastErrorMessage:(NSString *)message
{
	[lastErrorMessage autorelease];
	lastErrorMessage = [message copy];
}

- (void)_setCompletionNote:(NSString *)note
{
	[completionNote autorelease];
	completionNote = [note copy];
}

- (void)_setSelectedDatabase:(NSString *)name
{
	[selectedDatabase autorelease];
	selectedDatabase = [name copy];
}

#pragma mark - Building

- (NSTextField *)_labelWithFrame:(NSRect)frame text:(NSString *)text
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	[label setStringValue:text ?: @""];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setAlignment:NSTextAlignmentRight];
	return label;
}

- (NSTextField *)_noteWithFrame:(NSRect)frame
{
	NSTextField *note = [self _labelWithFrame:frame text:@""];
	[note setAlignment:NSTextAlignmentLeft];
	[note setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[note setTextColor:[NSColor secondaryLabelColor]];
	[note setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
	return note;
}

- (NSSearchField *)_filterFieldWithFrame:(NSRect)frame
{
	NSSearchField *field = [[NSSearchField alloc] initWithFrame:frame];
	[field setPlaceholderString:NSLocalizedString(@"Filter", @"MySQL transfer sheet: filter placeholder")];
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

- (NSButton *)_buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action
{
	NSButton *button = [[NSButton alloc] initWithFrame:frame];
	[button setBezelStyle:NSBezelStyleRounded];
	[button setTitle:title];
	[button setTarget:self];
	[button setAction:action];
	[button setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	return button;
}

- (void)_buildSheet
{
	if (sheet) return;
	CGFloat width = 520, height = 536;
	sheet = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[sheet setReleasedWhenClosed:NO];
	[sheet setContentMinSize:NSMakeSize(width, height)];
	[sheet setTitle:NSLocalizedString(@"Transfer", @"MySQL transfer sheet: title")];
	NSView *content = [sheet contentView];

	NSTextField *heading = [self _labelWithFrame:NSMakeRect(20, height - 36, width - 40, 18) text:NSLocalizedString(@"Transfer", @"MySQL transfer sheet: title")];
	[heading setAlignment:NSTextAlignmentLeft];
	[heading setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
	[heading setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:heading];

	wholeDatabaseRadio = [self _radioWithFrame:NSMakeRect(20, height - 66, width - 40, 20) title:[NSString stringWithFormat:NSLocalizedString(@"Whole database “%@”", @"MySQL transfer sheet: scope (database)"), database ?: @""] action:@selector(_scopeChanged:) on:YES];
	[content addSubview:wholeDatabaseRadio];
	selectedTablesRadio = [self _radioWithFrame:NSMakeRect(20, height - 90, width - 40, 20) title:NSLocalizedString(@"Selected tables", @"MySQL transfer sheet: scope") action:@selector(_scopeChanged:) on:NO];
	[content addSubview:selectedTablesRadio];
	CGFloat listBottom = 294;
	tablesList = [[SPPostgresCheckList alloc] initWithFrame:NSMakeRect(40, listBottom, width - 60, height - 98 - listBottom) inView:content];
	__block SPMySQLTransferController *controller = self;
	[tablesList setChecksChanged:^{ [controller _updateControls]; }];

	NSTextField *toLabel = [self _labelWithFrame:NSMakeRect(20, 252, 80, 18) text:NSLocalizedString(@"To:", @"MySQL transfer sheet: target favorite label")];
	[toLabel setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:toLabel];
	favoritePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(104, 247, 280, 26) pullsDown:NO];
	[favoritePopup setTarget:self];
	[favoritePopup setAction:@selector(_favoriteChanged:)];
	[favoritePopup setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:favoritePopup];
	favoriteFilterField = [self _filterFieldWithFrame:NSMakeRect(392, 249, width - 20 - 392, 22)];
	[content addSubview:favoriteFilterField];
	targetDescriptionField = [[self _noteWithFrame:NSMakeRect(108, 228, width - 128, 16)] retain];
	[targetDescriptionField setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[content addSubview:targetDescriptionField];

	NSTextField *databaseLabel = [self _labelWithFrame:NSMakeRect(20, 196, 80, 18) text:NSLocalizedString(@"Database:", @"MySQL transfer sheet: target database label")];
	[databaseLabel setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:databaseLabel];
	databasePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(104, 191, 280, 26) pullsDown:NO];
	[[databasePopup menu] setAutoenablesItems:NO];
	[databasePopup setTarget:self];
	[databasePopup setAction:@selector(_databaseChanged:)];
	[databasePopup setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:databasePopup];
	databaseFilterField = [self _filterFieldWithFrame:NSMakeRect(392, 193, width - 20 - 392, 22)];
	[content addSubview:databaseFilterField];

	targetStatusField = [[self _noteWithFrame:NSMakeRect(108, 154, width - 128 - 96, 32)] retain];
	[targetStatusField setTextColor:[NSColor systemRedColor]];
	[[targetStatusField cell] setWraps:YES];
	[[targetStatusField cell] setTruncatesLastVisibleLine:YES];
	[content addSubview:targetStatusField];
	retryButton = [self _buttonWithFrame:NSMakeRect(width - 20 - 90, 156, 90, 28) title:NSLocalizedString(@"Retry", @"MySQL transfer sheet: connect again") action:@selector(_retry:)];
	[retryButton setHidden:YES];
	[content addSubview:retryButton];

	emptyModeRadio = [self _radioWithFrame:NSMakeRect(20, 124, width - 40, 20) title:NSLocalizedString(@"Empty the target database first", @"MySQL transfer sheet: mode") action:@selector(_modeChanged:) on:YES];
	[emptyModeRadio setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:emptyModeRadio];
	overwriteModeRadio = [self _radioWithFrame:NSMakeRect(20, 100, width - 40, 20) title:NSLocalizedString(@"Overwrite tables that already exist on the target", @"MySQL transfer sheet: mode") action:@selector(_modeChanged:) on:NO];
	[overwriteModeRadio setAutoresizingMask:NSViewMaxYMargin];
	[content addSubview:overwriteModeRadio];

	ownershipNoteField = [[self _noteWithFrame:NSMakeRect(20, 50, width - 40, 46)] retain];
	[[ownershipNoteField cell] setWraps:YES];
	[content addSubview:ownershipNoteField];

	transferButton = [self _buttonWithFrame:NSMakeRect(width - 20 - 100, 12, 100, 32) title:NSLocalizedString(@"Transfer", @"MySQL transfer sheet: transfer button") action:@selector(transfer:)];
	[transferButton setKeyEquivalent:@"\r"];
	[content addSubview:transferButton];
	cancelButton = [self _buttonWithFrame:NSMakeRect(width - 20 - 200, 12, 100, 32) title:NSLocalizedString(@"Cancel", @"cancel button") action:@selector(cancel:)];
	[cancelButton setKeyEquivalent:@"\e"];
	[content addSubview:cancelButton];
}

- (void)_loadContents
{
	NSArray *tables = [[document tablesListInstance] allTableNames] ?: @[];
	[tablesList setRows:tables];
	for (NSString *name in [[document tablesListInstance] selectedTableNames]) {
		if ([tables containsObject:name]) [tablesList setChecked:YES item:name];
	}

	if (!favorites) [self setFavorites:[SPMySQLFavoriteConnector mysqlFavorites]];
	NSString *ownID = ownFavoriteID ?: [[document connectionController] connectionKeychainID];
	[favoritePopup removeAllItems];
	NSInteger preselected = -1;
	for (NSUInteger index = 0; index < [favorites count]; index++) {
		NSDictionary *favorite = favorites[index];
		[[favoritePopup menu] addItemWithTitle:[favorite objectForKey:SPFavoriteNameKey] ?: @"" action:NULL keyEquivalent:@""];
		BOOL own = [ownID length] && [[[favorite objectForKey:SPFavoriteIDKey] description] isEqualToString:ownID];
		if (preselected < 0 && !own) preselected = (NSInteger)index;
	}
	if ([favorites count]) [favoritePopup selectItemAtIndex:preselected >= 0 ? preselected : 0];
	[self _showFavorite];
}

#pragma mark - Controls

- (NSDictionary *)_selectedFavorite
{
	NSInteger index = [favoritePopup indexOfSelectedItem];
	return (index >= 0 && (NSUInteger)index < [favorites count]) ? favorites[index] : nil;
}

- (BOOL)_wholeDatabase
{
	return [wholeDatabaseRadio state] == NSControlStateValueOn;
}

- (SPMySQLTransferMode)_mode
{
	return [overwriteModeRadio state] == NSControlStateValueOn ? SPMySQLTransferOverwrite : SPMySQLTransferEmptyTarget;
}

- (BOOL)_canTransfer
{
	if (finished || running || confirming || prompting) return NO;
	if (![self _selectedFavorite] || targetState != SPMySQLTransferTargetConnected || ![selectedDatabase length]) return NO;
	return [self _wholeDatabase] || [[tablesList checkedItems] count] > 0;
}

- (void)_updateControls
{
	[[tablesList tableView] setEnabled:![self _wholeDatabase]];
	[favoritePopup setEnabled:[favorites count] > 0 && !prompting];
	[databasePopup setEnabled:targetState != SPMySQLTransferTargetNone && !prompting];
	[retryButton setHidden:targetState != SPMySQLTransferTargetFailed];
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

+ (NSString *)ownershipNoteForFavorite:(NSDictionary *)favorite
{
	NSString *user = [favorite objectForKey:SPFavoriteUserKey];
	if ([user length]) {
		return [NSString stringWithFormat:NSLocalizedString(@"Definers and privileges aren't copied: views, routines, triggers and events are created with “%@”, the user the To: connection logs in as, as their definer. Grant other users access afterwards if they need it.", @"MySQL transfer sheet: ownership note (target user)"), user];
	}
	return NSLocalizedString(@"Definers and privileges aren't copied: views, routines, triggers and events are created with the user the To: connection logs in as as their definer. Grant other users access afterwards if they need it.", @"MySQL transfer sheet: ownership note");
}

- (void)_showFavorite
{
	NSDictionary *favorite = [self _selectedFavorite];
	[targetDescriptionField setStringValue:favorite ? [SPMySQLFavoriteConnector descriptionForFavorite:favorite] : @""];
	[ownershipNoteField setStringValue:[[self class] ownershipNoteForFavorite:favorite]];
}

#pragma mark - Filters

- (void)_applyFilterToPopup:(NSPopUpButton *)popup
{
	NSSearchField *field = (popup == favoritePopup) ? favoriteFilterField : databaseFilterField;
	NSString *text = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	for (NSMenuItem *item in [popup itemArray]) {
		BOOL kept = [item isSeparatorItem] || [item tag] == SPMySQLTransferNewDatabaseTag || (popup == databasePopup && ![item representedObject]);
		BOOL matches = ![text length] || [[item title] rangeOfString:text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
		[item setHidden:!kept && !matches];
	}
	NSMenuItem *chosen = [popup selectedItem];
	if (!chosen || ![chosen isHidden]) return;
	[popup selectItem:nil];
	if (popup == favoritePopup) [self _favoriteChanged:nil];
	else {
		[self _setSelectedDatabase:nil];
		[self _updateControls];
	}
}

- (void)_filterChanged:(id)sender
{
	NSPopUpButton *popup = (sender == favoriteFilterField) ? favoritePopup : databasePopup;
	[self _applyFilterToPopup:popup];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_openFilteredMenu:) object:favoritePopup];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_openFilteredMenu:) object:databasePopup];
	if ([[[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		[self performSelector:@selector(_openFilteredMenu:) withObject:popup afterDelay:SPMySQLTransferFilterMenuDelay];
	}
}

- (void)_openFilteredMenu:(NSPopUpButton *)popup
{
	if (finished || running || confirming || prompting || ![sheet isVisible] || ![popup isEnabled]) return;
	NSSearchField *field = (popup == favoritePopup) ? favoriteFilterField : databaseFilterField;
	if (![[[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) return;
	BOOL matched = NO;
	for (NSMenuItem *item in [popup itemArray]) {
		if ([item isHidden] || [item isSeparatorItem] || ![item isEnabled] || [item tag] == SPMySQLTransferNewDatabaseTag) continue;
		if (popup == databasePopup && ![item representedObject]) continue;
		matched = YES;
		break;
	}
	if (!matched) return;
	if (filteredMenuOpener) filteredMenuOpener(popup);
	else [popup performClick:nil];
}

#pragma mark - The target session

- (void)_favoriteChanged:(id)sender
{
	[self _showFavorite];
	NSDictionary *favorite = [self _selectedFavorite];
	if (favorite == sessionFavorite && targetState != SPMySQLTransferTargetFailed && targetState != SPMySQLTransferTargetNone) {
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

- (void)_setTargetState:(SPMySQLTransferTargetState)state message:(NSString *)message
{
	targetState = state;
	[targetStatusField setStringValue:(state == SPMySQLTransferTargetFailed) ? (message ?: @"") : @""];
	if (state != SPMySQLTransferTargetConnected) {
		[self _setSelectedDatabase:nil];
		[databasePopup removeAllItems];
		NSString *title = (state == SPMySQLTransferTargetConnecting) ? NSLocalizedString(@"Connecting…", @"MySQL transfer sheet: database menu while connecting")
						: (state == SPMySQLTransferTargetFailed) ? NSLocalizedString(@"Not connected", @"MySQL transfer sheet: database menu when not connected") : nil;
		if (title) {
			NSMenuItem *item = [[databasePopup menu] addItemWithTitle:title action:NULL keyEquivalent:@""];
			[item setEnabled:NO];
		}
	}
	[self _updateControls];
}

- (void)_openSession
{
	sessionGeneration++;
	if (!sessionFavorite) {
		[self _setTargetState:SPMySQLTransferTargetNone message:nil];
		return;
	}
	[self _setTargetState:SPMySQLTransferTargetConnecting message:nil];
	NSUInteger generation = sessionGeneration;
	[self _connectFavorite:sessionFavorite password:sessionPassword completion:^(SPMySQLConnection *connection, NSError *error) {
		if (finished || generation != sessionGeneration) {
			[connection disconnect];
			return;
		}
		if (connection) [self _sessionOpened:connection];
		else if ([[error domain] isEqualToString:SPMySQLConnectorErrorDomain] && [error code] == SPMySQLConnectorErrorPasswordRequired) [self _askPasswordAfter:error];
		else [self _setTargetState:SPMySQLTransferTargetFailed message:[error localizedDescription]];
	}];
}

- (void)_connectFavorite:(NSDictionary *)favorite password:(NSString *)password completion:(void (^)(SPMySQLConnection *, NSError *))completion
{
	if (targetConnect) {
		targetConnect(favorite, password, completion);
		return;
	}
	void (^done)(SPMySQLConnection *, NSError *) = [[completion copy] autorelease];
	SPMySQLFavoriteConnector *connector = [[[SPMySQLFavoriteConnector alloc] initWithFavorite:favorite password:password parentWindow:sheet] autorelease];
	[sessionConnector release];
	sessionConnector = [connector retain];
	[connector connectWithCompletion:^(SPMySQLConnection *connection, NSError *error) {
		if (!connection && sessionConnector == connector) {
			[sessionConnector autorelease];
			sessionConnector = nil;
		}
		done(connection, error);
	}];
}

- (void)_sessionOpened:(SPMySQLConnection *)connection
{
	sessionConnection = [connection retain];
	[connection setEncoding:@"utf8mb4"];
	NSMutableArray *names = [NSMutableArray array];
	SPMySQLResult *result = [connection queryString:@"SHOW DATABASES"];
	if ([connection queryErrored]) {
		NSString *message = [connection lastErrorMessage];
		[self _closeSession];
		[self _setTargetState:SPMySQLTransferTargetFailed message:message];
		return;
	}
	[result setReturnDataAsStrings:YES];
	NSArray *row = nil;
	while ((row = [result getRowAsArray])) {
		NSString *name = [row count] ? row[0] : nil;
		if ([name isKindOfClass:[NSString class]] && ![SPMySQLTransferSystemDatabases() containsObject:[name lowercaseString]]) [names addObject:name];
	}
	[names sortUsingSelector:@selector(localizedStandardCompare:)];
	[self _showDatabases:names selecting:[sessionFavorite objectForKey:SPFavoriteDatabaseKey]];
}

- (void)_showDatabases:(NSArray *)names selecting:(NSString *)name
{
	targetState = SPMySQLTransferTargetConnected;
	[targetStatusField setStringValue:@""];
	[databasePopup removeAllItems];
	for (NSString *each in names) {
		NSMenuItem *item = [[databasePopup menu] addItemWithTitle:each action:NULL keyEquivalent:@""];
		[item setRepresentedObject:each];
	}
	if ([names count]) [[databasePopup menu] addItem:[NSMenuItem separatorItem]];
	NSMenuItem *newItem = [[databasePopup menu] addItemWithTitle:NSLocalizedString(@"New Database…", @"MySQL transfer sheet: create a database") action:NULL keyEquivalent:@""];
	[newItem setTag:SPMySQLTransferNewDatabaseTag];
	NSInteger index = [name length] ? [databasePopup indexOfItemWithRepresentedObject:name] : -1;
	if (index >= 0) {
		[databasePopup selectItemAtIndex:index];
		[self _setSelectedDatabase:name];
	}
	else {
		[databasePopup selectItem:nil];
		[self _setSelectedDatabase:nil];
	}
	[self _applyFilterToPopup:databasePopup];
	[self _updateControls];
}

- (void)_closeSession
{
	SPMySQLConnection *connection = sessionConnection;
	sessionConnection = nil;
	SPMySQLFavoriteConnector *connector = sessionConnector;
	sessionConnector = nil;
	if (connector) [connector disconnect];
	else if (connection) [connection disconnect];
	[connection release];
	[connector release];
}

- (void)_askPasswordAfter:(NSError *)error
{
	NSUInteger generation = sessionGeneration;
	NSDictionary *favorite = [[sessionFavorite retain] autorelease];
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
			[self _setTargetState:SPMySQLTransferTargetFailed message:message];
			return;
		}
		// For this sheet only: never saved
		[sessionPassword release];
		sessionPassword = [password copy];
		[self _openSession];
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

- (NSAlert *)passwordAlertForFavorite:(NSDictionary *)favorite
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Password for %@ on “%@”", @"MySQL transfer: password prompt title (user, favorite)"), [favorite objectForKey:SPFavoriteUserKey] ?: @"", [favorite objectForKey:SPFavoriteNameKey] ?: @""]];
	[alert setInformativeText:NSLocalizedString(@"The server refused the saved password, or none is saved. It is used for this transfer only and isn't saved.", @"MySQL transfer: password prompt text")];
	[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"MySQL transfer: password prompt button")];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];
	[alert setAccessoryView:[[[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease]];
	return alert;
}

- (void)_retry:(id)sender
{
	if (finished || targetState != SPMySQLTransferTargetFailed) return;
	[self _openSession];
}

/// One of this controller's alerts as a sheet on the Transfer sheet.
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

#pragma mark - The target database

- (void)_databaseChanged:(id)sender
{
	NSMenuItem *item = [databasePopup selectedItem];
	if ([item tag] == SPMySQLTransferNewDatabaseTag) {
		[self _newDatabase];
		return;
	}
	[self _setSelectedDatabase:[item representedObject]];
	[self _updateControls];
}

- (void)_reselectDatabase:(NSString *)name
{
	NSInteger index = [name length] ? [databasePopup indexOfItemWithRepresentedObject:name] : -1;
	if (index >= 0) [databasePopup selectItemAtIndex:index];
	else [databasePopup selectItem:nil];
	[self _setSelectedDatabase:index >= 0 ? name : nil];
	[self _updateControls];
}

- (void)_newDatabase
{
	NSString *previous = [[selectedDatabase copy] autorelease];
	if (targetState != SPMySQLTransferTargetConnected || prompting || finished) {
		[self _reselectDatabase:previous];
		return;
	}
	NSUInteger generation = sessionGeneration;
	NSDictionary *favorite = [[sessionFavorite retain] autorelease];
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

- (void)_createDatabase:(NSString *)name favorite:(NSDictionary *)favorite previous:(NSString *)previous
{
	NSString *quoted = [NSString stringWithFormat:@"`%@`", [name stringByReplacingOccurrencesOfString:@"`" withString:@"``"]];
	[sessionConnection queryString:[NSString stringWithFormat:@"CREATE DATABASE %@", quoted]];
	if ([sessionConnection queryErrored]) {
		NSString *message = [sessionConnection lastErrorMessage];
		[self _reselectDatabase:previous];
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"“%@” couldn't be created on “%@”", @"MySQL transfer: CREATE DATABASE failed (database, favorite)"), name, [favorite objectForKey:SPFavoriteNameKey] ?: @""]];
		[alert setInformativeText:message ?: @""];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
		[self _beginAlert:alert completion:nil];
		return;
	}
	[createdDatabases addObject:name];
	[databaseFilterField setStringValue:@""];
	NSMutableArray *names = [NSMutableArray array];
	for (NSMenuItem *item in [databasePopup itemArray]) if ([item representedObject]) [names addObject:[item representedObject]];
	if (![names containsObject:name]) [names addObject:name];
	[names sortUsingSelector:@selector(localizedStandardCompare:)];
	[self _showDatabases:names selecting:name];
}

- (NSAlert *)createDatabaseAlertForFavorite:(NSDictionary *)favorite
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"New database on “%@”", @"MySQL transfer: New Database… prompt title (favorite)"), [favorite objectForKey:SPFavoriteNameKey] ?: @""]];
	[alert setInformativeText:NSLocalizedString(@"The database is created now, with the server's default character set and collation.", @"MySQL transfer: New Database… prompt text")];
	NSButton *create = [alert addButtonWithTitle:NSLocalizedString(@"Create", @"MySQL transfer: New Database… prompt button")];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];
	SPMySQLTransferNameField *field = [[[SPMySQLTransferNameField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease];
	[field setButton:create];
	[alert setAccessoryView:field];
	return alert;
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
	[self _loadContents];
	[self _updateControls];
	[window beginSheet:sheet completionHandler:^(NSModalResponse response) {
		void (^next)(void) = [afterSheetEnds autorelease];
		afterSheetEnds = nil;
		if (next) next();
	}];
	[self _favoriteChanged:nil];
}

- (void)_endSheet
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if ([sheet sheetParent]) [[sheet sheetParent] endSheet:sheet];
	[sheet orderOut:nil];
}

- (IBAction)cancel:(id)sender
{
	if (finished) return;
	if (running) {
		if (progressSheet) {
			[progressSheet cancel:nil];
			return;
		}
		cancelRequested = YES;
		running = NO;
		[afterSheetEnds release];
		afterSheetEnds = nil;
		[self _finish];
		return;
	}
	NSWindow *attached = [sheet attachedSheet];
	if (attached && [ownAlertWindows containsObject:attached]) [sheet endSheet:attached returnCode:NSAlertSecondButtonReturn];
	[self _closeSession];
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
	[self _closeSession];
	void (^theDidEnd)(void) = [didEnd autorelease];
	didEnd = nil;
	if (theDidEnd) theDidEnd();
	if (began && sheet) [self autorelease]; // balances -beginSheet's retain
}

#pragma mark - Confirmation

- (NSAlert *)emptyConfirmationAlertForDatabase:(NSString *)theDatabase targetDescription:(NSString *)description
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Empty “%@” and transfer into it?", @"MySQL transfer: empty confirmation title (database)"), theDatabase ?: @""]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Everything in database “%@” on %@ will be replaced: all its tables, views, routines, triggers and events. Other databases on that server aren't touched. The tables are only replaced once all of them have been copied.\n\nType the database's name to confirm.", @"MySQL transfer: empty confirmation text (database, target description)"), theDatabase ?: @"", description ?: @""]];
	NSButton *confirm = [alert addButtonWithTitle:NSLocalizedString(@"Empty and Transfer", @"MySQL transfer: empty confirmation button")];
	[confirm setHasDestructiveAction:YES];
	NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancel setKeyEquivalent:@"\e"];
	SPMySQLTransferNameField *field = [[[SPMySQLTransferNameField alloc] initWithFrame:NSMakeRect(0, 0, 260, 22)] autorelease];
	[field setPlaceholderString:theDatabase];
	[field setExpected:theDatabase];
	[field setButton:confirm];
	[alert setAccessoryView:field];
	return alert;
}

#pragma mark - Transferring

- (IBAction)transfer:(id)sender
{
	if (![self _canTransfer]) return;
	NSDictionary *favorite = [[[self _selectedFavorite] copy] autorelease];
	NSString *targetDatabase = [[selectedDatabase copy] autorelease];
	SPMySQLTransferMode mode = [self _mode];
	NSArray *tables = [self _wholeDatabase] ? nil : [[[tablesList checkedItems] copy] autorelease];

	if (mode != SPMySQLTransferEmptyTarget || [createdDatabases containsObject:targetDatabase]) {
		[self _startTransferTo:favorite database:targetDatabase mode:mode tables:tables];
		return;
	}
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
	NSString *description = [NSString stringWithFormat:NSLocalizedString(@"“%@” (%@)", @"MySQL transfer: empty confirmation's target (favorite, target line)"), [favorite objectForKey:SPFavoriteNameKey] ?: @"", [SPMySQLFavoriteConnector descriptionForFavorite:favorite]];
	if (emptyConfirmation) {
		emptyConfirmation(targetDatabase, description, answer);
		return;
	}
	NSAlert *alert = [self emptyConfirmationAlertForDatabase:targetDatabase targetDescription:description];
	[self _beginAlert:alert completion:^(NSModalResponse response) { answer(response == NSAlertFirstButtonReturn); }];
	[[alert window] makeFirstResponder:[alert accessoryView]];
}

- (void)_startTransferTo:(NSDictionary *)favorite database:(NSString *)targetDatabase mode:(SPMySQLTransferMode)mode tables:(NSArray *)tables
{
	running = YES;
	[self _setLastErrorMessage:nil];
	[self _setCompletionNote:nil];
	void (^next)(void) = ^{
		[self _beginProgressTo:favorite database:targetDatabase mode:mode tables:tables];
	};
	if ([sheet sheetParent]) {
		[afterSheetEnds release];
		afterSheetEnds = [next copy];
		[self _endSheet];
	}
	else {
		[self _endSheet];
		next();
	}
}

/// What a finished task did.
static NSString *SPMySQLTransferTaskSummary(NSUInteger task, SPMySQLTransfer *engine, SPMySQLTransferMode mode, NSUInteger tableCount, NSString *sourceDatabase, NSString *targetDatabase, NSString *favoriteName)
{
	switch (task) {
		case SPMySQLTransferTaskConnect:
			return [NSString stringWithFormat:NSLocalizedString(@"Connected to “%@” and to “%@” on “%@”", @"MySQL transfer task list: connect summary"), sourceDatabase, targetDatabase, favoriteName];
		case SPMySQLTransferTaskCheck:
			return SPMySQLTransferCount(tableCount, NSLocalizedString(@"%@ table to copy", @"MySQL transfer task list: check summary (one)"), NSLocalizedString(@"%@ tables to copy", @"MySQL transfer task list: check summary (count)"));
		case SPMySQLTransferTaskRead:
			return SPMySQLTransferCount(tableCount, NSLocalizedString(@"%@ table read", @"MySQL transfer task list: read summary (one)"), NSLocalizedString(@"%@ tables read", @"MySQL transfer task list: read summary (count)"));
		case SPMySQLTransferTaskCreate:
			return SPMySQLTransferCount(tableCount, NSLocalizedString(@"%@ table created under a temporary name", @"MySQL transfer task list: create summary (one)"), NSLocalizedString(@"%@ tables created under temporary names", @"MySQL transfer task list: create summary (count)"));
		case SPMySQLTransferTaskCopy:
			return [NSString stringWithFormat:NSLocalizedString(@"%@, %@ copied", @"MySQL transfer task list: copy summary (tables, rows)"),
					SPMySQLTransferCount([engine tablesCopied], NSLocalizedString(@"%@ table", @"MySQL transfer task list: tables (one)"), NSLocalizedString(@"%@ tables", @"MySQL transfer task list: tables (count)")),
					SPMySQLTransferCount([engine rowsCopied], NSLocalizedString(@"%@ row", @"MySQL transfer task list: rows (one)"), NSLocalizedString(@"%@ rows", @"MySQL transfer task list: rows (count)"))];
		case SPMySQLTransferTaskSwap: {
			NSMutableArray *parts = [NSMutableArray array];
			if ([[engine tablesReplaced] count]) [parts addObject:[NSString stringWithFormat:NSLocalizedString(@"replaced: %@", @"MySQL transfer task list: tables replaced"), SPMySQLTransferList([engine tablesReplaced], 6)]];
			if ([[engine objectsDropped] count]) [parts addObject:[NSString stringWithFormat:NSLocalizedString(@"dropped: %@", @"MySQL transfer task list: objects dropped"), SPMySQLTransferList([engine objectsDropped], 6)]];
			if (![parts count]) return NSLocalizedString(@"Swapped in; nothing was replaced", @"MySQL transfer task list: swap summary, nothing replaced");
			return [NSString stringWithFormat:NSLocalizedString(@"Swapped in; %@", @"MySQL transfer task list: swap summary"), [parts componentsJoinedByString:@"; "]];
		}
		case SPMySQLTransferTaskFinish: {
			NSUInteger created = [[engine objectsCreated] count], notCreated = [[engine objectsNotCreated] count];
			if (!created && !notCreated) return NSLocalizedString(@"Nothing else to create", @"MySQL transfer task list: finish summary, nothing");
			NSString *summary = SPMySQLTransferCount(created, NSLocalizedString(@"%@ object created", @"MySQL transfer task list: objects created (one)"), NSLocalizedString(@"%@ objects created", @"MySQL transfer task list: objects created (count)"));
			if (notCreated) summary = [summary stringByAppendingFormat:NSLocalizedString(@", %lu not created", @"MySQL transfer task list: objects not created"), (unsigned long)notCreated];
			return summary;
		}
	}
	return nil;
}

- (void)_beginProgressTo:(NSDictionary *)favorite database:(NSString *)targetDatabase mode:(SPMySQLTransferMode)mode tables:(NSArray *)tables
{
	if (finished || cancelRequested) return;
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Transferring “%@” to “%@”…", @"MySQL transfer: progress title (source, target)"), database, targetDatabase];
	NSArray *tasks = @[
		NSLocalizedString(@"Connect to the source and the target", @"MySQL transfer task list: connect"),
		NSLocalizedString(@"Check the source and the target", @"MySQL transfer task list: check"),
		[NSString stringWithFormat:NSLocalizedString(@"Read “%@”", @"MySQL transfer task list: read (source database)"), database],
		[NSString stringWithFormat:NSLocalizedString(@"Create the tables in “%@” under temporary names", @"MySQL transfer task list: create (target database)"), targetDatabase],
		NSLocalizedString(@"Copy the data", @"MySQL transfer task list: copy"),
		(mode == SPMySQLTransferEmptyTarget)
			? [NSString stringWithFormat:NSLocalizedString(@"Empty “%@” and swap the tables in", @"MySQL transfer task list: swap, Empty mode (target database)"), targetDatabase]
			: [NSString stringWithFormat:NSLocalizedString(@"Swap the tables into “%@”", @"MySQL transfer task list: swap, Overwrite mode (target database)"), targetDatabase],
		NSLocalizedString(@"Create foreign keys, views, triggers, routines and events", @"MySQL transfer task list: finish")];
	[progressSheet release];
	progressSheet = [[SPPostgresProgressSheet beginOnWindow:[document parentWindow] title:title tasks:tasks] retain];
	SPPostgresProgressSheet *progress = progressSheet;
	[progress setTask:SPMySQLTransferTaskConnect status:NSLocalizedString(@"Connecting…", @"MySQL transfer: progress status while connecting") fraction:0];

	// The source: a copy of the tab's connection (through its tunnel, if any) with its password; the target: the session
	SPMySQLConnection *tabConnection = [document getConnection];
	SPMySQLConnection *(^makeSource)(void) = [[sourceConnect copy] autorelease];
	NSString *tabPassword = nil;
	if (!makeSource) tabPassword = [[[(id)document keychainPasswordForConnection:tabConnection] copy] autorelease];
	SPMySQLConnection *target = [[sessionConnection retain] autorelease];
	NSString *sourceDatabase = [[database copy] autorelease];
	NSString *favoriteName = [[[favorite objectForKey:SPFavoriteNameKey] copy] autorelease] ?: @"";
	NSString *favoriteUser = [[[favorite objectForKey:SPFavoriteUserKey] copy] autorelease];
	void (^observer)(SPPostgresProgressSheet *) = [[progressObserver copy] autorelease];

	__block SPMySQLConnection *source = nil;
	[progress setCancelHandler:^{
		// A query running on either side is interrupted
		[source cancelCurrentQuery];
		[target cancelCurrentQuery];
	}];

	[self retain];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSError *error = nil;
		SPMySQLTransfer *engine = nil;
		BOOL ok = NO;
		if (makeSource) source = [makeSource() retain];
		else {
			source = [tabConnection copy];
			[source setDelegate:nil];
			if (tabPassword) [source setPassword:tabPassword];
			[source connect];
		}
		if (![source isConnected]) {
			error = [NSError errorWithDomain:SPMySQLTransferErrorDomain code:SPMySQLTransferErrorFailed userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"This tab's database couldn't be opened again for the transfer: %@", @"MySQL transfer: source connection failed"), [source lastErrorMessage] ?: @""]}];
		}
		else if ([progress cancelled]) {
			error = [NSError errorWithDomain:SPMySQLTransferErrorDomain code:SPMySQLTransferErrorCancelled userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"The transfer was cancelled.", @"MySQL transfer: cancelled")}];
		}
		else {
			engine = [[[SPMySQLTransfer alloc] initWithSource:source database:sourceDatabase target:target database:targetDatabase] autorelease];
			if (tables) [engine setTables:tables];
			else [engine setWholeDatabase:YES];
			[engine setMode:mode];
			__block SPMySQLTransfer *theEngine = engine;
			__block NSUInteger tableCount = 0;
			__block NSUInteger summarized = 0;
			void (^summarizeBefore)(NSUInteger) = ^(NSUInteger task) {
				for (; summarized < task; summarized++) {
					[progress setSummary:SPMySQLTransferTaskSummary(summarized, theEngine, mode, tableCount, sourceDatabase, targetDatabase, favoriteName) forTask:summarized];
				}
			};
			[engine setProgress:^BOOL(SPMySQLTransferStep step, NSString *detail) {
				NSUInteger index = [theEngine stepIndex], count = [theEngine stepCount];
				NSString *ofCount = [NSString stringWithFormat:NSLocalizedString(@"%lu of %lu", @"MySQL transfer: step of steps"), (unsigned long)index, (unsigned long)count];
				NSString *status = nil;
				NSUInteger task = SPMySQLTransferTaskCheck;
				double fraction = count ? (double)(index ? index - 1 : 0) / (double)count : 0;
				switch (step) {
					case SPMySQLTransferChecking:
						status = NSLocalizedString(@"Checking the source and the target…", @"MySQL transfer: progress status");
						break;
					case SPMySQLTransferReading:
						task = SPMySQLTransferTaskRead;
						if (!detail) tableCount = count;
						status = detail ? [NSString stringWithFormat:NSLocalizedString(@"Table %@: %@", @"MySQL transfer: progress status (step, table)"), ofCount, detail]
										: NSLocalizedString(@"Reading the definitions in one snapshot…", @"MySQL transfer: progress status before the first table");
						break;
					case SPMySQLTransferCreatingTables:
						task = SPMySQLTransferTaskCreate;
						status = [NSString stringWithFormat:NSLocalizedString(@"Table %@: %@", @"MySQL transfer: progress status (step, table)"), ofCount, detail ?: @""];
						break;
					case SPMySQLTransferCopyingData: {
						task = SPMySQLTransferTaskCopy;
						unsigned long long rows = [theEngine tableRowsCopied], estimate = [theEngine tableRowEstimate];
						NSString *copied = [NSNumberFormatter localizedStringFromNumber:@(rows) numberStyle:NSNumberFormatterDecimalStyle];
						status = (estimate > rows)
							? [NSString stringWithFormat:NSLocalizedString(@"Table %@: %@ — %@ of about %@ rows", @"MySQL transfer: progress status (step, table, rows, estimate)"), ofCount, detail ?: @"", copied, [NSNumberFormatter localizedStringFromNumber:@(estimate) numberStyle:NSNumberFormatterDecimalStyle]]
							: [NSString stringWithFormat:NSLocalizedString(@"Table %@: %@ — %@", @"MySQL transfer: progress status (step, table, rows)"), ofCount, detail ?: @"", SPMySQLTransferCount(rows, NSLocalizedString(@"%@ row", @"MySQL transfer task list: rows (one)"), NSLocalizedString(@"%@ rows", @"MySQL transfer task list: rows (count)"))];
						if (count && estimate) fraction = ((double)(index ? index - 1 : 0) + MIN(1.0, (double)rows / (double)estimate)) / (double)count;
						break;
					}
					case SPMySQLTransferSwapping:
						task = SPMySQLTransferTaskSwap;
						status = NSLocalizedString(@"Renaming the tables into place…", @"MySQL transfer: progress status (swap)");
						break;
					case SPMySQLTransferFinishing:
						task = SPMySQLTransferTaskFinish;
						status = [NSString stringWithFormat:NSLocalizedString(@"%@: %@", @"MySQL transfer: progress status (step, object)"), ofCount, detail ?: @""];
						break;
				}
				summarizeBefore(task);
				[progress setTask:task status:status fraction:fraction];
				if (observer) observer(progress);
				return ![progress cancelled];
			}];
			ok = [engine run:&error];
			if (ok || [error code] == SPMySQLTransferErrorIncomplete) summarizeBefore(SPMySQLTransferTaskCount);
			[engine setProgress:nil];
		}
		[error retain];
		[engine retain];
		[pool drain];
		dispatch_async(dispatch_get_main_queue(), ^{
			[source disconnect];
			[source release];
			[self _jobEndedWithSuccess:ok engine:engine error:error database:targetDatabase favoriteName:favoriteName user:favoriteUser];
			[engine release];
			[error release];
			[self release];
		});
	});
}

- (NSString *)_completionNoteForEngine:(SPMySQLTransfer *)engine database:(NSString *)targetDatabase favoriteName:(NSString *)favoriteName user:(NSString *)user
{
	NSMutableArray *lines = [NSMutableArray array];
	NSString *place = [NSString stringWithFormat:NSLocalizedString(@"“%@” on “%@”", @"MySQL transfer: target database on favorite"), targetDatabase, favoriteName];
	[lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Copied %@ (%@) to %@.", @"MySQL transfer: completion (tables, rows, target)"),
					  SPMySQLTransferCount([engine tablesCopied], NSLocalizedString(@"%@ table", @"MySQL transfer task list: tables (one)"), NSLocalizedString(@"%@ tables", @"MySQL transfer task list: tables (count)")),
					  SPMySQLTransferCount([engine rowsCopied], NSLocalizedString(@"%@ row", @"MySQL transfer task list: rows (one)"), NSLocalizedString(@"%@ rows", @"MySQL transfer task list: rows (count)")), place]];
	if ([[engine tablesReplaced] count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Replaced: %@.", @"MySQL transfer: completion, tables replaced"), [[engine tablesReplaced] componentsJoinedByString:@", "]]];
	if ([[engine objectsDropped] count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Dropped: %@.", @"MySQL transfer: completion, objects dropped"), [[engine objectsDropped] componentsJoinedByString:@", "]]];
	if ([[engine objectsCreated] count]) [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"Created: %@.", @"MySQL transfer: completion, objects created"), [[engine objectsCreated] componentsJoinedByString:@", "]]];
	[lines addObject:[user length]
		? [NSString stringWithFormat:NSLocalizedString(@"Views, routines, triggers and events are defined by “%@”. The source's definers and privileges weren't copied.", @"MySQL transfer: completion, definer (user)"), user]
		: NSLocalizedString(@"Views, routines, triggers and events are defined by the To: connection's user. The source's definers and privileges weren't copied.", @"MySQL transfer: completion, definer")];
	return [lines componentsJoinedByString:@"\n\n"];
}

- (void)_jobEndedWithSuccess:(BOOL)ok engine:(SPMySQLTransfer *)engine error:(NSError *)error database:(NSString *)targetDatabase favoriteName:(NSString *)favoriteName user:(NSString *)user
{
	if (finished) return;
	running = NO;
	NSString *place = [NSString stringWithFormat:NSLocalizedString(@"“%@” on “%@”", @"MySQL transfer: target database on favorite"), targetDatabase, favoriteName];
	if (ok) {
		[self _setCompletionNote:[self _completionNoteForEngine:engine database:targetDatabase favoriteName:favoriteName user:user]];
		[progressSheet finishWithSuccess:YES message:NSLocalizedString(@"Transfer complete", @"MySQL transfer: success title") text:completionNote];
	}
	else if ([[error domain] isEqualToString:SPMySQLTransferErrorDomain] && [error code] == SPMySQLTransferErrorCancelled) {
		// Before the swap: the target is as it was, nothing to show
		[progressSheet end];
		[self _setLastErrorMessage:[error localizedDescription]];
	}
	else if ([[error domain] isEqualToString:SPMySQLTransferErrorDomain] && [error code] == SPMySQLTransferErrorIncomplete) {
		// The tables are in place; some objects aren't
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The tables were copied to %@, but not everything else was created.", @"MySQL transfer: incomplete title (target)"), place];
		NSArray *notCreated = [[error userInfo] objectForKey:SPMySQLTransferNotCreatedKey] ?: @[];
		NSString *text = [NSString stringWithFormat:@"%@\n\n%@\n%@\n\n%@", [error localizedDescription], NSLocalizedString(@"Not created:", @"MySQL transfer: incomplete, the list follows"), [notCreated componentsJoinedByString:@"\n"], [self _completionNoteForEngine:engine database:targetDatabase favoriteName:favoriteName user:user]];
		[self _setLastErrorMessage:[NSString stringWithFormat:@"%@\n\n%@", message, text]];
		[progressSheet finishWithSuccess:NO message:message text:text];
	}
	else {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The transfer failed. %@ wasn't changed.", @"MySQL transfer: failure title (target)"), place];
		NSString *text = [error localizedDescription] ?: @"";
		[self _setLastErrorMessage:[NSString stringWithFormat:@"%@\n\n%@", message, text]];
		[progressSheet finishWithSuccess:NO message:message text:text];
	}
	[self _finish];
}

@end
