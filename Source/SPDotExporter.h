//
//  $Id$
//
//  SPDotExporter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 17, 2010
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
#import "SPDotExporterProtocol.h"

@class SPTableData;

/**
 * @class SPXMLExporter SPXMLExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * XML exporter class.
 */
@interface SPDotExporter : SPExporter 
{
	/**
	 * Exporter delegate
	 */
	NSObject <SPDotExporterProtocol> *delegate;
	
	/**
	 * Table information
	 */
	NSArray *dotExportTables;
	
	/**
	 * Current table
	 */
	NSString *dotExportCurrentTable;
	
	/**
	 * Table data
	 */
	SPTableData *dotTableData;
	
	/**
	 * Database host
	 */
	NSString *dotDatabaseHost;
	
	/**
	 * Database name
	 */
	NSString *dotDatabaseName;
	
	/**
	 * Database version
	 */
	NSString *dotDatabaseVersion;
}

@property(readwrite, assign) NSObject *delegate;
@property(readwrite, retain) NSArray *dotExportTables;
@property(readwrite, retain) NSString *dotExportCurrentTable;
@property(readwrite, retain) SPTableData *dotTableData;

@property(readwrite, retain) NSString *dotDatabaseHost;
@property(readwrite, retain) NSString *dotDatabaseName;
@property(readwrite, retain) NSString *dotDatabaseVersion;

/**
 * Initialise an instance of SPDotExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject *)exportDelegate;

@end
