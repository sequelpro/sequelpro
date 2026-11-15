#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "../Source/Postgres/SPPostgresDumpReader.h"
#import "../Source/Postgres/SPPostgresSQLImporter.h"
#import "../Source/Postgres/SPPostgresErrors.h"

@interface SPPostgresSQLImporterTests : XCTestCase
@property (nonatomic, copy) NSString *directory;
@end

@implementation SPPostgresSQLImporterTests

- (void)setUp
{
	self.continueAfterFailure = NO;
	self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtPath:self.directory error:NULL];
}

- (NSString *)writeText:(NSString *)text named:(NSString *)name
{
	NSString *path = [self.directory stringByAppendingPathComponent:name];
	XCTAssertTrue([[text dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES]);
	return path;
}

- (SPPostgresSQLImporter *)importerForPath:(NSString *)path connection:(PGPostgresConnection *)connection
{
	return [self importerForPath:path connection:connection chunkSize:0];
}

- (SPPostgresSQLImporter *)importerForPath:(NSString *)path connection:(PGPostgresConnection *)connection chunkSize:(NSUInteger)chunkSize
{
	NSError *error = nil;
	SPPostgresDumpReader *reader = [[SPPostgresDumpReader alloc] initWithPath:path error:&error];
	XCTAssertNotNil(reader, @"%@", error);
	if (chunkSize) reader.chunkSize = chunkSize;
	return [[SPPostgresSQLImporter alloc] initWithConnection:connection reader:reader];
}

/// "schema.table" → row count of every table (partitions included) outside the system schemas, plus the checksum
/// of "Sales Data"."Orders 2026" and the sequences' values.
- (NSDictionary *)snapshotOf:(PGPostgresConnection *)connection
{
	NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
	PGPostgresResult *tables = [connection execute:(@"SELECT n.nspname::text, c.relname::text FROM pg_catalog.pg_class c"
													@" JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
													@" WHERE c.relkind IN ('r', 'p') AND n.nspname <> 'information_schema' AND n.nspname NOT LIKE 'pg\\_%'"
													@" ORDER BY 1, 2")];
	XCTAssertNotNil(tables, @"%@", connection.lastError.errorPrimaryMessage);
	for (unsigned long long row = 0; row < tables.numberOfRows; row++) {
		NSString *schema = [tables textValueAtRow:row column:0];
		NSString *table = [tables textValueAtRow:row column:1];
		NSString *sql = [NSString stringWithFormat:@"SELECT count(*)::text FROM \"%@\".\"%@\"", schema, table];
		PGPostgresResult *count = [connection execute:sql];
		XCTAssertNotNil(count, @"%@: %@", sql, connection.lastError.errorPrimaryMessage);
		snapshot[[NSString stringWithFormat:@"%@.%@", schema, table]] = [count textValueAtRow:0 column:0];
	}
	PGPostgresResult *checksum = [connection execute:@"SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM \"Sales Data\".\"Orders 2026\" t"];
	XCTAssertNotNil(checksum, @"%@", connection.lastError.errorPrimaryMessage);
	snapshot[@"checksum"] = [checksum textValueAtRow:0 column:0];
	PGPostgresResult *sequences = [connection execute:(@"SELECT string_agg(schemaname || '.' || sequencename || '=' || coalesce(last_value::text, 'null'), ', ' ORDER BY schemaname COLLATE \"C\", sequencename COLLATE \"C\")"
													   @" FROM pg_catalog.pg_sequences")];
	snapshot[@"sequences"] = [sequences textValueAtRow:0 column:0];
	PGPostgresResult *matview = [connection execute:@"SELECT count(*)::text FROM \"Sales Data\".mv_by_feeling"];
	snapshot[@"mv_by_feeling"] = [matview textValueAtRow:0 column:0] ?: @"(not populated)";
	return snapshot;
}

- (BOOL)table:(NSString *)table existsOn:(PGPostgresConnection *)connection
{
	PGPostgresResult *result = [connection execute:@"SELECT to_regclass($1::text) IS NOT NULL" values:@[table]];
	return [[result textValueAtRow:0 column:0] isEqualToString:@"t"];
}

#pragma mark -

- (void)testImportsPgDump18AndPgDump12
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *source = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
		[SPPostgresTestServers loadFixtureNamed:@"io_source" onPort:port.unsignedIntegerValue];
		NSDictionary *expected = [self snapshotOf:source];
		XCTAssertEqualObjects(expected[@"Sales Data.Orders 2026"], @"7");
		XCTAssertEqualObjects(expected[@"public.audit"], @"7");
		XCTAssertTrue([expected[@"sequences"] containsString:@"public.counter=42"], @"%@", expected[@"sequences"]);
		[source disconnect];

		NSMutableArray *dumps = [NSMutableArray arrayWithObject:@"pgdump12.sql"];
		if (port.unsignedIntegerValue == 55418) [dumps addObject:@"pgdump18.sql"]; // PG 12 can't load a PG 18 dump

		for (NSString *dump in dumps) {
			for (NSNumber *chunkSize in @[@0, @97]) {
				PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
				SPPostgresSQLImporter *importer = [self importerForPath:[SPPostgresTestServers fixturePathNamed:dump] connection:destination chunkSize:chunkSize.unsignedIntegerValue];
				__block NSUInteger progressCalls = 0;
				importer.progress = ^BOOL(unsigned long long bytesRead, unsigned long long fileSize) {
					progressCalls++;
					return bytesRead <= fileSize;
				};

				NSError *error = nil;
				XCTAssertTrue([importer run:&error], @"%@ on %@: %@", dump, port, error.localizedDescription);
				XCTAssertTrue(importer.statementsRun > 20);
				XCTAssertTrue(progressCalls > 20);
				XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
				[destination disconnect];

				PGPostgresConnection *check = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
				NSDictionary *actual = [self snapshotOf:check];
				XCTAssertEqualObjects(actual, expected, @"%@ on %@", dump, port);
				[check disconnect];
			}
		}
	}
}

