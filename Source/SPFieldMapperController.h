//
//  $Id$
//
//  SPQueryFavoriteManager.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 01, 2010
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
#import <MCPKit/MCPKit.h>



@interface SPFieldMapperController : NSWindowController {

	IBOutlet id fieldMapperView;
	IBOutlet id fieldMapperTableView;
	IBOutlet id tableTargetPopup;
	IBOutlet id fileSourcePath;
	IBOutlet id importMethodPopup;
	IBOutlet id rowUpButton;
	IBOutlet id rowDownButton;
	IBOutlet id recordCountLabel;
	
	id theDelegate;
	
	NSInteger fieldMappingCurrentRow;
	NSArray *fieldMappingImportArray;
	NSArray *fieldMappingArray;

	BOOL fieldMappingImportArrayIsPreview;

	MCPConnection *mySQLConnection;

}

- (id)initWithDelegate:(id)managerDelegate;

- (void)setConnection:(MCPConnection *)theConnection;

// IBAction methods
- (IBAction)changeTableTarget:(id)sender;
- (IBAction)changeImportMethod:(id)sender;
- (IBAction)stepRow:(id)sender;

@end
