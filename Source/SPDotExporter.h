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
	NSObject <SPDotExporterProtocol> *delegate;
	
	NSArray *dotExportTables;
	
	NSString *dotExportCurrentTable;
	
	SPTableData *dotTableData;
	
	NSString *dotDatabaseHost;
	NSString *dotDatabaseName;
	NSString *dotDatabaseVersion;
}

/**
 * @property delegate Exporter delegate
 */
@property(readwrite, assign) NSObject *delegate;

/**
 * @property dotExportTables Table information
 */
@property(readwrite, retain) NSArray *dotExportTables;

/**
 * @property dotExportCurrentTable Current table
 */
@property(readwrite, retain) NSString *dotExportCurrentTable;

/**
 * @property dotTableData Table data
 */
@property(readwrite, retain) SPTableData *dotTableData;

/**
 * @property dotDatabaseHost Database host
 */
@property(readwrite, retain) NSString *dotDatabaseHost;

/**
 * @property dotDatabaseName Database name
 */
@property(readwrite, retain) NSString *dotDatabaseName;

/**
 * @property dotDatabaseVersion Database version
 */
@property(readwrite, retain) NSString *dotDatabaseVersion;

- (id)initWithDelegate:(NSObject *)exportDelegate;

@end
