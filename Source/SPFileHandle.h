//
//  SPFileHandle.h
//  sequel-pro
//
//  Created by Rowan Beentje on 05/04/2010.
//  Copyright 2010 Arboreal. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPFileHandle : NSObject {
	void *wrappedFile;
	char *wrappedFilePath;

	NSMutableData *buffer;
	NSUInteger bufferDataLength;
	NSUInteger bufferPosition;
	BOOL endOfFile;
	pthread_mutex_t bufferLock;
	NSThread *processingThread;

	int fileMode;
	BOOL dataWritten;
	BOOL fileIsClosed;
	BOOL useGzip;
}


#pragma mark -
#pragma mark Class methods

+ (id) fileHandleForReadingAtPath:(NSString *)path;
+ (id) fileHandleForWritingAtPath:(NSString *)path;
+ (id) fileHandleForPath:(NSString *)path mode:(int)mode;

#pragma mark -
#pragma mark Initialisation

// Returns a file handle initialised with a file
- (id) initWithFile:(void *)theFile fromPath:(const char *)path mode:(int)mode;


#pragma mark -
#pragma mark Data reading

// Reads data up to a specified number of bytes from the file
- (NSMutableData *) readDataOfLength:(NSUInteger)length;

// Returns the data to the end of the file
- (NSMutableData *) readDataToEndOfFile;

// Returns the on-disk (raw) length of data read so far - can be used in progress bars
- (NSUInteger) realDataReadLength;

#pragma mark -
#pragma mark Data writing

// Set whether data should be written as gzipped data (defaults to NO on a fresh object)
- (void) setShouldWriteWithGzipCompression:(BOOL)useGzip;

// Write the provided data to the file
- (void) writeData:(NSData *)data;

// Ensures any buffers are written to disk
- (void) synchronizeFile;

// Prevents further access to the file
- (void) closeFile;


#pragma mark -
#pragma mark File information

// Returns whether gzip compression is enabled on the file
- (BOOL) isCompressed;


@end