- (void)testErrorInSingleTransactionRollsBackAndNamesLine
{
	NSString *path = [self writeText:@"CREATE TABLE a(i int);\n\nINSERT INTO a VALUES ('not a number');\n" named:@"bad.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		NSError *error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertEqualObjects(error.domain, SPPostgresErrorDomain);
		XCTAssertEqual(error.code, SPPostgresErrorQueryFailed);
		XCTAssertTrue([error.localizedDescription hasPrefix:@"Line 3: "], @"%@", error.localizedDescription);
		XCTAssertTrue([error.localizedDescription containsString:@"invalid input syntax"], @"%@", error.localizedDescription);
		XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
		XCTAssertFalse([self table:@"public.a" existsOn:destination]);
		[destination disconnect];
	}
}

- (void)testErrorMessageCarriesContext
{
	NSString *text = @"CREATE FUNCTION public.boom() RETURNS void LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'boom' USING DETAIL = 'the detail', HINT = 'the hint'; END $$;\n"
		@"SELECT public.boom();\n";
	NSString *path = [self writeText:text named:@"context.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSError *error = nil;
		XCTAssertFalse([[self importerForPath:path connection:destination] run:&error]);
		NSArray *lines = [error.localizedDescription componentsSeparatedByString:@"\n"];
		XCTAssertEqualObjects(lines.firstObject, @"Line 2: boom");
		XCTAssertTrue([lines containsObject:@"DETAIL: the detail"], @"%@", lines);
		XCTAssertTrue([lines containsObject:@"HINT: the hint"], @"%@", lines);
		XCTAssertTrue([lines.lastObject hasPrefix:@"CONTEXT: PL/pgSQL function boom() line 1 at RAISE"], @"%@", lines);
		[destination disconnect];
	}
}

