#import "SPPostgresCompressedFileReader.h"
#import "SPPostgresErrors.h"
#import <zlib.h>
#import <bzlib.h>
#import <sys/stat.h>

typedef NS_ENUM(NSInteger, SPCompressedFileFormat) {
	SPCompressedFilePlain = 0,
	SPCompressedFileGzip = 1,
	SPCompressedFileBzip2 = 2
};

@implementation SPPostgresCompressedFileReader
{
	FILE *file;              // plain and bzip2 files
	gzFile gzipFile;         // gzip files
	BZFILE *bzipFile;        // bzip2 files (on file)
	SPCompressedFileFormat format;
	BOOL openFailed;         // the bzip2 stream couldn't be set up: reported as damaged by the first read
	unsigned long long offset;
	unsigned long long fileSize;
}

@synthesize fileSize;

- (instancetype)initWithPath:(NSString *)path error:(NSError **)error
{
	if ((self = [super init])) {
		const char *fsPath = [path fileSystemRepresentation];
		file = fsPath ? fopen(fsPath, "rb") : NULL;
		if (!file) {
			if (error) {
				NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The file “%@” can't be opened.", @"Postgres import: file can't be opened"), [path lastPathComponent]];
				*error = SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil);
			}
			[self release];
			return nil;
		}

		struct stat info;
		if (fstat(fileno(file), &info) == 0) fileSize = (unsigned long long)info.st_size;

		// The format, from the first bytes: gzip 1f 8b, bzip2 "BZh"
		unsigned char magic[3] = {0, 0, 0};
		size_t magicLength = fread(magic, 1, 3, file);
		rewind(file);
		if (magicLength >= 2 && magic[0] == 0x1f && magic[1] == 0x8b) format = SPCompressedFileGzip;
		else if (magicLength == 3 && magic[0] == 'B' && magic[1] == 'Z' && magic[2] == 'h') format = SPCompressedFileBzip2;
		else format = SPCompressedFilePlain;

		if (format == SPCompressedFileGzip) {
			fclose(file);
			file = NULL;
			gzipFile = gzopen(fsPath, "rb");
			openFailed = gzipFile == NULL;
		}
		else if (format == SPCompressedFileBzip2) {
			int bzError = BZ_OK;
			bzipFile = BZ2_bzReadOpen(&bzError, file, 0, 0, NULL, 0);
			if (bzError != BZ_OK) {
				if (bzipFile) BZ2_bzReadClose(&bzError, bzipFile);
				bzipFile = NULL;
				openFailed = YES;
			}
		}
	}
	return self;
}

- (void)dealloc
{
	int bzError;
	if (bzipFile) BZ2_bzReadClose(&bzError, bzipFile);
	if (gzipFile) gzclose(gzipFile);
	if (file) fclose(file);
	[super dealloc];
}

- (BOOL)isCompressed
{
	return format != SPCompressedFilePlain;
}

- (unsigned long long)bytesRead
{
	return offset;
}

- (BOOL)readBytes:(void *)bytes count:(NSUInteger)count read:(NSUInteger *)read damaged:(BOOL *)damaged
{
	*read = 0;
	if (damaged) *damaged = NO;
	if (count > INT_MAX) count = INT_MAX;
	if (openFailed) {
		if (damaged) *damaged = YES;
		return NO;
	}

	switch (format) {
		case SPCompressedFilePlain: {
			size_t n = fread(bytes, 1, count, file);
			if (n == 0 && ferror(file)) return NO;
			// At the end: a file still being written can be read further later
			if (n == 0) clearerr(file);
			*read = n;
			long position = ftell(file);
			if (position >= 0) offset = (unsigned long long)position;
			return YES;
		}

		case SPCompressedFileGzip: {
			int n = gzread(gzipFile, bytes, (unsigned)count);
			int gzError = Z_OK;
			gzerror(gzipFile, &gzError);
			// zlib reports a stream cut short as Z_BUF_ERROR ("unexpected end of file"), returning what it decoded
			if (n < 0 || (gzError != Z_OK && gzError != Z_STREAM_END)) {
				if (damaged) *damaged = (gzError != Z_ERRNO);
				return NO;
			}
			*read = (NSUInteger)n;
			z_off_t position = gzoffset(gzipFile);
			if (position >= 0) offset = (unsigned long long)position;
			return YES;
		}

		case SPCompressedFileBzip2: {
			while (bzipFile) {
				int bzError = BZ_OK;
				int n = BZ2_bzRead(&bzError, bzipFile, bytes, (int)count);
				long position = ftell(file);
				if (position >= 0) offset = (unsigned long long)position;
				if (bzError == BZ_OK) {
					*read = (NSUInteger)n;
					return YES;
				}
				if (bzError != BZ_STREAM_END) {
					// BZ_UNEXPECTED_EOF, BZ_DATA_ERROR, …; BZ_IO_ERROR is the file's own read failing
					if (damaged) *damaged = (bzError != BZ_IO_ERROR);
					return NO;
				}

				// The end of a stream: another may follow (pbzip2 writes several)
				void *unused = NULL;
				int unusedCount = 0;
				BZ2_bzReadGetUnused(&bzError, bzipFile, &unused, &unusedCount);
				NSData *rest = (bzError == BZ_OK && unusedCount > 0) ? [NSData dataWithBytes:unused length:(NSUInteger)unusedCount] : nil;
				BZ2_bzReadClose(&bzError, bzipFile);
				bzipFile = NULL;

				BOOL more = [rest length] > 0;
				if (!more) {
					int c = fgetc(file);
					if (c != EOF) { ungetc(c, file); more = YES; }
				}
				if (more) {
					bzipFile = BZ2_bzReadOpen(&bzError, file, 0, 0, (void *)[rest bytes], (int)[rest length]);
					if (bzError != BZ_OK) {
						if (bzipFile) BZ2_bzReadClose(&bzError, bzipFile);
						bzipFile = NULL;
						if (damaged) *damaged = YES;
						return NO;
					}
				}
				if (n > 0) {
					*read = (NSUInteger)n;
					return YES;
				}
			}
			return YES; // the end of the file
		}
	}
	return YES;
}

@end
