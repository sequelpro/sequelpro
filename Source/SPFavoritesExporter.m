//
//  $Id$
//
//  SPFavoritesExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 14, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPFavoritesExporter.h"
#import "SPTreeNode.h"

@interface SPFavoritesExporter ()

- (void)_writeFavoritesInBackground;

@end

@implementation SPFavoritesExporter

@synthesize delegate;
@synthesize exportPath;
@synthesize exportFavorites;

/***
 * Write the supplied array of favorites to the file at the supplied path.
 *
 * @param favorites The array of favorites to be written
 * @param path      The file system path that the file is to be written to
 * @param filename  The filename of the file to be written
 * @param error     Upon return if an error occurred contains the NSError instance
 *
 * @return A BOOL indicating the success of the operation
 */
- (void)writeFavorites:(NSArray *)favorites toFile:(NSString *)path error:(NSError **)error
{
	[self setExportFavorites:favorites];
	[self setExportPath:path];
	
	[NSThread detachNewThreadSelector:@selector(_writeFavoritesInBackground) toTarget:self withObject:nil];
}

/**
 * Writes the favorites array to disk in plist format on separate thread.
 */
- (void)_writeFavoritesInBackground
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSError *error = nil;
	NSString *errorString = nil;
	
	NSMutableArray *favorites = [[NSMutableArray alloc] init];
	
	// Get a dictionary representation of all favorites
	for (SPTreeNode *node in [self exportFavorites])
	{
		[favorites addObject:[node dictionaryRepresentation]];
	}
	
	NSDictionary *dictionary = [NSDictionary dictionaryWithObject:favorites forKey:SPFavoritesDataRootKey];
	
	[favorites release];
	
	// Convert the current favorites tree to a dictionary representation to create the plist data
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:dictionary
																   format:NSPropertyListXMLFormat_v1_0
														 errorDescription:&errorString];
	
	if (plistData) {
		[plistData writeToFile:[self exportPath] options:NSAtomicWrite error:&error];
		
		if (error) {
			NSLog(@"Error writing favorites data: %@", [error localizedDescription]);
		}
	}
	else if (errorString) {
		NSLog(@"Error converting favorites data to plist format: %@", errorString);
		
		[errorString release];
	}
	
	// Inform the delegate that the export has completed and pass the error instance
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesExportCompletedWithError:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesExportCompletedWithError:) withObject:error waitUntilDone:NO];
	}
	
	[pool release];
}

@end
