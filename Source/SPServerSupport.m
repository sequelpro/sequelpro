//
//  $Id$
//
//  SPServerSupport.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 23, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPServerSupport.h"
#import <objc/runtime.h>

@interface SPServerSupport (PrivateAPI)

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
@synthesize supportsShowCharacterSet;
@synthesize supportsCharacterSetDatabaseVar;
@synthesize supportsPost41CharacterSetHandling;
@synthesize supportsCreateUser;
@synthesize supportsDropUser;
@synthesize supportsFullDropUser;
@synthesize supportsUserMaxVars;
@synthesize supportsShowPrivileges;
@synthesize supportsInformationSchemaEngines;
@synthesize supportsPre41StorageEngines;
@synthesize supportsBlackholeStorageEngine;
@synthesize supportsArchiveStorageEngine;
@synthesize supportsCSVStorageEngine;
@synthesize supportsTriggers;
@synthesize supportsIndexKeyBlockSize;
@synthesize serverMajorVersion;
@synthesize serverMinorVersion;
@synthesize serverReleaseVersion;

#pragma mark -
#pragma mark Initialization

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
	if ((self == [super init])) {
		
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
	
	// The SHOW CHARACTER SET statement wasn't added until MySQL 4.1.0
	supportsShowCharacterSet = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// The variable 'character_set_database' wasn't added until MySQL 4.1.1
	supportsCharacterSetDatabaseVar = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:1];
	
	// As of MySQL 4.1 encoding support was greatly improved
	supportsPost41CharacterSetHandling = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
	// The table information_schema.engines wasn't added until MySQL 5.1.5
	supportsInformationSchemaEngines = [self isEqualToOrGreaterThanMajorVersion:5 minor:1 release:1];
	
	// The CREATE USER statement wasn't added until MySQL 5.0.2
	supportsCreateUser = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];
	
	// The DROP USER statement wasn't added until MySQL 4.1.1
	supportsDropUser = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:1];
	
	// Similarly before MySQL 5.0.2 the DROP USER statement only removed users with no privileges
	supportsFullDropUser = [self isEqualToOrGreaterThanMajorVersion:5 minor:0 release:2];
	
	// The maximum user variable columns (within mysql.user) weren't added until MySQL 4.0.2
	supportsUserMaxVars = [self isEqualToOrGreaterThanMajorVersion:4 minor:0 release:2];
	
	// The SHOW PRIVILEGES statement wasn't added until MySQL 4.1.0
	supportsShowPrivileges = [self isEqualToOrGreaterThanMajorVersion:4 minor:1 release:0];
	
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
	
	// Support for specifying an index's key block size wasn't added until MySQL 5.1.10
	supportsIndexKeyBlockSize = [self isEqualToOrGreaterThanMajorVersion:5 minor:1 release:10];	
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
	NSString *description = [NSMutableString stringWithFormat:@"<%@: Server is MySQL version %d.%d.%d. Supports:\n", [self className], serverMajorVersion, serverMinorVersion, serverReleaseVersion];
	
	Ivar *vars = class_copyIvarList([self class], &i);
	
	for (NSUInteger j = 0; j < i; j++) 
	{	
		NSString *varName = [NSString stringWithUTF8String:ivar_getName(vars[j])];
		
		if ([varName hasPrefix:@"supports"]) {
			[description appendFormat:@"\t%@ = %@\n", varName, ((BOOL)object_getIvar(self, vars[j])) ? @"YES" : @"NO"];
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
	isMySQL3                           = NO;
	isMySQL4                           = NO;
	isMySQL5                           = NO;
	isMySQL6                           = NO;
	
	supportsInformationSchema          = NO;
	supportsShowCharacterSet           = NO;
	supportsCharacterSetDatabaseVar    = NO;
	supportsPost41CharacterSetHandling = NO;
	supportsCreateUser                 = NO;
	supportsDropUser                   = NO;
	supportsFullDropUser               = NO;
	supportsUserMaxVars                = NO;
	supportsShowPrivileges             = NO;
	supportsInformationSchemaEngines   = NO;
	supportsPre41StorageEngines        = NO;
	supportsBlackholeStorageEngine     = NO;
	supportsArchiveStorageEngine       = NO;
	supportsCSVStorageEngine           = NO;
	supportsTriggers                   = NO;
	supportsIndexKeyBlockSize          = NO;
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

/**
 * Dealloc. Invalidate all ivars.
 */
- (void)dealloc
{
	// Reset version integers
	serverMajorVersion   = -1;
	serverMinorVersion   = -1;
	serverReleaseVersion = -1;
	
	// Invalidate all ivars
	[self _invalidate];
	
	[super dealloc];
}

@end