- (void)testPerStatementModeAsksAndIgnores
{
	NSString *path = [self writeText:@"CREATE TABLE a(i int);\n\nINSERT INTO a VALUES ('not a number');\nINSERT INTO a VALUES (1);\n" named:@"bad.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		importer.singleTransaction = NO;
		__block NSMutableArray *asked = [NSMutableArray array];
		importer.errorHandler = ^SPPostgresImportErrorChoice(NSError *error, SPPostgresDumpItem *item) {
			[asked addObject:[NSString stringWithFormat:@"%lu %@", (unsigned long)item.line, [error.localizedDescription substringToIndex:7]]];
			return SPPostgresImportIgnore;
		};
		NSError *error = nil;
		XCTAssertTrue([importer run:&error], @"%@", error);
		XCTAssertEqualObjects(asked, @[@"3 Line 3:"]);
		XCTAssertEqual(importer.errorsIgnored, 1u);
		XCTAssertEqual(importer.statementsRun, 2u);
		XCTAssertTrue([self table:@"public.a" existsOn:destination]);
		XCTAssertEqualObjects([[destination execute:@"SELECT count(*)::text FROM public.a"] textValueAtRow:0 column:0], @"1");
		[destination disconnect];

		// Stop: fails, and what ran before stays committed
		destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		importer = [self importerForPath:path connection:destination];
		importer.singleTransaction = NO;
		importer.errorHandler = ^SPPostgresImportErrorChoice(NSError *error, SPPostgresDumpItem *item) {
			return SPPostgresImportStop;
		};
		error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertTrue([error.localizedDescription hasPrefix:@"Line 3: "], @"%@", error.localizedDescription);
		XCTAssertTrue([self table:@"public.a" existsOn:destination]);
		XCTAssertEqualObjects([[destination execute:@"SELECT count(*)::text FROM public.a"] textValueAtRow:0 column:0], @"0");
		[destination disconnect];

		// No handler means Stop
		destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		importer = [self importerForPath:path connection:destination];
		importer.singleTransaction = NO;
		XCTAssertFalse([importer run:NULL]);
		XCTAssertTrue([self table:@"public.a" existsOn:destination]);
		[destination disconnect];
	}
}

- (void)testPerStatementSkipsDataOfFailedCopy
{
	NSMutableString *text = [NSMutableString stringWithString:@"COPY public.missing FROM stdin;\n"];
	for (NSUInteger i = 0; i < 2000; i++) [text appendFormat:@"%lu\n", (unsigned long)i];
	[text appendString:@"\\.\nCREATE TABLE b(i int);\n"];
	NSString *path = [self writeText:text named:@"missing.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination chunkSize:128];
		importer.singleTransaction = NO;
		__block NSMutableArray *asked = [NSMutableArray array];
		importer.errorHandler = ^SPPostgresImportErrorChoice(NSError *error, SPPostgresDumpItem *item) {
			[asked addObject:@(item.line)];
			return SPPostgresImportIgnore;
		};
		NSError *error = nil;
		XCTAssertTrue([importer run:&error], @"%@", error);
		XCTAssertEqualObjects(asked, @[@1]);
		XCTAssertEqual(importer.errorsIgnored, 1u);
		XCTAssertEqual(importer.statementsRun, 1u);
		XCTAssertTrue([self table:@"public.b" existsOn:destination]);
		[destination disconnect];
	}
}

- (void)testDumpEndingTheTransactionFails
{
	NSString *path = [self writeText:@"CREATE TABLE a(i int);\nROLLBACK;\nCREATE TABLE b(i int);\n" named:@"rollback.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSError *error = nil;
		XCTAssertFalse([[self importerForPath:path connection:destination] run:&error]);
		XCTAssertEqualObjects(error.localizedDescription, @"Line 2: the file ends the transaction itself; import it with “Run in a single transaction” off.");
		XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
		XCTAssertFalse([self table:@"public.a" existsOn:destination]);
		XCTAssertFalse([self table:@"public.b" existsOn:destination]);
		[destination disconnect];
	}
}

