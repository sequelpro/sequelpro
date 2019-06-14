//
//  SPBundleCommandRunner.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 6, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPBundleCommandRunner.h"
#import "SPDatabaseDocument.h"
#import "SPAppController.h"

// Defined to suppress warnings
@interface NSObject (SPBundleMethods)

- (NSString *)lastBundleBlobFilesDirectory;
- (void)setLastBundleBlobFilesDirectory:(NSString *)path;

@end

// Defined to suppress warnings
@interface NSObject (SPWindowControllerTabMethods)

- (id)selectedTableDocument;

@end

@implementation SPBundleCommandRunner

#ifndef SP_CODA /* run commands */

/**
 * Run the supplied string as a BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 * @param command The command to run
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 */
+ (NSString *)runBashCommand:(NSString *)command withEnvironment:(NSDictionary*)shellEnvironment atCurrentDirectoryPath:(NSString*)path error:(NSError**)theError
{
	return [SPBundleCommandRunner runBashCommand:command withEnvironment:shellEnvironment atCurrentDirectoryPath:path callerInstance:nil contextInfo:nil error:theError];
}

/**
 * Run the supplied command as a BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 * @param command The command to run
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 * @param caller The SPDatabaseDocument which invoked that command to register the command for cancelling; if nil the command won't be registered.
 * @param name The menu title of the command.
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 */
+ (NSString *)runBashCommand:(NSString *)command withEnvironment:(NSDictionary*)shellEnvironment atCurrentDirectoryPath:(NSString*)path callerInstance:(id)caller contextInfo:(NSDictionary*)contextInfo error:(NSError**)theError
{	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	BOOL userTerminated = NO;
	BOOL redirectForScript = NO;
	BOOL isDir = NO;
	
	NSMutableArray *scriptHeaderArguments = [NSMutableArray array];
	NSString *scriptPath = @"";
	NSString *uuid = (contextInfo && [contextInfo objectForKey:SPBundleFileInternalexecutionUUID]) ? [contextInfo objectForKey:SPBundleFileInternalexecutionUUID] : [NSString stringWithNewUUID];
	NSString *stdoutFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskOutputFilePath, uuid];
	NSString *scriptFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskScriptCommandFilePath, uuid];
	
	[fm removeItemAtPath:scriptFilePath error:nil];
	[fm removeItemAtPath:stdoutFilePath error:nil];
	if([SPAppDelegate lastBundleBlobFilesDirectory] != nil)
		[fm removeItemAtPath:[SPAppDelegate lastBundleBlobFilesDirectory] error:nil];
	
	if([shellEnvironment objectForKey:SPBundleShellVariableBlobFileDirectory])
		[SPAppDelegate setLastBundleBlobFilesDirectory:[shellEnvironment objectForKey:SPBundleShellVariableBlobFileDirectory]];
	
	// Parse first line for magic header #! ; if found save the script content and run the command after #! with that file.
	// This allows to write perl, ruby, osascript scripts natively.
	if([command length] > 3 && [command hasPrefix:@"#!"] && [shellEnvironment objectForKey:SPBundleShellVariableBundlePath]) {
		
		NSRange firstLineRange = NSMakeRange(2, [command rangeOfString:@"\n"].location - 2);
		
		[scriptHeaderArguments setArray:[[command substringWithRange:firstLineRange] componentsSeparatedByString:@" "]];
		
		while([scriptHeaderArguments containsObject:@""])
			[scriptHeaderArguments removeObject:@""];
		
		if([scriptHeaderArguments count])
			scriptPath = [scriptHeaderArguments objectAtIndex:0];
		
		if([scriptPath hasPrefix:@"/"] && [fm fileExistsAtPath:scriptPath isDirectory:&isDir] && !isDir) {
			NSString *script = [command substringWithRange:NSMakeRange(NSMaxRange(firstLineRange), [command length] - NSMaxRange(firstLineRange))];
			NSError *writeError = nil;
			[script writeToFile:scriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
			if(writeError == nil) {
				redirectForScript = YES;
				[scriptHeaderArguments addObject:scriptFilePath];
			} else {
				NSBeep();
				NSLog(@"Couldn't write script file.");
			}
		}
	} else {
		[scriptHeaderArguments addObject:@"/bin/sh"];
		NSError *writeError = nil;
		[command writeToFile:scriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError == nil) {
			redirectForScript = YES;
			[scriptHeaderArguments addObject:scriptFilePath];
		} else {
			NSBeep();
			NSLog(@"Couldn't write script file.");
		}
	}
	
	NSTask *bashTask = [[NSTask alloc] init];
	[bashTask setLaunchPath:@"/bin/bash"];
	
	NSMutableDictionary *theEnv = [NSMutableDictionary dictionary];
	[theEnv setDictionary:shellEnvironment];
	
	[theEnv setObject:[[NSBundle mainBundle] pathForResource:@"appIcon" ofType:@"icns"] forKey:SPBundleShellVariableIconFile];
	[theEnv setObject:[NSString stringWithFormat:@"%@/Contents/Resources", [[NSBundle mainBundle] bundlePath]] forKey:SPBundleShellVariableAppResourcesDirectory];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionNone] forKey:SPBundleShellVariableExitNone];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionReplaceSection] forKey:SPBundleShellVariableExitReplaceSelection];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionReplaceContent] forKey:SPBundleShellVariableExitReplaceContent];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionInsertAsText] forKey:SPBundleShellVariableExitInsertAsText];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionInsertAsSnippet] forKey:SPBundleShellVariableExitInsertAsSnippet];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionShowAsHTML] forKey:SPBundleShellVariableExitShowAsHTML];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionShowAsTextTooltip] forKey:SPBundleShellVariableExitShowAsTextTooltip];
	[theEnv setObject:[NSNumber numberWithInteger:SPBundleRedirectActionShowAsHTMLTooltip] forKey:SPBundleShellVariableExitShowAsHTMLTooltip];
	
	// Create and set an unique process ID for each SPDatabaseDocument which has to passed
	// for each sequelpro:// scheme command as user to be able to identify the url scheme command.
	// Furthermore this id is used to communicate with the called command as file name.
	id doc = nil;
	if([[[NSApp mainWindow] delegate] respondsToSelector:@selector(selectedTableDocument)])
		doc = [(SPWindowController *)[[NSApp mainWindow] delegate] selectedTableDocument];
	// Check if connected
	if([doc getConnection] == nil)
		doc = nil;
	else {
		for (NSWindow *aWindow in [NSApp orderedWindows])
		{
			if ([[[[aWindow windowController] class] description] isEqualToString:@"SPWindowController"]) {

				SPWindowController *windowController = (SPWindowController *)[aWindow windowController];
				NSArray *documents = [windowController documents];

				if ([documents count] && [[[[documents objectAtIndex:0] class] description] isEqualToString:@"SPDatabaseDocument"]) {
					// Check if connected
					if ([[documents objectAtIndex:0] getConnection]) {
						doc = [documents objectAtIndex:0];
					}
					else {
						doc = nil;
					}
				}
			}

			if (doc) break;
		}
	}
	
	if (doc != nil) {
		
		[doc setProcessID:uuid];
		
		[theEnv setObject:uuid forKey:SPBundleShellVariableProcessID];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, uuid] forKey:SPBundleShellVariableQueryFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, uuid] forKey:SPBundleShellVariableQueryResultFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, uuid] forKey:SPBundleShellVariableQueryResultStatusFile];
		[theEnv setObject:[NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, uuid] forKey:SPBundleShellVariableQueryResultMetaFile];
		
		if([doc shellVariables])
			[theEnv addEntriesFromDictionary:[doc shellVariables]];
		
		if([theEnv objectForKey:SPBundleShellVariableCurrentEditedColumnName] && [[theEnv objectForKey:SPBundleShellVariableDataTableSource] isEqualToString:@"content"])
			[theEnv setObject:[theEnv objectForKey:SPBundleShellVariableSelectedTable] forKey:SPBundleShellVariableCurrentEditedTable];
		
	}
	
	if(theEnv != nil && [theEnv count])
		[bashTask setEnvironment:theEnv];
	
	if(path != nil)
		[bashTask setCurrentDirectoryPath:path];
	else if([shellEnvironment objectForKey:SPBundleShellVariableBundlePath] && [fm fileExistsAtPath:[shellEnvironment objectForKey:SPBundleShellVariableBundlePath] isDirectory:&isDir] && isDir)
		[bashTask setCurrentDirectoryPath:[shellEnvironment objectForKey:SPBundleShellVariableBundlePath]];
	
	// STDOUT will be redirected to SPBundleTaskOutputFilePath in order to avoid nasty pipe programming due to block size reading
	if([shellEnvironment objectForKey:SPBundleShellVariableInputFilePath])
		[bashTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@ > %@ < %@", [scriptHeaderArguments componentsJoinedByString:@" "], stdoutFilePath, [shellEnvironment objectForKey:SPBundleShellVariableInputFilePath]], nil]];
	else
		[bashTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@ > %@", [scriptHeaderArguments componentsJoinedByString:@" "], stdoutFilePath], nil]];
	
	NSPipe *stderr_pipe = [NSPipe pipe];
	[bashTask setStandardError:stderr_pipe];
	NSFileHandle *stderr_file = [stderr_pipe fileHandleForReading];
	[bashTask launch];
	NSInteger pid = -1;
	if(caller != nil && [caller respondsToSelector:@selector(registerActivity:)]) {
		// register command
		pid = [bashTask processIdentifier];
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:pid], @"pid",
							  (contextInfo)?: @{}, @"contextInfo",
							  @"bashcommand", @"type",
							  [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]], @"starttime",
							  nil];
		[caller registerActivity:dict];
	}
	
	// Listen to ⌘. to terminate
	while(1) {
		if(![bashTask isRunning] || [bashTask processIdentifier] == 0) break;
		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
											untilDate:[NSDate distantPast]
											   inMode:NSDefaultRunLoopMode
											  dequeue:YES];
		usleep(1000);
		if(!event) continue;
		if ([event type] == NSKeyDown) {
			unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
			if (([event modifierFlags] & NSEventModifierFlagCommand) && key == '.') {
				[bashTask terminate];
				userTerminated = YES;
				break;
			}
			[NSApp sendEvent:event];
		} else {
			[NSApp sendEvent:event];
		}
	}
	
	[bashTask waitUntilExit];
	
	// unregister BASH command if it was registered
	if(pid > 0) {
		[caller removeRegisteredActivity:pid];
	}
	
	// Remove files
	[fm removeItemAtPath:scriptFilePath error:nil];
	if([theEnv objectForKey:SPBundleShellVariableQueryFile])
		[fm removeItemAtPath:[theEnv objectForKey:SPBundleShellVariableQueryFile] error:nil];
	if([theEnv objectForKey:SPBundleShellVariableQueryResultFile])
		[fm removeItemAtPath:[theEnv objectForKey:SPBundleShellVariableQueryResultFile] error:nil];
	if([theEnv objectForKey:SPBundleShellVariableQueryResultStatusFile])
		[fm removeItemAtPath:[theEnv objectForKey:SPBundleShellVariableQueryResultStatusFile] error:nil];
	if([theEnv objectForKey:SPBundleShellVariableQueryResultMetaFile])
		[fm removeItemAtPath:[theEnv objectForKey:SPBundleShellVariableQueryResultMetaFile] error:nil];
	if([theEnv objectForKey:SPBundleShellVariableInputTableMetaData])
		[fm removeItemAtPath:[theEnv objectForKey:SPBundleShellVariableInputTableMetaData] error:nil];
	
	// If return from bash re-activate Sequel Pro
	[NSApp activateIgnoringOtherApps:YES];
	
	NSInteger status = [bashTask terminationStatus];
	NSData *errdata  = [stderr_file readDataToEndOfFile];
	
	// Check STDERR
	if([errdata length] && (status < SPBundleRedirectActionNone || status > SPBundleRedirectActionLastCode)) {
		[fm removeItemAtPath:stdoutFilePath error:nil];
		
		if(status == 9 || userTerminated) return @"";
		if(theError != NULL) {
			NSMutableString *errMessage = [[[NSMutableString alloc] initWithData:errdata encoding:NSUTF8StringEncoding] autorelease];
			[errMessage replaceOccurrencesOfString:[NSString stringWithFormat:@"%@: ", scriptFilePath] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [errMessage length])];
			*theError = [[[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
													code:status 
												userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
														  errMessage,
														  NSLocalizedDescriptionKey, 
														  nil]] autorelease];
		} else {
			NSBeep();
		}
		return @"";
	}
	
	// Read STDOUT saved to file 
	if([fm fileExistsAtPath:stdoutFilePath isDirectory:nil]) {
		NSString *stdoutContent = [NSString stringWithContentsOfFile:stdoutFilePath encoding:NSUTF8StringEncoding error:nil];
		if(bashTask) SPClear(bashTask);
		[fm removeItemAtPath:stdoutFilePath error:nil];
		if(stdoutContent != nil) {
			if (status == 0) {
				return stdoutContent;
			} else {
				if(theError != NULL) {
					if(status == 9 || userTerminated) return @"";
					NSMutableString *errMessage = [[[NSMutableString alloc] initWithData:errdata encoding:NSUTF8StringEncoding] autorelease];
					[errMessage replaceOccurrencesOfString:SPBundleTaskScriptCommandFilePath withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [errMessage length])];
					*theError = [[[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
															code:status 
														userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																  errMessage,
																  NSLocalizedDescriptionKey, 
																  nil]] autorelease];
				} else {
					NSBeep();
				}
				if(status > SPBundleRedirectActionNone && status <= SPBundleRedirectActionLastCode)
					return stdoutContent;
				else
					return @"";
			}
		} else {
			NSLog(@"Couldn't read return string from “%@” by using UTF-8 encoding.", command);
			NSBeep();
		}
	}
	
	if (bashTask) [bashTask release];
	[fm removeItemAtPath:stdoutFilePath error:nil];
	return @"";
}

#endif

@end
