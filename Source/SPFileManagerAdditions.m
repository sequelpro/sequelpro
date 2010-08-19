//
//  $Id$
//
//  SPFileManagerAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 19, 2010
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>


#import "SPFileManagerAdditions.h"

enum
{
	DirectoryLocationErrorNoPathFound,
	DirectoryLocationErrorFileExistsAtLocation
};
	
NSString* const DirectoryLocationDomain = @"DirectoryLocationDomain";


@implementation NSFileManager (SPFileManagerAdditions)

/*
 * Return the application support folder of the current application for 'subDirectory'.
 * If this folder doesn't exist it will be created. If 'subDirectory' == nil it only returns
 * the application support folder of the current application.
 */
- (NSString*)applicationSupportDirectoryForSubDirectory:(NSString*)subDirectory error:(NSError **)errorOut
{
	//  Based on Matt Gallagher on 06 May 2010
	//
	//  Permission is given to use this source code file, free of charge, in any
	//  project, commercial or otherwise, entirely at your risk, with the condition
	//  that any redistribution (in part or whole) of source code must retain
	//  this copyright and permission notice. Attribution in compiled projects is
	//  appreciated but not required.
	//

	NSError *error;

	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);

	if (![paths count]) {
		if (errorOut) {
			NSDictionary *userInfo =
				[NSDictionary dictionaryWithObjectsAndKeys:
					NSLocalizedStringFromTable(
						@"No path found for directory in domain.",
						@"Errors",
					nil),
					NSLocalizedDescriptionKey,
					[NSNumber numberWithInteger:NSApplicationSupportDirectory],
					@"NSSearchPathDirectory",
					[NSNumber numberWithInteger:NSUserDomainMask],
					@"NSSearchPathDomainMask",
				nil];
			*errorOut = [NSError 
					errorWithDomain:DirectoryLocationDomain
					code:DirectoryLocationErrorNoPathFound
					userInfo:userInfo];
		}
		return nil;
	}

	// Use only the first path returned
	NSString *resolvedPath = [paths objectAtIndex:0];

	// Append the application name
	resolvedPath = [resolvedPath stringByAppendingPathComponent:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"]];

	// Append the subdirectory if passed
	if (subDirectory)
		resolvedPath = [resolvedPath stringByAppendingPathComponent:subDirectory];

	// Check if the path exists already
	BOOL exists;
	BOOL isDirectory;
	exists = [self fileExistsAtPath:resolvedPath isDirectory:&isDirectory];
	if (!exists || !isDirectory) {
		if (exists) {
			if (errorOut) {
				NSDictionary *userInfo =
					[NSDictionary dictionaryWithObjectsAndKeys:
						NSLocalizedStringFromTable(
							@"File exists at requested directory location.",
							@"Errors",
						nil),
						NSLocalizedDescriptionKey,
						[NSNumber numberWithInteger:NSApplicationSupportDirectory],
						@"NSSearchPathDirectory",
						[NSNumber numberWithInteger:NSUserDomainMask],
						@"NSSearchPathDomainMask",
					nil];
				*errorOut = [NSError 
						errorWithDomain:DirectoryLocationDomain
						code:DirectoryLocationErrorFileExistsAtLocation
						userInfo:userInfo];
			}
			return nil;
		}
	
		// Create the path if it doesn't exist
		NSError *error = nil;
		BOOL success = [self createDirectoryAtPath:resolvedPath withIntermediateDirectories:YES attributes:nil error:&error];
		if (!success)  {
			if (errorOut) {
				*errorOut = error;
			}
			return nil;
		}
	}
	
	if (errorOut)
		*errorOut = nil;
	
	if (!resolvedPath) {
		NSBeep();
		NSLog(@"Unable to find or create application support directory:\n%@", error);
	}
	
	
	return resolvedPath;

	
}

@end
