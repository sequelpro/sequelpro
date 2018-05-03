//
//  SPFavoritesImporter.m
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

#import "SPFavoritesImporter.h"
#import "SPThreadAdditions.h"

static NSString *SPOldPreferenceFileFavoritesKey = @"favorites";

@interface SPFavoritesImporter ()

- (void)_importFavoritesInBackground;
- (void)_informDelegateOfImportCompletion:(NSError *)error;
- (void)_informDelegateOfImportDataAvailable:(NSArray *)data;
- (void)_informDelegateOfErrorCode:(NSUInteger)code description:(NSString *)description;

@end

@implementation SPFavoritesImporter

@synthesize delegate;
@synthesize importPath;

/**
 * Imports the favorites from the file at the supplied path.
 *
 * @param path The path of the file to import
 */
- (void)importFavoritesFromFileAtPath:(NSString *)path
{
	[self setImportPath:path];

	[NSThread detachNewThreadWithName:@"SPFavoritesImporter background favorite importer" target:self selector:@selector(_importFavoritesInBackground) object:nil];
}

#pragma mark -
#pragma mark Private API

/**
 * Starts the import process on a separate thread.
 */
- (void)_importFavoritesInBackground
{
	@autoreleasepool {
		NSDictionary *importData;
		NSFileManager *fileManager = [NSFileManager defaultManager];

		if ([fileManager fileExistsAtPath:[self importPath]]) {
			importData = [[[NSDictionary alloc] initWithContentsOfFile:[self importPath]] autorelease];

			NSArray *favorites = [importData valueForKey:SPFavoritesDataRootKey];

			if (favorites) {
				[self _informDelegateOfImportDataAvailable:favorites];
			}
			else {
				// Check to see whether we're importing favorites from an old preferences file
				if ([importData valueForKey:SPOldPreferenceFileFavoritesKey]) {
					[self _informDelegateOfImportDataAvailable:[importData valueForKey:SPOldPreferenceFileFavoritesKey]];
				} else {
					[self _informDelegateOfErrorCode:NSFileReadUnknownError
					                     description:NSLocalizedString(@"Error reading import file.", @"error reading import file")];
				}
			}
		}
		else {
			[self _informDelegateOfErrorCode:NSFileReadNoSuchFileError
			                     description:NSLocalizedString(@"Import file does not exist.", @"import file does not exist message")];
		}
	}
}

/**
 * Informs the delegate that the import process has completed.
 */
- (void)_informDelegateOfImportCompletion:(NSError *)error
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesImportCompletedWithError:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesImportCompletedWithError:) withObject:error waitUntilDone:NO];
	}
}

/**
 * Informs the delegate that the imported data is available.
 */
- (void)_informDelegateOfImportDataAvailable:(NSArray *)data
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(favoritesImportData:)]) {
		[[self delegate] performSelectorOnMainThread:@selector(favoritesImportData:) withObject:data waitUntilDone:NO];
	}
}

/**
 * Informs the delegate that an error occurred during the import.
 *
 * @param code        The error code
 * @param description A short description of the error
 */
- (void)_informDelegateOfErrorCode:(NSUInteger)code description:(NSString *)description
{
	NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
										 code:code
									 userInfo:@{NSLocalizedDescriptionKey : description}];
	
	[self _informDelegateOfImportCompletion:error];
}

@end
