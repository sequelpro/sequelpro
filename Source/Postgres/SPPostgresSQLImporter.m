#import "SPPostgresSQLImporter.h"
#import "SPPostgresDumpReader.h"
#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import <PostgresKit/PostgresKit.h>

@interface SPPostgresSQLImporter ()

- (NSString *)_serverMessageFallingBackTo:(NSString *)fallback;
- (void)_rollBackIfInTransaction;

@end

@implementation SPPostgresSQLImporter

@synthesize singleTransaction;
@synthesize errorHandler;
@synthesize progress;
@synthesize statementsRun;
@synthesize errorsIgnored;
@synthesize settingsSkipped;
@synthesize statementsBeforeImport;
@synthesize statementBeforeImportObserver;
@synthesize itemObserver;
@synthesize copyDataObserver;
@synthesize commitObserver;
@synthesize batchesStatements;

/// A batch is sent once it holds this many statements, or this many characters
static const NSUInteger SPImportBatchStatements = 200;
static const NSUInteger SPImportBatchCharacters = 1024 * 1024;

/**
 * Runs the statements held back in batch (emptied) in one round trip, inside a savepoint. NO when one fails: then
 * *failure (retained) is its error as -run: reports a failed item ("Line n: …"), found by rolling the batch back and
 * running its statements one by one; or *cancelled when stillGoing says the run was cancelled.
 */
- (BOOL)_runBatch:(NSMutableArray *)batch failure:(NSError **)failure cancelled:(BOOL *)cancelled stillGoing:(BOOL (^)(void))stillGoing
{
	if (![batch count]) return YES;
	NSArray *items = [[batch copy] autorelease];
	[batch removeAllObjects];

	if ([items count] > 1) {
		// The savepoint on its own: the server parses a whole batch before running any of it, so a syntax error fails
		// it before a SAVEPOINT inside it would exist
		NSError *batchError = nil;
		if (!SPPostgresExecuteWithDetails(connection, @"SAVEPOINT sp_import_batch", nil, &batchError)) {
			*failure = [batchError retain];
			return NO;
		}
		// Each statement on lines of its own: a trailing -- comment can't swallow the separator
		NSMutableString *sql = [NSMutableString string];
		for (SPPostgresDumpItem *item in items) [sql appendFormat:@"%@\n;\n", [item sql]];
		[sql appendString:@"RELEASE SAVEPOINT sp_import_batch"];
		if (SPPostgresExecuteStatementsWithDetails(connection, sql, &batchError)) {
			statementsRun += [items count];
			return YES;
		}
		if (!stillGoing()) {
			*cancelled = YES;
			return NO;
		}
		// Undone, then one by one: the failing statement is named
		NSError *undoError = nil;
		if (!SPPostgresExecuteWithDetails(connection, @"ROLLBACK TO SAVEPOINT sp_import_batch", nil, &undoError)
			|| !SPPostgresExecuteWithDetails(connection, @"RELEASE SAVEPOINT sp_import_batch", nil, &undoError)) {
			*failure = [(undoError ?: batchError) retain];
			return NO;
		}
	}

	for (SPPostgresDumpItem *item in items) {
		NSError *executeError = nil;
		if (SPPostgresExecuteWithDetails(connection, [item sql], nil, &executeError)) {
			statementsRun++;
			continue;
		}
		if (!stillGoing()) {
			*cancelled = YES;
			return NO;
		}
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Line %lu: %@", @"Postgres import: error at a line of the file"), (unsigned long)[item line], [self _serverMessageFallingBackTo:[executeError localizedDescription]]];
		*failure = [SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil) retain];
		return NO;
	}
	return YES;
}

- (instancetype)initWithConnection:(PGPostgresConnection *)theConnection reader:(SPPostgresDumpReader *)theReader
{
	if ((self = [super init])) {
		connection = [theConnection retain];
		reader = [theReader retain];
		singleTransaction = YES;
	}
	return self;
}

- (void)dealloc
{
	[connection release];
	[reader release];
	[errorHandler release];
	[progress release];
	[skippedSettings release];
	[statementsBeforeImport release];
	[statementBeforeImportObserver release];
	[itemObserver release];
	[copyDataObserver release];
	[commitObserver release];
	[super dealloc];
}

#pragma mark - Helpers

