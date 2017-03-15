//
//  SPTableInfo.h
//  sequel-pro
//
//  Created by Ben Perry on Jun 6, 2008.
//  Copyright (c) 2008 Ben Perry. All rights reserved.
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

@class SPTableView;
@class SPTablesList;
@class SPTableData;
@class SPDatabaseDocument;

@interface SPTableInfo : NSObject 
{
	IBOutlet SPTableView *tableList;
	IBOutlet SPTablesList *tableListInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPDatabaseDocument *tableDocumentInstance;

	IBOutlet NSTableView *infoTable;
	IBOutlet NSTableView *activitiesTable;
	IBOutlet NSScrollView *tableInfoScrollView;

	NSMutableArray *info;
	NSMutableArray *activities;
	BOOL _activitiesWillBeUpdated;
}

- (void)tableChanged:(NSNotification *)notification;
- (void)updateActivities;
- (void)removeActivity:(NSInteger)pid;

@end
