#import "SPPostgresDumpReader.h"
#import "SPPostgresStatementSplitter.h"
#import "SPPostgresErrors.h"
#import "SPPostgresCompressedFileReader.h"

@implementation SPPostgresDumpItem

@synthesize kind;
@synthesize sql;
@synthesize line;

- (instancetype)initWithKind:(SPPostgresDumpItemKind)theKind sql:(NSString *)theSQL line:(NSUInteger)theLine
{
	if ((self = [super init])) {
		kind = theKind;
		sql = [theSQL copy];
		line = theLine;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %ld line %lu: %@>", [self className], (long)kind, (unsigned long)line, sql];
}

- (void)dealloc
{
	[sql release];
	[super dealloc];
}

@end

#pragma mark -

static BOOL SPDumpIsWhitespace(unichar c)
{
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v' || c == 0xA0 || c == 0x2028 || c == 0x2029 || c == 0xFEFF;
}

/// The length of the longest prefix of bytes[0..<count] that doesn't end inside a UTF-8 sequence.
static NSUInteger SPCompleteUTF8Length(const unsigned char *bytes, NSUInteger count)
{
	// Look back at most 3 bytes for the start of the last sequence
	NSUInteger back = 0;
	while (back < count && back < 4) {
		unsigned char c = bytes[count - 1 - back];
		if ((c & 0xC0) != 0x80) {
			NSUInteger needed = (c < 0x80) ? 1 : ((c & 0xE0) == 0xC0) ? 2 : ((c & 0xF0) == 0xE0) ? 3 : ((c & 0xF8) == 0xF0) ? 4 : 1;
			return (back + 1 >= needed) ? count : count - 1 - back;
		}
		back++;
	}
	return count; // continuation bytes only: invalid, let the decoder say so
}

@interface SPPostgresDumpReader ()

- (BOOL)_readMore:(NSError **)error;
- (void)_advanceTo:(NSUInteger)index;
- (NSString *)_stringFrom:(NSUInteger)start to:(NSUInteger)end;

@end

@implementation SPPostgresDumpReader

@synthesize chunkSize;
@synthesize waitForMoreData;

- (instancetype)initWithPath:(NSString *)path error:(NSError **)error
{
	if ((self = [super init])) {
		source = [[SPPostgresCompressedFileReader alloc] initWithPath:path error:error];
		if (!source) {
			[self release];
			return nil;
		}
		chunkSize = 1024 * 1024;
		pendingBytes = [[NSMutableData alloc] init];
		currentLine = 1;
		atStart = YES;
	}
	return self;
}

- (void)dealloc
{
	[source release];
	[pendingBytes release];
	[readError release];
	[waitForMoreData release];
	if (characters) free(characters);
	[super dealloc];
}

- (unsigned long long)bytesRead
{
	return [source bytesRead];
}

- (unsigned long long)fileSize
{
	return [source fileSize];
}

/// Records error as the reader's error (returned again by later calls); NO.
- (BOOL)_fail:(NSString *)message
{
	[readError release];
	readError = [SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil) retain];
	return NO;
}

- (BOOL)_failDamaged
{
	return [self _fail:[NSString stringWithFormat:NSLocalizedString(@"The file is damaged or truncated (near line %lu).", @"Postgres import: damaged or truncated file"), (unsigned long)currentLine]];
}

/**
 * Reads up to count decompressed bytes into bytes, setting *read (0 at the end of the file). NO (with readError set)
 * when the file can't be read, or a compressed file is damaged or ends before its stream does.
 */
- (BOOL)_readBytes:(void *)bytes count:(NSUInteger)count read:(NSUInteger *)read
{
	BOOL damaged = NO;
	if ([source readBytes:bytes count:count read:read damaged:&damaged]) return YES;
	if (damaged) return [self _failDamaged];
	return [self _fail:[NSString stringWithFormat:NSLocalizedString(@"The file can't be read (near line %lu).", @"Postgres import: file read error"), (unsigned long)currentLine]];
}