/// The server's last error as the import reports it: its message, then DETAIL, HINT and CONTEXT lines.
- (NSString *)_serverMessageFallingBackTo:(NSString *)fallback
{
	PGPostgresError *serverError = [connection isConnected] ? [connection lastError] : nil;
	NSString *primary = [serverError errorPrimaryMessage];
	if (![primary length]) {
		if ([fallback length]) return fallback;
		NSString *libpq = [connection libpqErrorMessage];
		return [libpq length] ? libpq : NSLocalizedString(@"The statement failed.", @"Postgres import: statement failed without a message");
	}
	NSMutableString *message = [NSMutableString stringWithString:primary];
	[message appendString:SPPostgresErrorDetailLines(serverError)];
	NSString *context = [[serverError errorContext] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([context length]) [message appendFormat:@"\n%@ %@", NSLocalizedString(@"CONTEXT:", @"Postgres import: error context label"), context];
	return message;
}

- (void)_rollBackIfInTransaction
{
	PGPostgresTransactionStatus status = [connection transactionStatus];
	if (status == PGPostgresTransactionInTransaction || status == PGPostgresTransactionInError) {
		[connection execute:@"ROLLBACK"];
	}
}

/// YES for a statement that opens or ends a transaction block (BEGIN, START TRANSACTION, COMMIT, END).
static BOOL SPIsTransactionControl(NSString *sql)
{
	static NSRegularExpression *pattern = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		pattern = [[NSRegularExpression alloc] initWithPattern:@"\\A\\s*(BEGIN|START\\s+TRANSACTION|COMMIT|END)(?!\\s+PREPARED\\b)(\\s.*)?\\z"
													   options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
														 error:NULL];
	});
	// (BEGIN ATOMIC only appears inside CREATE FUNCTION, never at the start of a statement)
	return [pattern firstMatchInString:sql options:0 range:NSMakeRange(0, [sql length])] != nil;
}

/**
 * The configuration parameter a top-level `SET [SESSION | LOCAL] name {TO | =} …` or
 * `SELECT [pg_catalog.]set_config('name', …)` sets, or nil for any other statement (SET ROLE, SET SESSION
 * AUTHORIZATION, SET TRANSACTION, SET CONSTRAINTS and SET TIME ZONE name no parameter).
 */
static NSString *SPConfigurationParameterSetBy(NSString *sql)
{
	static NSRegularExpression *setPattern = nil, *setConfigPattern = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		setPattern = [[NSRegularExpression alloc] initWithPattern:@"\\A\\s*SET\\s+(?:(?:SESSION|LOCAL)\\s+)?(\"(?:[^\"]|\"\")+\"|[A-Za-z_][A-Za-z0-9_$]*(?:\\.[A-Za-z_][A-Za-z0-9_$]*)*)\\s*(?:=|\\bTO\\b)"
														  options:NSRegularExpressionCaseInsensitive error:NULL];
		setConfigPattern = [[NSRegularExpression alloc] initWithPattern:@"\\A\\s*SELECT\\s+(?:pg_catalog\\s*\\.\\s*)?set_config\\s*\\(\\s*'((?:[^']|'')*)'\\s*,"
																options:NSRegularExpressionCaseInsensitive error:NULL];
	});
	NSRange all = NSMakeRange(0, [sql length]);
	NSTextCheckingResult *match = [setPattern firstMatchInString:sql options:0 range:all];
	if (match) {
		NSString *name = [sql substringWithRange:[match rangeAtIndex:1]];
		if ([name hasPrefix:@"\""]) return [[name substringWithRange:NSMakeRange(1, [name length] - 2)] stringByReplacingOccurrencesOfString:@"\"\"" withString:@"\""];
		// (SET ROLE / SESSION AUTHORIZATION / TRANSACTION / CONSTRAINTS / TIME ZONE never take "=" or TO after one word)
		return [name lowercaseString];
	}
	match = [setConfigPattern firstMatchInString:sql options:0 range:all];
	if (match) return [[sql substringWithRange:[match rangeAtIndex:1]] stringByReplacingOccurrencesOfString:@"''" withString:@"'"];
	return nil;
}

- (NSArray *)skippedSettings
{
	return skippedSettings ? [[skippedSettings copy] autorelease] : @[];
}

/**
 * Runs a statement that sets a configuration parameter (named setting). YES when it ran, or when the server doesn't
 * know the parameter (42704): then it is counted as skipped. Inside a transaction it runs under a savepoint, so that
 * failure leaves the transaction usable. NO when it failed otherwise (the server's error is the connection's
 * lastError, *error set).
 */
