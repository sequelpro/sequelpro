//
//  SPServerSupport.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 23, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPServerSupport.h"

#import <objc/runtime.h>

@interface SPServerSupport ()

- (void)_invalidate;
- (NSComparisonResult)_compareServerMajorVersion:(NSInteger)majorVersionA 
										   minor:(NSInteger)minorVersionA 
										 release:(NSInteger)releaseVersionA
						  withServerMajorVersion:(NSInteger)majorVersionB
										   minor:(NSInteger)minorVersionB
										 release:(NSInteger)releaseVersionB;

@end

@implementation SPServerSupport

@synthesize isMySQL3;
@synthesize isMySQL4;
@synthesize isMySQL5;
@synthesize isMySQL6;
@synthesize supportsInformationSchema;
@synthesize supportsSpatialExtensions;
@synthesize supportsShowCharacterSet;
@synthesize supportsShowCollation;
@synthesize supportsCharacterSetAndCollationVars;
@synthesize supportsPost41CharacterSetHandling;
@synthesize supportsCreateUser;
@synthesize supportsRenameUser;
@synthesize supportsDropUser;
@synthesize supportsFullDropUser;
@synthesize supportsUserMaxVars;
@synthesize supportsShowPrivileges;
@synthesize engineTypeQueryName;
@synthesize supportsInformationSchemaEngines;
@synthesize supportsPre41StorageEngines;
@synthesize supportsBlackholeStorageEngine;
@synthesize supportsArchiveStorageEngine;
@synthesize supportsCSVStorageEngine;
@synthesize supportsTriggers;
@synthesize supportsEvents;
@synthesize supportsIndexKeyBlockSize;
@synthesize supportsQuotingEngineTypeInCreateSyntax;
@synthesize supportsFractionalSeconds;
@synthesize serverMajorVersion;
@synthesize serverMinorVersion;
@synthesize serverReleaseVersion;
@synthesize supportsFulltextOnInnoDB;
@synthesize supportsShowEngine;

#pragma mark -
#pragma mark Initialisation

/**
 * Creates and returns an instance of SPServerSupport with the supplied version numbers. The caller is
 * responsible it's memory.
 *
 * @param majorVersion   The major version number of the server
 * @param minorVersion   The minor version number of the server
 * @param releaseVersiod The release version number of the server
 *
 * @return The initializes SPServerSupport instance
 */
