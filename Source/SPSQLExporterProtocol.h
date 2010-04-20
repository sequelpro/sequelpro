//
//  $Id$
//
//  SPSQLExporterProtocol.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 15, 2010
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

@class SPSQLExporter;

/**
 * @protocol SPSQLExporterProtocol SPSQLExporterProtocol.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SQL exporter delegate protocol.
 */
@protocol SPSQLExporterProtocol

/**
 * Called when the SQL export process is about to begin. 
 * 
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBegin:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is complete.
 * 
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessComplete:(SPSQLExporter *)exporter;

/**
 * alled when the progress of the SQL export process is updated.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessProgressUpdated:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is about to begin fetching data from the database.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBeginFetchingData:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is about to begin writing data to disk.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBeginWritingData:(SPSQLExporter *)exporter;

@end
