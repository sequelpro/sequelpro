//
//  SPServerSupport.h
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

typedef struct {
	NSString *queryString;
	NSUInteger columnIndex;
} SPInnoDBStatusQueryFormat;

/**
 * @class SPServerSupport SPServerSupport.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * This class is provided as a convenient method of determining what features/functionality the MySQL server
 * with the supplied version numbers supports. Note that this class has no direct connection to the server,
 * all of it's information is simply determined by way of version comparisons using hard coded values of known
 * versions and the functionality they support.
 *
 * Every new MySQL connection that is established should create an instance of this class and make it globally
 * accessible to the rest of the application to remove the need of manual version comparisons. Calling it's 
 * designated initializer (initWithMajorVersion:major:minor:release:) causes the determination of what 
 * functionality is supported, and so other initializtion is required.
 *
 * See the method evaluate for information regarding adding additional functionality checks.
 */
@interface SPServerSupport : NSObject 
{
	// Convenience vars
	BOOL isMySQL3;
	BOOL isMySQL4;
	BOOL isMySQL5;
	BOOL isMySQL6;
	
	// General
	BOOL supportsInformationSchema;
	BOOL supportsSpatialExtensions;
	
	// Encoding
	BOOL supportsShowCharacterSet;
    BOOL supportsShowCollation;
	BOOL supportsCharacterSetAndCollationVars;
	BOOL supportsPost41CharacterSetHandling;
	
	// User account related
	BOOL supportsCreateUser;
	BOOL supportsRenameUser;
	BOOL supportsDropUser;
	BOOL supportsFullDropUser;
	BOOL supportsUserMaxVars;
	BOOL supportsShowPrivileges;
	
	// Storage engines
	NSString *engineTypeQueryName;
	BOOL supportsInformationSchemaEngines;
	BOOL supportsPre41StorageEngines;
	BOOL supportsBlackholeStorageEngine;
	BOOL supportsArchiveStorageEngine;
	BOOL supportsCSVStorageEngine;
	BOOL supportsQuotingEngineTypeInCreateSyntax;
	BOOL supportsShowEngine;
	
	// Triggers
	BOOL supportsTriggers;
	
	// Indexes
	BOOL supportsIndexKeyBlockSize;
	BOOL supportsFulltextOnInnoDB;

	// Events
	BOOL supportsEvents;
	
	// Data types
	BOOL supportsFractionalSeconds;
	
	// Server versions
	NSInteger serverMajorVersion;
	NSInteger serverMinorVersion;
	NSInteger serverReleaseVersion;
}

/**
 * @property serverMajorVersion
 */
@property (readwrite, assign) NSInteger serverMajorVersion;

/**
 * @property serverMinorVersion
 */
@property (readwrite, assign) NSInteger serverMinorVersion;

/**
 * @property serverReleaseVersion
 */
@property (readwrite, assign) NSInteger serverReleaseVersion;

/**
 * @property isMySQL3 Indicates if the server is MySQL version 3
 */
@property (readonly) BOOL isMySQL3;

/**
 * @property isMySQL4 Indicates if the server is MySQL version 4
 */
@property (readonly) BOOL isMySQL4;

/**
 * @property isMySQL5 Indicates if the server is MySQL version 5
 */
@property (readonly) BOOL isMySQL5;

/**
 * @property isMySQL6 Indicates if the server is MySQL version 6
 */
@property (readonly) BOOL isMySQL6;

/**
 * @property supportsInformationSchema Indicates if the server supports the information_schema database
 */
@property (readonly) BOOL supportsInformationSchema;

/**
 * @property supportsSpatialExtensions Indicates if the server supports spatial extensions
 */
@property (readonly) BOOL supportsSpatialExtensions;

/**
 * @property supportsShowCharacterSet Indicates if the server supports the SHOW CHARACTER SET statement
 */
@property (readonly) BOOL supportsShowCharacterSet;

/**
 * @property supportsShowCollation Indicates if the server supports the SHOW COLLATION statement
 */
@property (readonly) BOOL supportsShowCollation;

/**
 * @property supportsCharacterSetAndCollationVars Indicates if the server supports the 'character_set_*' and 'collation_*'
 *                                           variables.
 */