/// text written compressed (1 gzip, 2 bzip2) with the app's SPFileHandle; its bytes.
- (NSData *)compress:(NSString *)text format:(int)format path:(NSString *)path
{
	Class handleClass = NSClassFromString(@"SPFileHandle");
	[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
	id handle = [handleClass performSelector:@selector(fileHandleForWritingAtPath:) withObject:path];
	XCTAssertNotNil(handle);
	NSMethodSignature *signature = [handle methodSignatureForSelector:@selector(setCompressionFormat:)];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	invocation.selector = @selector(setCompressionFormat:);
	[invocation setArgument:&format atIndex:2];
	[invocation invokeWithTarget:handle];
	[handle performSelector:@selector(writeData:) withObject:[text dataUsingEncoding:NSUTF8StringEncoding]];
	[handle performSelector:@selector(closeFile)];
	return [NSData dataWithContentsOfFile:path];
}

- (void)testDamagedOrTruncatedCompressedFilesFail
{
	NSMutableString *text = [NSMutableString stringWithString:@"CREATE TABLE a(i int, t text);\nCOPY a FROM stdin;\n"];
	for (NSUInteger i = 0; i < 3000; i++) [text appendFormat:@"%lu\trow %lu %@\n", (unsigned long)i, (unsigned long)(i * 7919 % 10007), [[NSUUID UUID] UUIDString]];
	[text appendString:@"\\.\nCREATE TABLE b(i int);\n"];

	NSString *gzPath = [self.directory stringByAppendingPathComponent:@"whole.sql.gz"];
	NSString *bzPath = [self.directory stringByAppendingPathComponent:@"whole.sql.bz2"];
	NSData *gz = [self compress:text format:1 path:gzPath];
	NSData *bz = [self compress:text format:2 path:bzPath];

	NSMutableDictionary *damaged = [NSMutableDictionary dictionary];
	damaged[@"half.sql.gz"] = [gz subdataWithRange:NSMakeRange(0, gz.length / 2)];
	damaged[@"half.sql.bz2"] = [bz subdataWithRange:NSMakeRange(0, bz.length / 2)];
	NSMutableData *flipped = [gz mutableCopy];
	unsigned char *bytes = flipped.mutableBytes;
	for (NSUInteger k = flipped.length - 8; k < flipped.length - 4; k++) bytes[k] ^= 0xFF; // the CRC
	damaged[@"crc.sql.gz"] = flipped;

	for (NSNumber *port in [SPPostgresTestServers ports]) {
		// The intact files import
		for (NSString *path in @[gzPath, bzPath]) {
			PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
			NSError *error = nil;
			XCTAssertTrue([[self importerForPath:path connection:destination chunkSize:512] run:&error], @"%@: %@", path, error);
			XCTAssertEqualObjects([[destination execute:@"SELECT count(*)::text FROM public.a"] textValueAtRow:0 column:0], @"3000");
			[destination disconnect];
		}

		for (NSString *name in damaged) {
			NSString *path = [self.directory stringByAppendingPathComponent:name];
			XCTAssertTrue([damaged[name] writeToFile:path atomically:YES]);
			for (NSNumber *chunkSize in @[@0, @512]) {
				PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
				NSError *error = nil;
				SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination chunkSize:chunkSize.unsignedIntegerValue];
				XCTAssertFalse([importer run:&error], @"%@", name);
				XCTAssertTrue([error.localizedDescription hasPrefix:@"The file is damaged or truncated (near line "], @"%@ (%@): %@", name, chunkSize, error.localizedDescription);
				XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
				XCTAssertFalse([self table:@"public.a" existsOn:destination], @"%@ (%@)", name, chunkSize);
				XCTAssertFalse([self table:@"public.b" existsOn:destination], @"%@ (%@)", name, chunkSize);
				[destination disconnect];
			}
		}
	}
}

