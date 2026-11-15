#import <Cocoa/Cocoa.h>
#import "SPPostgresDocument.h"

@class SPPostgresFavorite;
@class SPPostgresProgressSheet;
@class SPPostgresCheckList;
@class SPPostgresConnector;
@class PGPostgresConnection;

/**
 * The Transfer sheet of a PostgreSQL tab (the Transfer toolbar item), built in code: copies this tab's database (the
 * whole of it, or some tables with what they need) into a database of any Postgres favorite, through SPPostgresTransfer.
 *
 * - Scope: "Whole database “<db>”" (default) or "Selected tables" (a checkbox list grouped by schema, preset to the
 *   sidebar's selected table).
 * - To: a favorite (the first that isn't this tab's is preselected), the line under it showing user@host:port,
 *   user@<socket directory> or user@host:port via SSH sshUser@sshHost. Choosing a favorite (and opening the sheet)
 *   opens a session to it (the favorite's database, or postgres; one retry on postgres) with the Keychain password,
 *   asking for one (never saved) when the server wants it. Database: a menu of the session's databases, then
 *   "New Database…" (CREATE DATABASE on the session); the favorite's database is selected when listed, else none. "Connecting…" / "Not connected" (the error and Retry under it).
 * - Filter fields (placeholder "Filter") beside the To: and Database: menus narrow each menu to the names holding the
 *   typed text (case- and diacritic-insensitive); "New Database…" always stays. A choice filtered out is unset (a
 *   favorite's session closed, a database no longer chosen), so Transfer is disabled until a listed one is chosen;
 *   clearing the filter doesn't choose again. A database made with New Database… clears the database filter. Once
 *   typing pauses (0.5 s) the menu opens, showing the matches (when there's text and at least one matching name).
 * - Mode: "Empty the target database first" (default; confirmed first by typing the database's name, except for a
 *   database created in this sheet) or "Overwrite tables that already exist on the target".
 *
 * The transfer runs as a two-connection SPPostgresBackgroundJob (this tab's database from the document's provider,
 * then the target, opened through the session: its SSH tunnel and password) under an SPPostgresProgressSheet task list:
 * Connect, Check, Read the source, (Empty and) Write, each marked as it runs, is done or failed. Cancel interrupts both
 * connections (and ends the sheet). The session closes when the controller finishes. The outcome stays on the task list
 * until Close: "Transfer complete" and what was copied, or why the target wasn't changed. Use on the main thread.
 */
__attribute__((visibility("default")))
@interface SPPostgresTransferController : NSObject

- (instancetype)initWithDocument:(SPPostgresDocument *)document;

/// Shows the sheet on the document's window. The controller keeps itself alive until the transfer (or Cancel) ends.
/// When the tables can't be read, an alert says why (on the sheet, or through the document's alertPresenter when set).
- (void)beginSheet;

/// Called on the main thread once the sheet and any transfer it started have ended.
@property (copy) void (^didEnd)(void);

#pragma mark - Seams

/// The favorites the To: pop-up offers (SPPostgresFavorite). nil (the default): the favorites store's, read by
/// -beginSheet.
@property (copy) NSArray *favorites;

/**
 * Opens a target connection; completion must be called once, on the main thread. sessionToken nil: the sheet's session
 * to database (the default: an SPPostgresConnector for a copy of the favorite with that database, password or else
 * the Keychain's, the Transfer sheet as parentWindow for its SSH prompts; the connector is the token). Non-nil: the
 * transfer's connection to database through that session (the default: a connector sharingTunnelOf: the token with
 * password or else the session's, kept until the job ends). The completion's token is the session's (ignored for a
 * transfer connection). The controller closes a session by disconnecting its connection and, when it responds to
 * -disconnect, its token.
 */
@property (copy) void (^targetConnect)(SPPostgresFavorite *favorite, NSString *database, NSString *password, id sessionToken, void (^completion)(PGPostgresConnection *connection, id sessionToken, NSError *error));

/// Asks for the favorite's password after the server asked for one; answer once with the password, or nil (Cancel).
/// nil (the default): the alert of -passwordAlertForFavorite:, as a sheet on the Transfer sheet.
@property (copy) void (^passwordPrompt)(SPPostgresFavorite *favorite, void (^answer)(NSString *password));

/// Asks for a new database's name; answer once with the name, or nil (Cancel). nil (the default): the alert of
/// -createDatabaseAlertForFavorite:, as a sheet on the Transfer sheet.
@property (copy) void (^newDatabasePrompt)(SPPostgresFavorite *favorite, void (^answer)(NSString *name));
// Not in the "new" method family (ARC callers would release what it returns)
- (void (^)(SPPostgresFavorite *favorite, void (^answer)(NSString *name)))newDatabasePrompt __attribute__((objc_method_family(none)));

