//
//  $Id$
//
//  SPContentFilterManager.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Sep 29, 2009
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

@interface NSObject (SPContentFilterManagerDelegate)

- (void)contentFiltersHaveBeenUpdated:(id)manager;

@end

@interface SPContentFilterManager : NSWindowController 
{
	NSUserDefaults *prefs;
	
	NSURL *delegatesFileURL;
	IBOutlet id encodingPopUp;
	IBOutlet id contentFilterTableView;
	IBOutlet id contentFilterNameTextField;
	IBOutlet id contentFilterConjunctionTextField;
	IBOutlet id contentFilterConjunctionLabel;
	IBOutlet id contentFilterTextView;
	IBOutlet id removeButton;
	IBOutlet id numberOfArgsLabel;
	IBOutlet id resultingClauseLabel;
	IBOutlet id resultingClauseContentLabel;
	IBOutlet id insertPlaceholderButton;

	IBOutlet id contentFilterArrayController;
	
	NSMutableArray *contentFilters;

	BOOL isTableCellEditing;
	
	NSString *filterType;
}

- (id)initWithDelegate:(id)managerDelegate forFilterType:(NSString *)compareType;

// Accessors
- (NSMutableArray *)contentFilterForFileURL:(NSURL *)fileURL;
- (id)customQueryInstance;

// IBAction methods
- (IBAction)addContentFilter:(id)sender;
- (IBAction)removeContentFilter:(id)sender;
- (IBAction)insertPlaceholder:(id)sender;
- (IBAction)duplicateContentFilter:(id)sender;
- (IBAction)exportContentFilter:(id)sender;
- (IBAction)importContentFilterByAdding:(id)sender;
// - (IBAction)importContentFilterByReplacing:(id)sender;
- (IBAction)closeContentFilterManagerSheet:(id)sender;

@end
