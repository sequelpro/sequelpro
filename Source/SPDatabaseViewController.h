//
//  SPDatabaseViewController.h
//  sequel-pro
//
//  Created by Rowan Beentje on October 31, 2010.
//  Copyright (c) 2010 Arboreal. All rights reserved.
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

#import "SPDatabaseDocument.h"

@interface SPDatabaseDocument (SPDatabaseViewController)

// Accessors
- (NSString *)table;
- (SPTableType)tableType;

- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

#ifndef SP_CODA /* method decls */
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
- (void)setRelationsRequiresReload:(BOOL)reload;

// Table control
- (void)loadTable:(NSString *)aTable ofType:(SPTableType)aTableType;

// Loading queries
- (void) viewCustomQuery:(id)sender withString:(NSString*)query;

#ifndef SP_CODA /* method decls */
- (NSView *)databaseView;
#endif

@end