- (void)testUnsupportedMetaCommandStops
{
	NSString *path = [self writeText:@"CREATE TABLE a(i int);\n\\connect other\nCREATE TABLE b(i int);\n" named:@"meta.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSError *error = nil;
		XCTAssertFalse([[self importerForPath:path connection:destination] run:&error]);
		XCTAssertEqualObjects(error.localizedDescription, @"psql command “\\connect” on line 2 can't be run here.");
		XCTAssertFalse([self table:@"public.a" existsOn:destination], @"rolled back");
		XCTAssertFalse([self table:@"public.b" existsOn:destination]);
		[destination disconnect];
	}
}

- (void)testDumpTransactionLinesSkippedInSingleTransaction
{
	NSString *path = [self writeText:@"BEGIN;\nCREATE TABLE a(i int);\nCOMMIT;\nINSERT INTO a VALUES ('x');\n" named:@"tx.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSError *error = nil;
		XCTAssertFalse([[self importerForPath:path connection:destination] run:&error]);
		XCTAssertTrue([error.localizedDescription hasPrefix:@"Line 4: "], @"%@", error.localizedDescription);
		XCTAssertFalse([self table:@"public.a" existsOn:destination], @"the dump's COMMIT didn't commit");
		[destination disconnect];
	}
}

- (void)testCancelInSingleTransactionLeavesNothing
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		SPPostgresSQLImporter *importer = [self importerForPath:[SPPostgresTestServers fixturePathNamed:@"pgdump12.sql"] connection:destination];
		__block NSUInteger calls = 0;
		importer.progress = ^BOOL(unsigned long long bytesRead, unsigned long long fileSize) {
			return ++calls < 2;
		};
		NSError *error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertEqualObjects(error.domain, SPPostgresErrorDomain);
		XCTAssertEqual(error.code, SPPostgresErrorCancelled);
		XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
		PGPostgresResult *tables = [destination execute:(@"SELECT count(*)::text FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
														 @" WHERE n.nspname <> 'information_schema' AND n.nspname NOT LIKE 'pg\\_%'")];
		XCTAssertEqualObjects([tables textValueAtRow:0 column:0], @"0");
		[destination disconnect];

		// Cancelled in the middle of a COPY block
		destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSMutableString *text = [NSMutableString stringWithString:@"CREATE TABLE a(i int);\nCOPY a FROM stdin;\n"];
		for (NSUInteger i = 0; i < 5000; i++) [text appendFormat:@"%lu\n", (unsigned long)i];
		[text appendString:@"\\.\n"];
		importer = [self importerForPath:[self writeText:text named:@"big.sql"] connection:destination chunkSize:256];
		calls = 0;
		importer.progress = ^BOOL(unsigned long long bytesRead, unsigned long long fileSize) {
			return ++calls < 5; // the first item, then some COPY chunks
		};
		error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertEqual(error.code, SPPostgresErrorCancelled);
		XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
		XCTAssertFalse([self table:@"public.a" existsOn:destination]);
		XCTAssertNotNil([destination execute:@"SELECT 1"]);
		[destination disconnect];
	}
}

#pragma mark - Settings the server doesn't know (R11)