- (id)initWithMajorVersion:(NSInteger)majorVersion minor:(NSInteger)minorVersion release:(NSInteger)releaseVersion
{
	if ((self = [super init])) {
		serverMajorVersion   = majorVersion;
		serverMinorVersion   = minorVersion;
		serverReleaseVersion = releaseVersion;
		
		// Determine what the server supports
		[self evaluate];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Performs the actual version based comparisons to determine what functionaity the server supports. This
 * method is called automatically as part of the designated initializer (initWithMajorVersion:major:minor:release:)
 * and shouldn't really need to be called again throughout a connection's lifetime.
 *
 * Note that for the sake of simplicity this method does not try to be smart in that it does not assume
 * the presence of functionality based on a previous version check. This allows adding new ivars in the 
 * future a matter of simply performing a new version comparison.
 *
 * To add a new metod for determining a server's support for specific functionality, simply add a new 
 * (read only) ivar with the prefix 'supports' and peform the version checking within this method.
 */
- (void)evaluate
{
	// By default, assumme the server doesn't support anything
	[self _invalidate];
	
	isMySQL3 = (serverMajorVersion == 3);
	isMySQL4 = (serverMajorVersion == 4);
	isMySQL5 = (serverMajorVersion == 5);
	isMySQL6 = (serverMajorVersion == 6);
	
	// The information schema database wasn't added until MySQL 5
	supportsInformationSchema = (serverMajorVersion >= 5);
	
	// Support for spatial extensions wasn't added until MySQL 4.1
	supportsSpatialExtensions = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// The SHOW CHARACTER SET statement wasn't added until MySQL 4.1.0
	supportsShowCharacterSet = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];

	// The SHOW COLLATION statement wasn't added until MySQL 4.1.0
	supportsShowCollation = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// The variables 'character_set_*' and 'collation_*' weren't added until MySQL 4.1.1
	supportsCharacterSetAndCollationVars = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:1];
	
	// As of MySQL 4.1 encoding support was greatly improved
	supportsPost41CharacterSetHandling = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// The table information_schema.engines wasn't added until MySQL 5.1.5
	supportsInformationSchemaEngines = [self isEqualToOrGreaterThanMajorVersion:5 minor:1 release:1];
	
	// The CREATE USER statement wasn't added until MySQL 5.0.2
	supportsCreateUser = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];
	
	// The RENAME USER statement wasn't added until MySQL 5.0.2
	supportsRenameUser = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];
	
	// The DROP USER statement wasn't added until MySQL 4.1.1
	supportsDropUser = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:1];
	
	// Similarly before MySQL 5.0.2 the DROP USER statement only removed users with no privileges
	supportsFullDropUser = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];
	
	// The maximum user variable columns (within mysql.user) weren't added until MySQL 4.0.2
	supportsUserMaxVars = [self isEqualToOrGreaterThanMajorVersion:4 minor:0 release:2];
	
	// The SHOW PRIVILEGES statement wasn't added until MySQL 4.1.0
	supportsShowPrivileges = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];

	// MySQL 4.0.18+ and 4.1.2+ changed the TYPE option to ENGINE, but 4.x supports both
	engineTypeQueryName = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:0] ? @"ENGINE" : @"TYPE";

	// Before MySQL 4.1 the MEMORY engine was known as HEAP and the ISAM engine was available
	supportsPre41StorageEngines = (![self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0]);
	
	// The BLACKHOLE storage engine wasn't added until MySQL 4.1.11
	supportsBlackholeStorageEngine = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:11];
	
	// The ARCHIVE storage engine wasn't added until MySQL 4.1.3
	supportsArchiveStorageEngine = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:3];
	
	// The CSV storage engine wasn't added until MySQL 4.1.4
	supportsCSVStorageEngine = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:4];
	
	// Support for triggers wasn't added until MySQL 5.0.2
	supportsTriggers = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];

	// Support for events wasn't added until MySQL 5.1.6
	supportsEvents = [self isEqualToOrGreaterThanMajorVersion:5 minor:1 release:6];
	
	// Support for specifying an index's key block size wasn't added until MySQL 5.1.10
	supportsIndexKeyBlockSize = [self isEqualToOrGreaterThanMajorVersion:5 minor:1 release:10];
	
	// MySQL 4.0 doesn't seem to like having the ENGINE/TYPE quoted in a table's create syntax
	supportsQuotingEngineTypeInCreateSyntax = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// Fractional second support wasn't added until MySQL 5.6.4
	supportsFractionalSeconds = [self isEqualToOrGreaterThanMajorVersion:5 minor:6 release:4];
	supportsFulltextOnInnoDB  = supportsFractionalSeconds; //introduced in 5.6.4 too
	
	// The SHOW ENGINE query wasn't added until MySQL 4.1.2
	supportsShowEngine = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:2];
}

- (SPInnoDBStatusQueryFormat)innoDBStatusQuery
{
	SPInnoDBStatusQueryFormat tuple = {nil,0};
	
	//if we have SHOW ENGINE go with that
	if(supportsShowEngine) {
		tuple.queryString = @"SHOW ENGINE INNODB STATUS";
		tuple.columnIndex = 2;
	}
	//up to mysql 5.5 we could also use the old SHOW INNODB STATUS
	if([self isEqualToOrGreaterThanMajorVersion:3 minor:23 release:52] &&
	   ![self isEqualToOrGreaterThanMajorVersion:5 minor:5 release:0]) {
		tuple.queryString = @"SHOW INNODB STATUS";
		tuple.columnIndex = 0;
	}
	
	return tuple;
}

/**
 * Convenience method provided as an easy way to determine whether the currently connected server version
 * is equal to or greater than the supplied version numbers. 
 *
 * This method should only be used in the case that the build in support ivars don't cover the version/functionality
 * checking that is required.
 *
 * @param majorVersion   The major version number of the server
 * @param minorVersion   The minor version number of the server
 * @param releaseVersiod The release version number of the server
 *
 * @return A BOOL indicating the result of the comparison.
 */
- (BOOL)isEqualToOrGreaterThanMajorVersion:(NSInteger)majorVersion minor:(NSInteger)minorVersion release:(NSInteger)releaseVersion;
{
	return ([self _compareServerMajorVersion:serverMajorVersion 
									   minor:serverMinorVersion 
									 release:serverReleaseVersion 
					  withServerMajorVersion:majorVersion 
									   minor:minorVersion 
									 release:releaseVersion] > NSOrderedAscending);
}