- (BOOL)_runSetting:(NSString *)setting statement:(NSString *)sql error:(NSError **)error
{
	BOOL savepoint = [connection transactionStatus] == PGPostgresTransactionInTransaction;
	if (savepoint && !SPPostgresExecuteWithDetails(connection, @"SAVEPOINT sp_import_setting", nil, error)) return NO;

	if (SPPostgresExecuteWithDetails(connection, sql, nil, error)) {
		if (savepoint) SPPostgresExecuteWithDetails(connection, @"RELEASE SAVEPOINT sp_import_setting", nil, NULL);
		statementsRun++;
		return YES;
	}

	PGPostgresError *serverError = [connection isConnected] ? [connection lastError] : nil;
	if (![[serverError errorStateCode] isEqualToString:@"42704"]) return NO;

	// The server doesn't know the parameter: skipped
	if (savepoint) {
		NSError *undoError = nil;
		if (!SPPostgresExecuteWithDetails(connection, @"ROLLBACK TO SAVEPOINT sp_import_setting", nil, &undoError)
			|| !SPPostgresExecuteWithDetails(connection, @"RELEASE SAVEPOINT sp_import_setting", nil, &undoError)) {
			if (error) *error = undoError;
			return NO;
		}
	}
	settingsSkipped++;
	if (!skippedSettings) skippedSettings = [[NSMutableArray alloc] init];
	if (![skippedSettings containsObject:setting]) [skippedSettings addObject:setting];
	return YES;
}

#pragma mark - Running