/// A SET or set_config naming a parameter the server doesn't know (42704) is skipped and counted, in both modes; in
/// a single transaction it doesn't abort the transaction. pg_dump 17+'s SET transaction_timeout on PG 12.
- (void)testUnknownSettingsAreSkipped
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		for (NSNumber *single in @[@YES, @NO]) {
			PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
			NSString *path = [self writeText:(@"SET statement_timeout = 0;\n"
											  @"SET transaction_timeout = 0;\n"
											  @"SET sp_no_such_setting = 0;\n"
											  @"SET sp_no_such_setting TO 1;\n"
											  @"SELECT pg_catalog.set_config('sp_no_such_other', '1', false);\n"
											  @"CREATE TABLE public.after_settings (i int);\n"
											  @"INSERT INTO public.after_settings VALUES (1);\n") named:@"settings.sql"];
			SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
			importer.singleTransaction = single.boolValue;
			__block NSUInteger asked = 0;
			importer.errorHandler = ^SPPostgresImportErrorChoice(NSError *error, SPPostgresDumpItem *item) {
				asked++;
				return SPPostgresImportStop;
			};
			NSError *error = nil;
			XCTAssertTrue([importer run:&error], @"port %@ single %@: %@", port, single, error.localizedDescription);
			XCTAssertEqual(asked, 0u, @"no error to ask about");
			BOOL knowsTransactionTimeout = destination.serverVersion >= 170000;
			NSMutableArray *expected = [NSMutableArray array];
			if (!knowsTransactionTimeout) [expected addObject:@"transaction_timeout"];
			[expected addObjectsFromArray:@[@"sp_no_such_setting", @"sp_no_such_other"]];
			XCTAssertEqualObjects(importer.skippedSettings, expected, @"port %@", port);
			XCTAssertEqual(importer.settingsSkipped, expected.count + 1, @"each statement counted (the unknown one twice)");
			XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
			PGPostgresResult *rows = [destination execute:@"SELECT count(*)::text FROM public.after_settings"];
			XCTAssertEqualObjects([rows textValueAtRow:0 column:0], @"1", @"what follows ran and committed");
			[destination disconnect];
		}
	}
}

/// A SET that fails for another reason (a bad value) is still an error.
- (void)testBadSettingValueStillFails
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSString *path = [self writeText:@"CREATE TABLE public.before_bad (i int);\nSET statement_timeout = 'not a number';\n" named:@"bad-setting.sql"];
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		NSError *error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertTrue([error.localizedDescription hasPrefix:@"Line 2:"], @"%@", error.localizedDescription);
		XCTAssertEqual(importer.settingsSkipped, 0u);
		XCTAssertFalse([self table:@"public.before_bad" existsOn:destination], @"rolled back");
		[destination disconnect];
	}
}

#pragma mark - A statement the cancel interrupts

/// A statement waiting on a lock, interrupted through a cancel token after progress starts answering NO: the import
/// reports the cancel (not the server's "canceling statement"), never asks about the error, and rolls back.
- (void)testCancelledStatementReportsCancel
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		for (NSNumber *single in @[@YES, @NO]) {
			PGPostgresConnection *holder = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
			XCTAssertNotNil([holder execute:@"CREATE TABLE public.locked (i int)"]);
			XCTAssertNotNil([holder execute:@"BEGIN"]);
			XCTAssertNotNil([holder execute:@"LOCK TABLE public.locked IN ACCESS EXCLUSIVE MODE"]);

			PGPostgresConnection *destination = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
			NSString *path = [self writeText:@"CREATE TABLE public.before_lock (i int);\nINSERT INTO public.locked VALUES (1);\nCREATE TABLE public.after_lock (i int);\n" named:@"lock.sql"];
			SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
			importer.singleTransaction = single.boolValue;
			__block BOOL cancelFlag = NO;
			__block NSUInteger asked = 0;
			importer.progress = ^BOOL(unsigned long long bytesRead, unsigned long long fileSize) {
				@synchronized(self) { return !cancelFlag; }
			};
			importer.errorHandler = ^SPPostgresImportErrorChoice(NSError *error, SPPostgresDumpItem *item) {
				asked++;
				return SPPostgresImportIgnore;
			};
			PGPostgresCancelToken *token = [destination newCancelToken];
			__block BOOL done = NO, ok = YES;
			__block NSError *runError = nil;
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
				NSError *theError = nil;
				ok = [importer run:&theError];
				runError = theError;
				dispatch_async(dispatch_get_main_queue(), ^{ done = YES; });
			});
			NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
			while (![[[holder execute:@"SELECT count(*)::text FROM pg_catalog.pg_locks WHERE NOT granted AND relation = 'public.locked'::regclass"] textValueAtRow:0 column:0] isEqualToString:@"1"]
				   && [deadline timeIntervalSinceNow] > 0) {
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
			}
			XCTAssertFalse(done, @"the import waits on the lock");
			@synchronized(self) { cancelFlag = YES; }
			XCTAssertTrue([token cancel]);
			deadline = [NSDate dateWithTimeIntervalSinceNow:10];
			while (!done && [deadline timeIntervalSinceNow] > 0) {
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
			}
			XCTAssertTrue(done);
			[token invalidate];
			XCTAssertFalse(ok);
			XCTAssertEqualObjects(runError.domain, SPPostgresErrorDomain);
			XCTAssertEqual(runError.code, SPPostgresErrorCancelled, @"%@", runError.localizedDescription);
			XCTAssertEqual(asked, 0u, @"a cancel isn't an error to ask about");
			XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
			XCTAssertNotNil([holder execute:@"ROLLBACK"]);
			XCTAssertEqual([self table:@"public.before_lock" existsOn:holder], !single.boolValue, @"single transaction: rolled back; otherwise it stays");
			XCTAssertFalse([self table:@"public.after_lock" existsOn:holder], @"nothing ran after the cancel");
			[destination disconnect];
			[holder disconnect];
		}
	}
}

