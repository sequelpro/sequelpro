//
//  $Id$
//
//  SPDatabaseViewController.h
//  sequel-pro
//
//  Created by Rowan Beentje on 31/10/2010.
//  Copyright 2010 Arboreal. All rights reserved.
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

#import "SPDatabaseDocument.h"


@interface SPDatabaseDocument (SPDatabaseViewController)

// Getters
- (NSString *)table;
- (SPTableType)tableType;
- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

#ifndef SP_REFACTOR /* method decls */
// Tab view control
- (IBAction)viewStructure:(id)sender;
- (IBAction)viewContent:(id)sender;
- (IBAction)viewQuery:(id)sender;
- (IBAction)viewStatus:(id)sender;
- (IBAction)viewRelations:(id)sender;
- (IBAction)viewTriggers:(id)sender;
#endif
- (void)setStructureRequiresReload:(BOOL)reload;
- (void)setContentRequiresReload:(BOOL)reload;
- (void)setStatusRequiresReload:(BOOL)reload;

// Table control
- (void)loadTable:(NSString *)aTable ofType:(NSInteger)aTableType;

#ifndef SP_REFACTOR /* method decls */
- (NSView *)databaseView;
#endif

@end
