//
//  $Id$
//
//  SPSQLExporter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import <Cocoa/Cocoa.h>

#import "SPExporter.h"
#import "SPSQLExporterProtocol.h"

/**
 * @class SPSQLExporter SPSQLExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SQL exporter class.
 */
@interface SPSQLExporter : SPExporter
{
	NSObject <SPSQLExporterProtocol> *delegate;
	
	/**
	 * Tables
	 */
	NSArray *sqlExportTables;
	
	/**
	 * Database host
	 */
	NSString *sqlDatabaseHost;
	
	/**
	 * Database name
	 */
	NSString *sqlDatabaseName;
	
	/**
	 * Database version
	 */
	NSString *sqlDatabaseVersion;
	
	/**
	 * Current table
	 */
	NSString *sqlExportCurrentTable;
	
	/**
	 * Export errors
	 */
	NSString *sqlExportErrors;
	
	/**
	 * Include UTF-8 BOM
	 */
	BOOL sqlOutputIncludeUTF8BOM;
	
	/**
	 * Include export errors
	 */
	BOOL sqlOutputIncludeErrors;
	
	/**
	 * Compress output
	 */
	BOOL sqlOutputCompressFile;
	
	/**
	 * Table information
	 */
	NSDictionary *sqlTableInformation;
}

@property(readwrite, assign) NSObject *delegate;

@property(readwrite, retain) NSArray *sqlExportTables;

@property(readwrite, retain) NSString *sqlDatabaseHost;
@property(readwrite, retain) NSString *sqlDatabaseName;
@property(readwrite, retain) NSString *sqlDatabaseVersion;

@property(readwrite, retain) NSString *sqlExportCurrentTable;
@property(readwrite, retain) NSString *sqlExportErrors;

@property(readwrite, assign) BOOL sqlOutputIncludeUTF8BOM;
@property(readwrite, assign) BOOL sqlOutputIncludeErrors;
@property(readwrite, assign) BOOL sqlOutputCompressFile;

@property (readwrite, retain) NSDictionary *sqlTableInformation;

/**
 * Initialise an instance of SPSQLExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject *)exportDelegate;

/**
 * Returns whether or not any export errors occurred.
 *
 * @return A BOOL indicating the occurrence of errors
 */
- (BOOL)didExportErrorsOccur;

@end
