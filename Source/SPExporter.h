//
//  $Id$
//
//  SPExporter.h
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

/**
 * This class is designed to be the base class of all data exporters and provide basic functionality
 * common to each of them. Each data exporter (i.e. CSV, SQL, XML, etc.) should be implemented as a subclass
 * of this class, with the end result being an uncomplicated export architecture defined by export type.
 *
 * All export functionality is initially controlled by SPExportController, which is the single point within the
 * architecture that controls the user interface and provides user feedback. When the user starts an export 
 * operation after selecting the available options, SPExportController should create an instance of the appropriate
 * exporter (e.g. SPCSVExporter for a CSV export) and begin the export process. Any available progress information
 * (defined in SPExporter as is common to all exporters) of the export should be set by the exporter and made 
 * available to SPExportController via delegate methods in order to update the user interface.
 *
 * Note that all core export processes should be designed and implemented to run in a separate thread to avoid
 * blocking the main thread and also to provide improved efficiency over the current design (for example, all memory
 * used within a separate thread can be reclaimed immediately after the thread completes its cycle and it's 
 * autorelease pool is released).
 */
@interface SPExporter : NSObject 

// Implement functionality common to all exporters here

@end