#pragma mark - Stage 7: statements before the import

- (void)testStatementsBeforeImportRunFirstInTheTransaction
{
	NSString *path = [self writeText:@"INSERT INTO public.first VALUES (2);\n" named:@"after-first.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		XCTAssertNotNil([destination execute:@"CREATE TABLE public.gone (i int)"]);
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		importer.statementsBeforeImport = @[@"DROP TABLE public.gone", @"CREATE TABLE public.first (i int)", @"INSERT INTO public.first VALUES (1)"];
		NSError *error = nil;
		XCTAssertTrue([importer run:&error], @"%@", error.localizedDescription);
		XCTAssertEqual(importer.statementsRun, 4u);
		XCTAssertFalse([self table:@"public.gone" existsOn:destination]);
		XCTAssertEqualObjects([[destination execute:@"SELECT string_agg(i::text, ',' ORDER BY i) FROM public.first"] textValueAtRow:0 column:0], @"1,2");
		[destination disconnect];
	}
}

- (void)testFailedStatementBeforeImportRollsBackWithoutLineNumber
{
	NSString *path = [self writeText:@"CREATE TABLE public.never (i int);\n" named:@"never.sql"];
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		XCTAssertNotNil([destination execute:@"CREATE TABLE public.kept (i int)"]);
		XCTAssertNotNil([destination execute:@"CREATE VIEW public.kept_view AS SELECT i FROM public.kept"]);
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		importer.statementsBeforeImport = @[@"CREATE TABLE public.early (i int)", @"DROP TABLE public.kept"];
		NSError *error = nil;
		XCTAssertFalse([importer run:&error]);
		XCTAssertEqualObjects(error.domain, SPPostgresErrorDomain);
		XCTAssertEqual(error.code, SPPostgresErrorQueryFailed);
		XCTAssertEqualObjects(error.userInfo[SPPostgresSQLStateErrorKey], @"2BP01");
		NSArray *lines = [error.localizedDescription componentsSeparatedByString:@"\n"];
		XCTAssertFalse([lines.firstObject hasPrefix:@"Line "], @"%@", error.localizedDescription);
		XCTAssertTrue([lines.firstObject containsString:@"cannot drop table"], @"%@", error.localizedDescription);
		XCTAssertTrue([lines containsObject:@"DETAIL: view kept_view depends on table kept"], @"%@", lines);
		XCTAssertTrue([lines.lastObject hasPrefix:@"HINT: "], @"%@", lines);
		XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
		XCTAssertFalse([self table:@"public.early" existsOn:destination], @"rolled back");
		XCTAssertFalse([self table:@"public.never" existsOn:destination], @"the file never ran");
		XCTAssertTrue([self table:@"public.kept" existsOn:destination]);
		[destination disconnect];
	}
}

#pragma mark - Batching