/// The password prompt: "Password for <user> on “<favorite>”", an NSSecureTextField accessory, Connect and Cancel.
- (NSAlert *)passwordAlertForFavorite:(SPPostgresFavorite *)favorite;

/// The New Database… prompt: "New database on “<favorite>”", an NSTextField accessory, Create (enabled while the name
/// is non-empty, at most 63 bytes in UTF-8, and has no leading or trailing whitespace) and Cancel.
- (NSAlert *)createDatabaseAlertForFavorite:(SPPostgresFavorite *)favorite;

/// Asks to confirm Empty mode; answer must be called once (later calls are ignored). nil (the default): the alert of
/// -emptyConfirmationAlertForDatabase:targetDescription:, as a sheet on the Transfer sheet.
@property (copy) void (^emptyConfirmation)(NSString *database, NSString *targetDescription, void (^answer)(BOOL confirmed));

/// The Empty mode confirmation: an NSTextField accessory, and a first button "Empty and Transfer" (destructive),
/// enabled only while the field holds exactly database (as typed, or as set by -setStringValue:); then Cancel.
- (NSAlert *)emptyConfirmationAlertForDatabase:(NSString *)database targetDescription:(NSString *)description;

/// Opens a filter's menu once typing in the filter pauses. nil (the default): -performClick: on the pop-up (its menu
/// tracks until closed; keys then go to the menu).
@property (copy) void (^filteredMenuOpener)(NSPopUpButton *popup);

/// Called on the job's thread at every progress report, before the job checks for a cancel (as Export's).
@property (copy) void (^progressObserver)(SPPostgresProgressSheet *sheet);

/// Where the engine writes its temporary dump; nil: NSTemporaryDirectory().
@property (copy) NSString *temporaryDirectory;

#pragma mark - For tests

@property (readonly) NSPanel *sheet;
@property (readonly) NSButton *wholeDatabaseRadio;
@property (readonly) NSButton *selectedTablesRadio;
@property (readonly) SPPostgresCheckList *tablesList;
@property (readonly) NSPopUpButton *favoritePopup;
@property (readonly) NSTextField *targetDescriptionField;
/// Under the mode: owners and privileges aren't copied, and who owns the copy (the chosen favorite's user)
@property (readonly) NSTextField *ownershipNoteField;
@property (readonly) NSPopUpButton *databasePopup;
/// Narrows the To: menu (hidden items) as it's typed in; unsets the favorite it filters out
@property (readonly) NSSearchField *favoriteFilterField;
/// Narrows the Database: menu (hidden items, "New Database…" always shown) as it's typed in; unsets the database it
/// filters out
@property (readonly) NSSearchField *databaseFilterField;
/// The session's error under the menu ("" otherwise)
@property (readonly) NSTextField *targetStatusField;
/// Shown while not connected
@property (readonly) NSButton *retryButton;
/// The database chosen in the menu; nil while none (connecting, not connected, or the favorite's database isn't listed:
/// nothing is chosen for the user)
@property (readonly, copy) NSString *selectedDatabase;
@property (readonly) NSButton *emptyModeRadio;
@property (readonly) NSButton *overwriteModeRadio;
@property (readonly) NSButton *transferButton;

/// The connector the default targetConnect is opening for the transfer (until it has connected); nil otherwise.
@property (readonly) SPPostgresConnector *pendingConnector;

/// The progress sheet while a transfer runs.
/// (Kept once the transfer ends: it stays open with the outcome until Close.)
@property (readonly) SPPostgresProgressSheet *progressSheet;

- (IBAction)transfer:(id)sender;
- (IBAction)cancel:(id)sender;

/// The last transfer's error (the failed task list's message and text; nil after a success); the cancel message after a
/// cancel.
@property (readonly, copy) NSString *lastErrorMessage;

/// What a successful transfer copied ("Copied <n> tables to …" and what it replaced, created or left out), then who
/// owns what was created (owners and privileges aren't copied), also shown on the task list under "Transfer complete".
@property (readonly, copy) NSString *completionNote;

/// The target line for a favorite: user@host:port, user@<socket directory>, or user@host:port via SSH sshUser@sshHost.
+ (NSString *)targetDescriptionForFavorite:(SPPostgresFavorite *)favorite;

/// The sheet's ownership note: the copy is owned by the favorite's user (or "the user the To: connection logs in as"
/// without a favorite or user); owners and privileges aren't copied.
+ (NSString *)ownershipNoteForFavorite:(SPPostgresFavorite *)favorite;

@end