#pragma mark - Buffer

/**
 * Reads the next chunk and appends its text to the buffer (dropping what was handed out). Returns NO with an error
 * when the file isn't UTF-8; at the end of the file sets endOfFile and returns YES.
 */
- (BOOL)_readMore:(NSError **)error
{
	if (endOfFile) return YES;

	// Drop what was handed out
	if (position > 0) {
		if (length > position) memmove(characters, characters + position, (length - position) * sizeof(unichar));
		length -= position;
		position = 0;
	}

	NSUInteger wanted = MAX(chunkSize, (NSUInteger)1);
	NSUInteger pendingLength = [pendingBytes length];
	[pendingBytes setLength:pendingLength + wanted];
	NSUInteger got = 0;
	if (![self _readBytes:(unsigned char *)[pendingBytes mutableBytes] + pendingLength count:wanted read:&got]) {
		[pendingBytes setLength:pendingLength];
		if (error) *error = [[readError retain] autorelease];
		return NO;
	}
	// A file still being written: wait for more, or for its end
	while (!got && waitForMoreData) {
		NSError *waitError = nil;
		if (!waitForMoreData(&waitError)) {
			if (waitError) {
				[pendingBytes setLength:pendingLength];
				[readError release];
				readError = [waitError retain];
				if (error) *error = [[readError retain] autorelease];
				return NO;
			}
			break;
		}
		if (![self _readBytes:(unsigned char *)[pendingBytes mutableBytes] + pendingLength count:wanted read:&got]) {
			[pendingBytes setLength:pendingLength];
			if (error) *error = [[readError retain] autorelease];
			return NO;
		}
	}
	[pendingBytes setLength:pendingLength + got];
	if (!got) endOfFile = YES;

	NSUInteger usable = endOfFile ? [pendingBytes length] : SPCompleteUTF8Length([pendingBytes bytes], [pendingBytes length]);
	if (!usable) return YES;

	NSString *text = [[NSString alloc] initWithBytes:[pendingBytes bytes] length:usable encoding:NSUTF8StringEncoding];
	if (!text) {
		[readError release];
		readError = [SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"The file isn't valid UTF-8 text (near line %lu).", @"Postgres import: file not UTF-8"), (unsigned long)currentLine], nil) retain];
		if (error) *error = [[readError retain] autorelease];
		return NO;
	}
	[pendingBytes replaceBytesInRange:NSMakeRange(0, usable) withBytes:NULL length:0];

	NSUInteger count = [text length];
	if (length + count > capacity) {
		NSUInteger newCapacity = MAX(capacity * 2, length + count);
		unichar *grown = realloc(characters, newCapacity * sizeof(unichar));
		if (!grown) {
			[text release];
			[readError release];
			readError = [SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"Out of memory reading the file.", @"Postgres import: out of memory"), nil) retain];
			if (error) *error = [[readError retain] autorelease];
			return NO;
		}
		characters = grown;
		capacity = newCapacity;
	}
	[text getCharacters:characters + length range:NSMakeRange(0, count)];
	[text release];

	// A byte order mark at the start of the file is skipped
	if (atStart && count) {
		atStart = NO;
		if (characters[length] == 0xFEFF) {
			memmove(characters + length, characters + length + 1, (count - 1) * sizeof(unichar));
			count--;
		}
	}
	length += count;

	return YES;
}

/// Moves position to index, counting the lines passed.
- (void)_advanceTo:(NSUInteger)index
{
	for (NSUInteger i = position; i < index; i++) {
		if (characters[i] == '\n') currentLine++;
	}
	position = index;
}

- (NSString *)_stringFrom:(NSUInteger)start to:(NSUInteger)end
{
	return [[[NSString alloc] initWithCharacters:characters + start length:end - start] autorelease];
}