@property (readonly) BOOL supportsCharacterSetAndCollationVars;

/**
 * @property supportsPost41CharacterSetHandling Indicates whether the server supports post 4.1 character set
 *                                              handling.
 */
@property (readonly) BOOL supportsPost41CharacterSetHandling;

/**
 * @property supportsCreateUser Indicates if the server supports the CREATE USER statement
 */
@property (readonly) BOOL supportsCreateUser;

/**
 * @property supportsRenameUser Indicates if the server supports the RENAME USER statement
 */
@property (readonly) BOOL supportsRenameUser;

/**
 * @property supportsDropUser Indicates if the server supports the DROP USER statement
 */
@property (readonly) BOOL supportsDropUser;

/**
 * @property supportsFullDropUser Indicates if the server supports deleting a user's priveleges when issueing
 *                                the DROP USER statement.
 */
@property (readonly) BOOL supportsFullDropUser;

/**
 * @property supportsUserMaxVars Indicates if the server supports setting a user's maximum variables
 */
@property (readonly) BOOL supportsUserMaxVars;

/**
 * @property supportsShowPrivileges Indicates if the server supports the SHOW PRIVILEGES statement
 */
@property (readonly) BOOL supportsShowPrivileges;

/**
 * @property engineTypeQueryName Returns the appropriate query part for specifying table engine - ENGINE or TYPE
 */
@property (readonly) NSString *engineTypeQueryName;

/**
 * @property supportsInformationSchemaEngines Indicates if the server supports the information_schema.engines table
 */
@property (readonly) BOOL supportsInformationSchemaEngines;

/**
 * @property supportsPre41StorageEngines Indicates if the server supports storage engines available prior 
 *                                       to MySQL 4.1 
 */
@property (readonly) BOOL supportsPre41StorageEngines;

/**
 * @property supportsBlackholeStorageEngine Indicates if the server supports the BLACKHOLE storage engine
 */
@property (readonly) BOOL supportsBlackholeStorageEngine;

/**
 * @property supportsArchiveStorageEngine Indicates if the server supports the ARCHIVE storage engine
 */
@property (readonly) BOOL supportsArchiveStorageEngine;

/**
 * @property supportsCSVStorageEngine Indicates if the server supports the CSV storage engine
 */
@property (readonly) BOOL supportsCSVStorageEngine;

/**
 * @property supportsTriggers Indicates if the server supports table triggers
 */
@property (readonly) BOOL supportsTriggers;

/**
* @property supportsEvents Indicates if the server supports scheduled events
*/
@property (readonly) BOOL supportsEvents;

/**
 * @property supportsIndexKeyBlockSize Indicates if the server supports specifying an index's key block size
 */
@property (readonly) BOOL supportsIndexKeyBlockSize;

/**
 * @property supportsQuotingEngineTypeInCreateSyntax Indicates whether the server supports quoting the engine
 *                                                   type in the create syntax.
 */
@property (readonly) BOOL supportsQuotingEngineTypeInCreateSyntax;

/**
 * @property supportsFractionalSeconds Indicates whether the server supports fractional seconds in date/time data types.
 */
@property (readonly) BOOL supportsFractionalSeconds;

/**
 * @property supportsFulltextOnInnoDB Indicates whether the server supports FULLTEXT indexes with the InnoDb engine.
 */
@property (readonly) BOOL supportsFulltextOnInnoDB;

/**
 * @property supportsShowEngine Indicates whether the server supports the "SHOW ENGINE x {LOGS|STATUS}" query.
 */
@property (readonly) BOOL supportsShowEngine;

- (id)initWithMajorVersion:(NSInteger)majorVersion minor:(NSInteger)minorVersion release:(NSInteger)releaseVersion;

- (void)evaluate;
- (BOOL)isEqualToOrGreaterThanMajorVersion:(NSInteger)majorVersion minor:(NSInteger)minorVersion release:(NSInteger)releaseVersion;

/**
 * @return The correct query to get the InnoDB engine status. queryString is nil for unsupported versions.
 *         The columnIndex tells the index of the column (starting with 0) in which the status text is returned.
 */
- (SPInnoDBStatusQueryFormat)innoDBStatusQuery;
@end
