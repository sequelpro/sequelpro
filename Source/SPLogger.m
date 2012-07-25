//
//  $Id$
//
//  SPLogger.m
//  sequel-pro
//
//  Created by Rowan Beentje on June 17, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPLogger.h"

#import <pwd.h>
#import <stdio.h>
#import <dirent.h>
#import <sys/dir.h>
#import <sys/types.h>

static SPLogger *logger = nil;

@interface SPLogger ()

- (void)_initLogFile;
- (void)_outputTimeString;

int _isSPLeaksLog(struct direct *entry);

@end

/**
 * This is a small class intended to aid in user issue debugging; by including
 * the header file, and using [[SPLogger logger] log:@"String with format", ...]
 * a file will be created on the user's desktop including timestamps and
 * the log message.
 * This allows use of fine-grained and detailed logging, without asking the user
 * to copy text from a console log via NSLog.
 * As each log line must by synched to disk as soon as it is received, for safety,
 * this class can add a performance hit when lots of logging is used.
 */

@implementation SPLogger

@synthesize dumpLeaksOnTermination;
@synthesize removeOldLeakDumpsOnTermination;

/*
 * Returns the shared logger object.
 */
+ (SPLogger *)logger
{
	@synchronized(self) {
		if (logger == nil) {
			logger = [[super allocWithZone:NULL] init];
		}
	}
	
	return logger;
}

#pragma mark -
#pragma mark Initialisation and teardown

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
		return [[self logger] retain];
    }
	return nil;
}

- (id)init
{
	if ((self = [super init])) {
		initializedSuccessfully = YES;
		
		[self setDumpLeaksOnTermination:NO];
		[self setRemoveOldLeakDumpsOnTermination:YES];
	}
	
	return self;
}

#pragma mark -
#pragma mark Logging functions

- (void)log:(NSString *)theString, ...
{
	if (!initializedSuccessfully) return;
	
	if (!logFileHandle) [self _initLogFile];

	// Extract any supplied arguments and build the formatted log string
	va_list arguments;
	va_start(arguments, theString);
	NSString *logString = [[NSString alloc] initWithFormat:theString arguments:arguments];
	va_end(arguments);

	// Write the log line, forcing an immediate write to disk to ensure logging, and
	// synchronised to allow use across multiple executables or their frameworks.
	[logFileHandle synchronizeFile];
	[logFileHandle seekToEndOfFile];
	[logFileHandle writeData:[[NSString stringWithFormat:@"%@ %@\n", [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]], logString] dataUsingEncoding:NSUTF8StringEncoding]];
	[logFileHandle synchronizeFile];

	[logString release];
}

- (void)dumpLeaks
{
	if ([self dumpLeaksOnTermination]) {
		
		char *lgn;
		struct passwd *pw;
		boolean_t hdir = FALSE;
		
		// Determine where to write the log to
		if ((lgn = getlogin()) == NULL || (pw = getpwnam(lgn)) == NULL) {
			fprintf(stderr, "Unable to get user info, falling back to /tmp\n"); 
		}
		else {
			hdir = TRUE;
		}
		
		// If required remove old logs
		if ([self removeOldLeakDumpsOnTermination]) {
			
			int cnt, cnt2, i;
			struct direct **files;
			
			cnt  = scandir("/tmp", &files, _isSPLeaksLog, NULL);
			
			char fpath[32], fpath2[32], fpath3[64];
			
			for (i = 0; i < cnt; i++)
			{
				snprintf(fpath, sizeof(fpath), "/tmp/%s", files[i]->d_name);
				
				if (remove(fpath) != 0) {
					printf("Unable to remove Sequel Pro leaks log '%s'\n", files[i]->d_name);
				}
			}
			
			free(&files);
			
			if (hdir) {
				snprintf(fpath2, sizeof(fpath2), "%s/Desktop", pw->pw_dir);
				
				cnt2 = scandir(fpath2, &files, _isSPLeaksLog, NULL);
				
				for (i = 0; i < cnt2; i++)
				{
					snprintf(fpath3, sizeof(fpath3), "%s/%s", fpath2, files[i]->d_name);
					
					if (remove(fpath3) != 0) {
						printf("Unable to remove Sequel Pro leaks log '%s'\n", files[i]->d_name);
					}
				}
			}
		}
	
		size_t len;
		FILE *fp, *fp2;
		char cmd[32], file[64], buf[512];
		
		snprintf(cmd, sizeof(cmd), "/usr/bin/leaks %d", getpid());
		snprintf(file, sizeof(file), (hdir) ? "%s/Desktop/sp.leaks.%d.log" : "%s/sp.leaks.%d.log", (hdir) ? pw->pw_dir : "/tmp", getpid());
		
		// Write new leaks log
		if ((fp = popen(cmd, "r")) && (fp2 = fopen(file, "w"))) {
			
			while ((len = fread(buf, 1, sizeof(buf), fp)))
			{
				fwrite(buf, 1, len, fp2);
			}
				
			pclose(fp);
		}
	}
}

#pragma mark -
#pragma mark Private API

- (void)_initLogFile
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
	NSString *logFilePath = [NSString stringWithFormat:@"%@/Sequel Pro Debug Log.log", [paths objectAtIndex:0]];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Check if the debug file exists, and is writable
	if ([fileManager fileExistsAtPath:logFilePath]) {
		if (![fileManager isWritableFileAtPath:logFilePath]) {
			initializedSuccessfully = NO;
			NSRunAlertPanel(@"Logging error", @"Log file exists but is not writeable; no debug log will be generated!", @"OK", nil, nil);
		}
		// Otherwise try creating one
	} 
	else {
		if (![fileManager createFileAtPath:logFilePath contents:[NSData data] attributes:nil]) {
			initializedSuccessfully = NO;
			NSRunAlertPanel(@"Logging error", @"Could not create log file for writing; no debug log will be generated!", @"OK", nil, nil);
		}
	}
	
	// Get a file handle to the file if possible
	if (initializedSuccessfully) {
		logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
		
		if (!logFileHandle) {
			initializedSuccessfully = NO;
			NSRunAlertPanel(@"Logging error", @"Could not open log file for writing; no debug log will be generated!", @"OK", nil, nil);
		} 
		else {
			[logFileHandle retain];
			[logFileHandle seekToEndOfFile];
			
			NSString *bundleName = [fileManager displayNameAtPath:[[NSBundle mainBundle] bundlePath]];
			NSMutableString *logStart = [NSMutableString stringWithString:@"\n\n\n==========================================================================\n\n"];
			
			[logStart appendFormat:@"%@ (r%ld)\n", bundleName, (long)[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue]];
			[logFileHandle writeData:[logStart dataUsingEncoding:NSUTF8StringEncoding]];
		}
	}
}

- (void)_outputTimeString
{
	if (!initializedSuccessfully) return;
	
	[logFileHandle writeData:[[NSString stringWithFormat:@"Launched at %@\n\n", [[NSDate date] description]] dataUsingEncoding:NSUTF8StringEncoding]];
}

int _isSPLeaksLog(struct direct *entry)
{
	return (strstr(entry->d_name, "sp.leaks") != NULL);
}

@end