/**
 * Skips whitespace and complete comments from position. Returns YES once position is at something else, or at the
 * end of the file (position == length and endOfFile). An unterminated comment at the end of the file is skipped.
 */
- (BOOL)_skipBlank:(NSError **)error
{
	for (;;) {
		while (position < length) {
			unichar c = characters[position];
			if (SPDumpIsWhitespace(c)) {
				[self _advanceTo:position + 1];
				continue;
			}
			if ((c == '-' || c == '/') && position + 1 >= length && !endOfFile) break; // need the next character
			if (c == '-' && position + 1 < length && characters[position + 1] == '-') {
				NSUInteger j = position + 2;
				while (j < length && characters[j] != '\n' && characters[j] != '\r') j++;
				if (j >= length && !endOfFile) break;
				[self _advanceTo:j];
				continue;
			}
			if (c == '/' && position + 1 < length && characters[position + 1] == '*') {
				NSUInteger depth = 1, j = position + 2;
				while (j < length && depth > 0) {
					if (characters[j] == '/' && j + 1 < length && characters[j + 1] == '*') { depth++; j += 2; }
					else if (characters[j] == '*' && j + 1 < length && characters[j + 1] == '/') { depth--; j += 2; }
					else j++;
				}
				if (depth > 0 && !endOfFile) break;
				[self _advanceTo:MIN(j, length)];
				continue;
			}
			return YES;
		}
		if (position >= length && endOfFile) return YES;
		if (![self _readMore:error]) return NO;
	}
}

/// The index of the next \n at or after from, reading more as needed; NSNotFound at the end of the file without one.
- (NSUInteger)_lineEndFrom:(NSUInteger *)from error:(NSError **)error failed:(BOOL *)failed
{
	*failed = NO;
	NSUInteger j = *from;
	for (;;) {
		while (j < length && characters[j] != '\n') j++;
		if (j < length) return j;
		if (endOfFile) return NSNotFound;
		// Reading more moves the text to the start of the buffer
		NSUInteger offset = position;
		if (![self _readMore:error]) { *failed = YES; return NSNotFound; }
		*from -= offset;
		j -= offset;
	}
}

#pragma mark - Items

- (SPPostgresDumpItem *)nextItem:(NSError **)error
{
	if (readError) {
		if (error) *error = [[readError retain] autorelease];
		return nil;
	}

	// An unread COPY's data is skipped, a chunk at a time (each one released before the next is read)
	while (inCopy) {
		BOOL more;
		@autoreleasepool {
			more = [self nextCopyData:NULL] != nil;
		}
		if (!more) break;
	}
	if (readError) {
		if (error) *error = [[readError retain] autorelease];
		return nil;
	}

	if (![self _skipBlank:error]) return nil;
	if (position >= length) return nil;

	NSUInteger line = currentLine;

	// A psql meta-command: the rest of the line
	if (characters[position] == '\\') {
		NSUInteger start = position;
		BOOL failed = NO;
		NSUInteger end = [self _lineEndFrom:&start error:error failed:&failed];
		if (failed) return nil;
		if (end == NSNotFound) end = length;
		NSUInteger contentEnd = end;
		while (contentEnd > start && SPDumpIsWhitespace(characters[contentEnd - 1])) contentEnd--;
		NSString *command = [self _stringFrom:start to:contentEnd];
		[self _advanceTo:end];
		return [[[SPPostgresDumpItem alloc] initWithKind:SPPostgresDumpItemMetaCommand sql:command line:line] autorelease];
	}

	// A statement: read until it is complete (or the file ends)
	NSUInteger statementLength = 0;
	for (;;) {
		statementLength = [SPPostgresStatementSplitter lengthOfFirstStatementInCharacters:characters + position length:length - position];
		if (statementLength || endOfFile) break;
		if (![self _readMore:error]) return nil;
	}

	NSUInteger start = position;
	NSUInteger end = statementLength ? start + statementLength : length;
	NSUInteger contentEnd = statementLength ? end - 1 : end; // without its semicolon
	while (contentEnd > start && SPDumpIsWhitespace(characters[contentEnd - 1])) contentEnd--;
	NSString *statement = [self _stringFrom:start to:contentEnd];
	[self _advanceTo:end];

	// COPY … FROM stdin, looking only at the statement's top-level code (not inside strings, quoted identifiers,
	// comments or parentheses, so neither COPY (SELECT 'from stdin') TO STDOUT nor a column list counts)
	static NSRegularExpression *copyPattern = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		copyPattern = [[NSRegularExpression alloc] initWithPattern:@"\\ACOPY\\b.*\\bFROM\\s+stdin\\b"
														   options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
															 error:NULL];
	});
	BOOL isCopy = NO;
	if ([statement length] >= 4 && [[statement substringToIndex:4] caseInsensitiveCompare:@"COPY"] == NSOrderedSame) {
		NSString *code = [SPPostgresStatementSplitter topLevelCodeOfStatement:statement];
		isCopy = [copyPattern firstMatchInString:code options:0 range:NSMakeRange(0, [code length])] != nil;
	}

	if (isCopy) {
		// The data starts on the next line
		NSUInteger from = position;
		BOOL failed = NO;
		NSUInteger lineEnd = [self _lineEndFrom:&from error:error failed:&failed];
		if (failed) return nil;
		[self _advanceTo:(lineEnd == NSNotFound) ? length : lineEnd + 1];
		inCopy = YES;
		copyLine = line;
	}

	return [[[SPPostgresDumpItem alloc] initWithKind:(isCopy ? SPPostgresDumpItemCopy : SPPostgresDumpItemStatement) sql:statement line:line] autorelease];
}

