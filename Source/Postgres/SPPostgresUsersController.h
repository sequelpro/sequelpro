#import <Cocoa/Cocoa.h>

@class PGPostgresConnection;
@class SPPostgresConnector;
@class SPPostgresRole;

/**
 * The Users sheet of a PostgreSQL tab, built in code: the cluster's roles (logins and groups, the predefined pg_*
 * roles hidden) on the left with +, − and duplicate; on the right a tab view with General (the role's name,
 * password, expiry, connection limit and attributes), Membership ("Member of:" and "Members of this role:") and
 * Privileges (per database and schema). Every edit is a draft until Apply, which sends the role changes and every
 * database-level grant in one transaction on the document's database, then each database's other privilege changes
 * in a transaction of their own on that database (the document's first, then the others by name). When everything
 * succeeds the sheet closes; on a failure it stays open with the error and every edit not applied (after a failure
 * in a later database it re-reads what was saved). Cancel discards everything.
 *
 * It never uses the document's connection: it asks `provider` for connections of its own (to the document's
 * database first), and disconnects them (and the connectors it adopted) when the sheet ends. Use on the main thread.
 */
__attribute__((visibility("default")))
@interface SPPostgresUsersController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTabViewDelegate>

/// `database` is the document's current database. The provider's completion may be called synchronously or later.
- (instancetype)initWithDatabase:(NSString *)database connectionProvider:(void (^)(NSString *database, void (^completion)(PGPostgresConnection *connection, NSError *error)))provider;

/**
 * Connects to the database and loads the roles, then shows the sheet on window. A failure shows the error (see
 * alertPresenter) and doesn't open the sheet. completion is called exactly once: YES after a successful Apply,
 * NO on Cancel, -endSheet or a failure to open. The controller keeps itself alive until then.
 */
- (void)beginSheetForWindow:(NSWindow *)window completion:(void (^)(BOOL applied))completion;

/// Ends the sheet (as Cancel) and closes its connections.
- (void)endSheet;

/// Keeps a connector the provider made, and disconnects it when the sheet ends.
- (void)adoptConnector:(SPPostgresConnector *)connector;

/**
 * Asked when the roles have loaded, just before the sheet attaches (which may be seconds after
 * -beginSheetForWindow:completion:, e.g. over SSH): NO (e.g. the tab is no longer the window's selected one) ends
 * quietly instead, the completion getting NO and the connections closed. nil (the default) always presents.
 */
@property (copy) BOOL (^canPresent)(void);

/// The server the sheet edits, shown at its top as "Users on <name>" (e.g. the favorite's name); nil shows "ROLES".
@property (copy) NSString *serverName;

/**
 * The window a connector the provider opens should host its sheets on (e.g. SSH passwords and host keys): the
 * Users sheet once it is attached (the parent window can't show a sheet then), the "Loading users…" sheet while that is
 * up, else the parent window.
 */
@property (readonly) NSWindow *windowForConnectorSheets;

/// Shows the controller's alerts (errors). nil (the default) shows them as a sheet on the Users sheet (or on the
/// parent window before it is open). Replaceable, e.g. by tests.
@property (copy) void (^alertPresenter)(NSAlert *alert);

#pragma mark - For tests

@property (readonly) NSWindow *sheet;
/// "Loading users…" (an SPLoadingSheet, with Cancel), shown on the parent window when the connection and the roles
/// take more than 0.3 s; nil otherwise. Its Cancel ends the sheet before it opens (the completion gets NO).
@property (readonly) id loadingSheet;
@property (readonly) NSTableView *rolesTable;
@property (readonly) NSTabView *tabView;

@property (readonly) NSTextField *nameField;
@property (readonly) NSSecureTextField *passwordField;
@property (readonly) NSButton *clearPasswordCheckbox;
@property (readonly) NSButton *validUntilCheckbox;
@property (readonly) NSDatePicker *validUntilPicker;
@property (readonly) NSTextField *connectionLimitField;

@property (readonly) NSButton *loginCheckbox;
@property (readonly) NSButton *inheritCheckbox;
@property (readonly) NSButton *superuserCheckbox;
@property (readonly) NSButton *createDBCheckbox;
@property (readonly) NSButton *createRoleCheckbox;
@property (readonly) NSButton *replicationCheckbox;
@property (readonly) NSButton *bypassRLSCheckbox;

/// Columns @"member" (checkbox), @"name", @"admin" (checkbox).
@property (readonly) NSTableView *memberOfTable;
@property (readonly) NSTableView *membersTable;
/// The role names each membership table lists, in order.
@property (readonly) NSArray *memberOfCandidates;
@property (readonly) NSArray *membersCandidates;

@property (readonly) NSButton *addButton;
@property (readonly) NSButton *removeButton;
@property (readonly) NSButton *duplicateButton;
@property (readonly) NSButton *applyButton;
@property (readonly) NSButton *cancelButton;

/// The draft: the roles as listed (copies of the server's, plus new ones).
@property (readonly) NSArray *editedRoles;
@property (readonly) SPPostgresRole *selectedRole;
/// The Privileges tab (SPPostgresUsersPrivilegesPane): the database, schema and default-privileges creator pop-ups,
/// the grid and the note shown for a superuser (hidden otherwise).
@property (readonly) NSPopUpButton *databasePopup;
@property (readonly) NSPopUpButton *schemaPopup;
@property (readonly) NSPopUpButton *creatorPopup;
@property (readonly) NSTableView *privilegesTable;
@property (readonly) NSTextField *superuserNote;
/// The SPPostgresPrivilegeObjects in the grid, as shown (pending edits included): the database's row, then the
/// schema's objects and its three default rows.
- (NSArray *)privilegeRowsShown;
/// The edited SPPostgresPrivilegeObjects still pending in a database, for every role.
- (NSArray *)pendingPrivilegeEditsInDatabase:(NSString *)database;

/// The label at the top of the roles list ("Users on <serverName>", or "ROLES").
@property (readonly) NSTextField *rolesHeader;
/// The connection the sheet holds to a database (nil when it has none yet).
- (PGPostgresConnection *)openConnectionForDatabase:(NSString *)database;
/// The connectors adopted from the provider (-adoptConnector:), in order.
@property (readonly) NSArray *adoptedConnectors;

/// The last error shown (nil until one is).
@property (readonly, copy) NSString *lastErrorMessage;

/// The grey subtitle of a role's row: @"superuser", @"group, no login" or @"".
- (NSString *)subtitleForRole:(SPPostgresRole *)role;

/// Selects the role listed under that name; NO when there is none.
- (BOOL)selectRoleNamed:(NSString *)name;

- (void)apply:(id)sender;
- (void)cancel:(id)sender;
- (void)addRole:(id)sender;
- (void)removeRole:(id)sender;
- (void)duplicateRole:(id)sender;

@end