- (BOOL)run:(NSError **)error
{
	statementsRun = 0;
	errorsIgnored = 0;
	settingsSkipped = 0;
	[skippedSettings release];
	skippedSettings = nil;

	NSError *failure = nil;
	BOOL cancelled = NO;
	BOOL ignoreAll = NO;

	if (singleTransaction) {
		if (!SPPostgresExecuteWithDetails(connection, @"BEGIN", nil, &failure)) {
			if (error) *error = failure;
			return NO;
		}
	}

	BOOL (^stillGoing)(void) = ^BOOL(void) {
		if (!self->progress) return YES;
		return self->progress([self->reader bytesRead], [self->reader fileSize]);
	};

	// The caller's statements first (in the transaction, when there is one): a failure is the server's message with
	// its DETAIL and HINT, as there is no line of the file to name
	NSUInteger beforeIndex = 0;
	for (NSString *sql in statementsBeforeImport) {
		if (statementBeforeImportObserver) statementBeforeImportObserver(beforeIndex);
		beforeIndex++;
		NSError *statementError = nil;
		if (SPPostgresExecuteWithDetails(connection, sql, nil, &statementError)) {
			statementsRun++;
			if (stillGoing()) continue;
			cancelled = YES;
		}
		else if (!stillGoing()) {
			cancelled = YES;
		}
		else {
			[self _rollBackIfInTransaction];
			if (error) *error = statementError;
			return NO;
		}
		break;
	}
	if (cancelled) {
		[self _rollBackIfInTransaction];
		if (error) *error = SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The import was cancelled.", @"Postgres import: cancelled"), nil);
		return NO;
	}

	BOOL batching = batchesStatements && singleTransaction;
	NSMutableArray *batch = [NSMutableArray array];
	NSUInteger batchCharacters = 0;

	for (;;) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		BOOL stop = NO;

		NSError *readError = nil;
		SPPostgresDumpItem *item = [reader nextItem:&readError];
		if (!item) {
			if (readError) failure = [readError retain];
			[pool drain];
			break;
		}

		NSString *itemFailure = nil; // the server's message when the item failed
		if (itemObserver && [item kind] != SPPostgresDumpItemMetaCommand) itemObserver(item);

		// Batching: a plain statement waits in the batch; anything else sends the batch first
		BOOL batched = batching && [item kind] == SPPostgresDumpItemStatement && !SPIsTransactionControl([item sql]) && !SPConfigurationParameterSetBy([item sql]);
		if (batched) {
			[batch addObject:item];
			batchCharacters += [[item sql] length];
		}
		if ([batch count] && (!batched || [batch count] >= SPImportBatchStatements || batchCharacters >= SPImportBatchCharacters)) {
			NSError *batchFailure = nil;
			BOOL batchCancelled = NO;
			if (![self _runBatch:batch failure:&batchFailure cancelled:&batchCancelled stillGoing:stillGoing]) {
				if (batchCancelled) cancelled = YES;
				else failure = batchFailure; // retained
				stop = YES;
			}
			batchCharacters = 0;
		}

		if (!stop && !batched) switch ([item kind]) {
			case SPPostgresDumpItemMetaCommand: {
				NSString *command = [[[item sql] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];
				if ([command isEqualToString:@"\\restrict"] || [command isEqualToString:@"\\unrestrict"]) break;
				NSString *message = [NSString stringWithFormat:NSLocalizedString(@"psql command “%@” on line %lu can't be run here.", @"Postgres import: unsupported psql meta-command"), command, (unsigned long)[item line]];
				failure = [SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil) retain];
				stop = YES;
				break;
			}

			case SPPostgresDumpItemStatement: {
				if (singleTransaction && SPIsTransactionControl([item sql])) break;
				NSError *executeError = nil;
				NSString *setting = SPConfigurationParameterSetBy([item sql]);
				if (setting) {
					if (![self _runSetting:setting statement:[item sql] error:&executeError]) {
						itemFailure = [self _serverMessageFallingBackTo:[executeError localizedDescription]];
					}
				}
				else if (SPPostgresExecuteWithDetails(connection, [item sql], nil, &executeError)) {
					statementsRun++;
				}
				else {
					itemFailure = [self _serverMessageFallingBackTo:[executeError localizedDescription]];
				}
				break;
			}

			case SPPostgresDumpItemCopy: {
				__block NSError *dataError = nil;
				__block BOOL copyCancelled = NO;
				NSError *copyError = nil;
				BOOL copied = [connection copyIn:[item sql] provider:^NSData *(BOOL *cancel) {
					NSError *nextError = nil;
					NSData *data = [self->reader nextCopyData:&nextError];
					if (!data && nextError) {
						dataError = [nextError retain];
						*cancel = YES;
						return nil;
					}
					if (data && !stillGoing()) {
						copyCancelled = YES;
						*cancel = YES;
						return nil;
					}
					if (data && self->copyDataObserver) self->copyDataObserver(data);
					return data;
				} error:&copyError];

				if (copied) {
					statementsRun++;
				}
				else if (dataError) {
					failure = dataError; // retained by the provider
					stop = YES;
				}
				else if (copyCancelled) {
					cancelled = YES;
					stop = YES;
				}
				else {
					itemFailure = [self _serverMessageFallingBackTo:[copyError localizedDescription]];
				}
				break;
			}
		}

		// In one transaction, nothing in the file may end it (ROLLBACK, ABORT, COMMIT AND NO CHAIN…): what follows
		// would commit statement by statement, unnoticed
		if (singleTransaction && !stop && !itemFailure && [item kind] != SPPostgresDumpItemMetaCommand
			&& [connection transactionStatus] == PGPostgresTransactionIdle) {
			NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Line %lu: the file ends the transaction itself; import it with “Run in a single transaction” off.", @"Postgres import: the file ends the import's transaction"), (unsigned long)[item line]];
			failure = [SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil) retain];
			stop = YES;
		}

		// A statement the cancel interrupted (or any failure after Cancel) is the cancel, not an error to report or ask about
		if (itemFailure && !stop && !stillGoing()) {
			cancelled = YES;
			stop = YES;
		}

		if (itemFailure && !stop) {
			NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Line %lu: %@", @"Postgres import: error at a line of the file"), (unsigned long)[item line], itemFailure];
			NSError *itemError = SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil);

			SPPostgresImportErrorChoice choice = SPPostgresImportStop;
			if (!singleTransaction) {
				if (ignoreAll) choice = SPPostgresImportIgnoreAll;
				else if (errorHandler) choice = errorHandler(itemError, item);
			}

			if (choice == SPPostgresImportIgnore || choice == SPPostgresImportIgnoreAll) {
				errorsIgnored++;
				if (choice == SPPostgresImportIgnoreAll) ignoreAll = YES;
			}
			else {
				failure = [itemError retain];
				stop = YES;
			}
		}

		if (!stop && !stillGoing()) {
			cancelled = YES;
			stop = YES;
		}

		[pool drain];
		if (stop) break;
	}

	// What the batch still holds, before the COMMIT
	if (!failure && !cancelled && [batch count]) {
		NSError *batchFailure = nil;
		BOOL batchCancelled = NO;
		if (![self _runBatch:batch failure:&batchFailure cancelled:&batchCancelled stillGoing:stillGoing]) {
			if (batchCancelled) cancelled = YES;
			else failure = batchFailure; // retained
		}
	}

	[failure autorelease];

	if (cancelled) {
		[self _rollBackIfInTransaction];
		if (error) *error = SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The import was cancelled.", @"Postgres import: cancelled"), nil);
		return NO;
	}

	if (failure) {
		// Single transaction: everything is undone. Otherwise only a transaction the dump itself left open.
		[self _rollBackIfInTransaction];
		if (error) *error = failure;
		return NO;
	}

	if (singleTransaction) {
		if (commitObserver) commitObserver();
		NSError *commitError = nil;
		if (!SPPostgresExecuteWithDetails(connection, @"COMMIT", nil, &commitError)) {
			[self _rollBackIfInTransaction];
			if (!stillGoing()) commitError = SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The import was cancelled.", @"Postgres import: cancelled"), nil);
			if (error) *error = commitError;
			return NO;
		}
	}

	return YES;
}

@end
