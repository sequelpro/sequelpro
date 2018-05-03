//
//  SPFavoritesExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 14, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPFavoritesExporter.h"
#import "SPTreeNode.h"
#import "SPThreadAdditions.h"

@interface SPFavoritesExporter ()

- (void)_writeFavoritesInBackground;
- (void)_informDelegateOfExportCompletion:(NSError *)error;

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
 */
- (void)writeFavorites:(NSArray *)favorites toFile:(NSString *)path
{
	[self setExportFavorites:favorites];
	[self setExportPath:path];
	
	[NSThread detachNewThreadWithName:@"SPFavoritesExporter background writing thread" target:self selector:@selector(_writeFavoritesInBackground) object:nil];
}

/**
 * Writes the favorites array to disk in plist format on separate thread.
 */
- (void)_writeFavoritesInBackground
{
	@autoreleasepool {
		NSMutableArray *favorites = [[NSMutableArray alloc] init];

		// Get a dictionary representation of all favorites
		for (SPTreeNode *node in [self exportFavorites])
		{
			// The selection could contain a group as well as items in that group.
			// So we skip those items, as their group will already export them.
			if(![node isDescendantOfNodes:[self exportFavorites]])
				[favorites addObject:[node dictionaryRepresentation]];
		}

		NSDictionary *dictionary = @{SPFavoritesDataRootKey : favorites};

		[favorites release];

		// Convert the current favorites tree to a dictionary representation to create the plist data
		NSError *error = nil;
		NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:dictionary
		                                                               format:NSPropertyListXMLFormat_v1_0
		                                                              options:0
		                                                                error:&error];

		if (error) {
			NSLog(@"Error converting favorites data to plist format: %@", error);
		}
		else if (plistData) {
			[plistData writeToFile:[self exportPath] options:NSAtomicWrite error:&error];

			if (error) {
				NSLog(@"Error writing favorites data: %@", error);
			}
		}

		[self _informDelegateOfExportCompletion:error];
	}
}

/**
 * Informs the delegate that the export process has completed.
 */
- (void)_informDelegateOfExportCompletion:(NSError *)error
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesExportCompletedWithError:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesExportCompletedWithError:) withObject:error waitUntilDone:NO];
	}
}

@end