- (NSData *)nextCopyData:(NSError **)error
{
	if (readError) {
		if (error) *error = [[readError retain] autorelease];
		return nil;
	}
	if (!inCopy) return nil;

	NSData *result = nil;
	BOOL done = NO;
	while (!done) {
		// Each turn's chunk, text and data are released before the next read
		@autoreleasepool {
			// Whole lines from position, up to the \. line
			NSUInteger j = position;
			NSUInteger lastLineEnd = position; // after the last whole data line
			BOOL ended = NO;
			NSUInteger markerEnd = 0;
			while (j < length) {
				NSUInteger lineStart = j;
				while (j < length && characters[j] != '\n') j++;
				BOOL complete = j < length;
				if (!complete && !endOfFile) break;

				NSUInteger contentEnd = j;
				if (contentEnd > lineStart && characters[contentEnd - 1] == '\r') contentEnd--;
				if (contentEnd - lineStart == 2 && characters[lineStart] == '\\' && characters[lineStart + 1] == '.') {
					ended = YES;
					markerEnd = complete ? j + 1 : j;
					break;
				}
				if (!complete) break; // a last data line without \n at the end of the file: no \. line follows
				j++;
				lastLineEnd = j;
			}

			if (lastLineEnd > position) {
				NSString *text = [self _stringFrom:position to:lastLineEnd];
				[self _advanceTo:lastLineEnd];
				result = [[text dataUsingEncoding:NSUTF8StringEncoding] retain];
				done = YES;
			}
			else if (ended) {
				[self _advanceTo:markerEnd];
				inCopy = NO;
				done = YES;
			}
			else if (endOfFile) {
				inCopy = NO;
				[self _fail:[NSString stringWithFormat:NSLocalizedString(@"The data of the COPY on line %lu has no end marker (\\.) before the end of the file.", @"Postgres import: COPY data without \\."), (unsigned long)copyLine]];
				done = YES;
			}
			else if (![self _readMore:NULL]) {
				inCopy = NO;
				done = YES;
			}
		}
	}

	if (!result && readError) {
		if (error) *error = [[readError retain] autorelease];
		return nil;
	}
	return [result autorelease];
}

@end
