//
//  SPMySQLTransferController.h
//  Sequel Plus
//
//  The Transfer sheet of a MySQL tab.
//

#import <Cocoa/Cocoa.h>

@class SPDatabaseDocument;
@class SPMySQLConnection;
@class SPPostgresProgressSheet;
@class SPPostgresCheckList;

/**
 * The Transfer sheet of a MySQL tab (the Transfer toolbar item), built in code like PostgreSQL's: copies this tab's
 * database (the whole of it, or some tables with their triggers) into a database of another MySQL favorite, through
 * SPMySQLTransfer.
 *
 * - Scope: "Whole database “<db>”" (default) or "Selected tables" (a checkbox list, preset to the tables selected in
 *   the table list).
 * - To: the MySQL favorites (the first that isn't this tab's preselected), the line under it user@host:port, …;
 *   choosing one opens a session to it (the keychain's password, asking for one, never saved, when the server refuses
 *   the user). Database: the session's databases (not the system ones), then "New Database…" (CREATE DATABASE on the
 *   session); the favorite's database selected when listed.
 * - Filter fields beside both menus, as PostgreSQL's (narrow, unset a hidden choice, open the menu when typing pauses).
 * - Mode: "Empty the target database first" (default; confirmed by typing its name, except for a database made in this
 *   sheet) or "Overwrite tables that already exist on the target".
 *
 * The transfer runs on a background thread (a copy of the tab's connection, and the session's) under an
 * SPPostgresProgressSheet task list; the outcome stays on it until Close. Use on the main thread.
 */
__attribute__((visibility("default")))
@interface SPMySQLTransferController : NSObject

- (instancetype)initWithDocument:(SPDatabaseDocument *)document;

/// Shows the sheet on the document's window; the controller keeps itself alive until the sheet (and any transfer)
/// ends.
- (void)beginSheet;

/// Called on the main thread once the sheet and any transfer it started have ended.
@property (copy) void (^didEnd)(void);

#pragma mark - Seams

/// The favorites the To: menu offers (dictionaries). nil (the default): +[SPMySQLFavoriteConnector mysqlFavorites].
@property (copy) NSArray<NSDictionary *> *favorites;
/// This tab's favorite ID (left out of the preselection). nil (the default): the connection controller's.
@property (copy) NSString *ownFavoriteID;
/// Opens the session to a favorite; completion once, on the main thread. nil (the default): an
/// SPMySQLFavoriteConnector (password, else the keychain's; this sheet as the parent of its SSH sheets).
@property (copy) void (^targetConnect)(NSDictionary *favorite, NSString *password, void (^completion)(SPMySQLConnection *connection, NSError *error));
/// The source connection for a transfer, on the transfer's thread. nil (the default): a copy of the tab's connection.
@property (copy) SPMySQLConnection *(^sourceConnect)(void);
@property (copy) void (^passwordPrompt)(NSDictionary *favorite, void (^answer)(NSString *password));
@property (copy) void (^newDatabasePrompt)(NSDictionary *favorite, void (^answer)(NSString *name));
- (void (^)(NSDictionary *favorite, void (^answer)(NSString *name)))newDatabasePrompt __attribute__((objc_method_family(none)));
@property (copy) void (^emptyConfirmation)(NSString *database, NSString *targetDescription, void (^answer)(BOOL confirmed));
@property (copy) void (^filteredMenuOpener)(NSPopUpButton *popup);
/// Called on the transfer's thread at every progress report.
@property (copy) void (^progressObserver)(SPPostgresProgressSheet *sheet);

- (NSAlert *)passwordAlertForFavorite:(NSDictionary *)favorite;
- (NSAlert *)createDatabaseAlertForFavorite:(NSDictionary *)favorite;
- (NSAlert *)emptyConfirmationAlertForDatabase:(NSString *)database targetDescription:(NSString *)description;

/// The sheet's ownership note for a favorite (its user).
+ (NSString *)ownershipNoteForFavorite:(NSDictionary *)favorite;

#pragma mark - For tests

@property (readonly) NSPanel *sheet;
@property (readonly) NSButton *wholeDatabaseRadio;
@property (readonly) NSButton *selectedTablesRadio;
@property (readonly) SPPostgresCheckList *tablesList;
@property (readonly) NSPopUpButton *favoritePopup;
@property (readonly) NSTextField *targetDescriptionField;
@property (readonly) NSTextField *ownershipNoteField;
@property (readonly) NSPopUpButton *databasePopup;
@property (readonly) NSSearchField *favoriteFilterField;
@property (readonly) NSSearchField *databaseFilterField;
@property (readonly) NSTextField *targetStatusField;
@property (readonly) NSButton *retryButton;
@property (readonly) NSButton *emptyModeRadio;
@property (readonly) NSButton *overwriteModeRadio;
@property (readonly) NSButton *transferButton;
@property (readonly, copy) NSString *selectedDatabase;
@property (readonly) SPPostgresProgressSheet *progressSheet;
@property (readonly, copy) NSString *lastErrorMessage;
@property (readonly, copy) NSString *completionNote;

- (IBAction)transfer:(id)sender;
- (IBAction)cancel:(id)sender;

@end