/**
 * Provides a general description of this object instance. Note that this should only be used for debugging purposes.
 *
 * @return The string describing the object instance
 */
- (NSString *)description
{
	unsigned int i;
	NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: Server is MySQL version %ld.%ld.%ld. Supports:\n", [self className], (long)serverMajorVersion, (long)serverMinorVersion, (long)serverReleaseVersion];
	
	Ivar *vars = class_copyIvarList([self class], &i);
	
	for (NSUInteger j = 0; j < i; j++) 
	{	
		NSString *varName = [NSString stringWithUTF8String:ivar_getName(vars[j])];
		
		if ([varName hasPrefix:@"supports"]) {
			[description appendFormat:@"\t%@ = %@\n", varName, (object_getIvar(self, vars[j])) ? @"YES" : @"NO"];
		}
	}
	
	[description appendString:@">"];
	
	free(vars);
	
	return description;
}

#pragma mark -
#pragma mark Private API

/**
 * Invalidates all knowledge of what we know the server supports by simply reseting all ivars to their
 * original state, that is, it doesn't support anything.
 */
- (void)_invalidate
{
	isMySQL3 = NO;
	isMySQL4 = NO;
	isMySQL5 = NO;
	isMySQL6 = NO;
	
	supportsInformationSchema               = NO;
	supportsSpatialExtensions               = NO;
	supportsShowCharacterSet                = NO;
	supportsShowCollation                   = NO;
	supportsCharacterSetAndCollationVars    = NO;
	supportsPost41CharacterSetHandling      = NO;
	supportsCreateUser                      = NO;
	supportsRenameUser                      = NO;
	supportsDropUser                        = NO;
	supportsFullDropUser                    = NO;
	supportsUserMaxVars                     = NO;
	supportsShowPrivileges                  = NO;
	engineTypeQueryName                     = @"ENGINE";
	supportsInformationSchemaEngines        = NO;
	supportsPre41StorageEngines             = NO;
	supportsBlackholeStorageEngine          = NO;
	supportsArchiveStorageEngine            = NO;
	supportsCSVStorageEngine                = NO;
	supportsTriggers                        = NO;
	supportsEvents                          = NO;
	supportsIndexKeyBlockSize               = NO;
	supportsQuotingEngineTypeInCreateSyntax = NO;
	supportsFractionalSeconds               = NO;
	supportsFulltextOnInnoDB                = NO;
	supportsShowEngine                      = NO;
}

/**
 * Compares the supplied version numbers to determine their order.
 *
 * Note that this method assumes (when comparing MySQL version numbers) that release verions in the form
 * XX are larger than X. For example, version 5.0.18 is greater than version 5.0.8
 *
 * @param majorVersionA   The major version number of server A
 * @param minorVersionA   The minor version number of server A
 * @param releaseVersionA The release version number of server A
 * @param majorVersionB   The major version number of server B
 * @param minorVersionB   The minor version number of server B
 * @param releaseVersionB The release version number of server B
 *
 * @return One of NSComparisonResult constants indicating the order of the comparison
 */
- (NSComparisonResult)_compareServerMajorVersion:(NSInteger)majorVersionA 
										   minor:(NSInteger)minorVersionA 
										 release:(NSInteger)releaseVersionA
						  withServerMajorVersion:(NSInteger)majorVersionB
										   minor:(NSInteger)minorVersionB
										 release:(NSInteger)releaseVersionB
{	
	if (majorVersionA > majorVersionB) return NSOrderedDescending;

	if (majorVersionA < majorVersionB) return NSOrderedAscending;
	
	// The major versions are the same so move to checking the minor versions
	if (minorVersionA > minorVersionB) return NSOrderedDescending;
	
	if (minorVersionA < minorVersionB) return NSOrderedAscending;
	
	// The minor versions are the same so move to checking the release versions
	if (releaseVersionA > releaseVersionB) return NSOrderedDescending;
	
	if (releaseVersionA < releaseVersionB) return NSOrderedAscending;
	
	// Both version numbers are the same
	return NSOrderedSame;
}

#pragma mark -
#pragma mark Other

- (void)dealloc
{
	// Reset version integers
	serverMajorVersion   = 0;
	serverMinorVersion   = 0;
	serverReleaseVersion = 0;
	
	// Invalidate all ivars
	[self _invalidate];
	
	[super dealloc];
}

@end