/// Statements batched (one round trip per batch) load as one by one: counted once each, and a 450-statement file
/// takes a handful of round trips. Counted on -[PGPostgresConnection executeStatements:].
- (void)testBatchedStatementsLoadAndCount
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
		NSMutableString *sql = [NSMutableString stringWithString:@"CREATE TABLE public.b (i int, note text);\n"];
		for (NSUInteger i = 1; i <= 450; i++) [sql appendFormat:@"INSERT INTO public.b VALUES (%lu, 'x;y') -- a comment\n;\n", (unsigned long)i];
		[sql appendString:@"COPY public.b (i, note) FROM stdin;\n1000\tcopied\n\\.\n"];
		[sql appendString:@"CREATE INDEX b_i ON public.b (i);\n"];
		NSString *path = [self writeText:sql named:@"batched.sql"];

		__block NSUInteger roundTrips = 0;
		SEL selector = @selector(executeStatements:);
		Method method = class_getInstanceMethod([PGPostgresConnection class], selector);
		IMP original = method_getImplementation(method);
		method_setImplementation(method, imp_implementationWithBlock(^id(PGPostgresConnection *me, NSString *batchSQL) {
			if (me == destination) roundTrips++;
			return ((id (*)(id, SEL, NSString *))original)(me, selector, batchSQL);
		}));
		SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
		importer.batchesStatements = YES;
		NSMutableArray *observed = [NSMutableArray array];
		importer.itemObserver = ^(SPPostgresDumpItem *item) { [observed addObject:@(item.line)]; };
		NSError *error = nil;
		BOOL ok = [importer run:&error];
		method_setImplementation(method, original);
		XCTAssertTrue(ok, @"port %@: %@", port, error.localizedDescription);
		XCTAssertEqual(importer.statementsRun, 453u);
		XCTAssertEqual(observed.count, 453u, @"each item observed once");
		XCTAssertGreaterThan(roundTrips, 0u);
		XCTAssertLessThanOrEqual(roundTrips, 4u, @"port %@: %lu", port, (unsigned long)roundTrips);
		PGPostgresResult *count = [destination execute:@"SELECT count(*)::text, count(*) FILTER (WHERE note = 'x;y')::text FROM public.b"];
		XCTAssertEqualObjects([count textValueAtRow:0 column:0], @"451");
		XCTAssertEqualObjects([count textValueAtRow:0 column:1], @"450");
		XCTAssertTrue([self table:@"public.b_i" existsOn:destination]);
	}
}

/// A failing statement in a batch (at run time, or a syntax error that fails the whole batch before it runs) is
/// reported as without batching, with its own line, and everything rolls back.
- (void)testBatchFailureNamesTheStatement
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		for (NSString *bad in @[@"INSERT INTO public.c VALUES (1/0)", @"INSERT INTO public.c VALUES (1"]) {
			PGPostgresConnection *destination = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
			NSMutableString *sql = [NSMutableString stringWithString:@"CREATE TABLE public.c (i int);\n"];
			for (NSUInteger i = 1; i <= 50; i++) [sql appendFormat:@"INSERT INTO public.c VALUES (%lu);\n", (unsigned long)i];
			// Line 52
			[sql appendFormat:@"%@;\n", bad];
			for (NSUInteger i = 1; i <= 50; i++) [sql appendFormat:@"INSERT INTO public.c VALUES (%lu);\n", (unsigned long)i];
			NSString *path = [self writeText:sql named:@"failing.sql"];
			SPPostgresSQLImporter *importer = [self importerForPath:path connection:destination];
			importer.batchesStatements = YES;
			NSError *error = nil;
			XCTAssertFalse([importer run:&error]);
			XCTAssertTrue([error.localizedDescription hasPrefix:@"Line 52: "], @"port %@, %@: %@", port, bad, error.localizedDescription);
			XCTAssertEqual(destination.transactionStatus, PGPostgresTransactionIdle);
			XCTAssertFalse([self table:@"public.c" existsOn:destination], @"rolled back");
		}
	}
}

@end
