//
//  MainController.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import <Cocoa/Cocoa.h>


@interface MainController : NSObject {

    IBOutlet id keyChainInstance;

    IBOutlet id preferencesWindow;
    IBOutlet id favoriteSheet;
    IBOutlet id reloadAfterAddingSwitch;
    IBOutlet id reloadAfterEditingSwitch;
    IBOutlet id reloadAfterRemovingSwitch;
    IBOutlet id showErrorSwitch;
    IBOutlet id dontShowBlobSwitch;
    IBOutlet id useMonospacedFontsSwitch;
    IBOutlet id fetchRowCountSwitch;
    IBOutlet id limitRowsSwitch;
    IBOutlet id limitRowsField;
    IBOutlet id nullValueField;
    IBOutlet id tableView;
    IBOutlet id nameField;
    IBOutlet id hostField;
    IBOutlet id socketField;
    IBOutlet id userField;
    IBOutlet id passwordField;
    IBOutlet id portField;
    IBOutlet id databaseField;
	IBOutlet id sshCheckbox;
    IBOutlet id sshUserField;
    IBOutlet id sshPasswordField;
    IBOutlet id sshHostField;
    IBOutlet id sshPortField;
    IBOutlet id encodingPopUpButton;

    NSMutableArray *favorites;
    NSUserDefaults *prefs;
    
    BOOL isNewFavorite;
}

//IBAction methods
- (IBAction)openPreferences:(id)sender;
- (IBAction)addFavorite:(id)sender;
- (IBAction)removeFavorite:(id)sender;
- (IBAction)copyFavorite:(id)sender;
- (IBAction)chooseLimitRows:(id)sender;
- (IBAction)closeFavoriteSheet:(id)sender;
- (IBAction)toggleUseSSH:(id)sender;

//services menu methods
- (void)doPerformQueryService:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;

//menu methods
- (IBAction)donate:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)visitHelpWebsite:(id)sender;
- (IBAction)checkForUpdates:(id)sender;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView
            objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex;

//tableView drag&drop datasource methods
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
    proposedDropOperation:(NSTableViewDropOperation)operation;
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row
    dropOperation:(NSTableViewDropOperation)operation;

//tableView delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

//window delegate methods
- (BOOL)windowShouldClose:(id)sender;

//other methods
- (void)awakeFromNib;

//SSHTunnel methods
- (id)authenticate:(NSScriptCommand *)command;
- (id)handleQuitScriptCommand:(NSScriptCommand *)command;

@end
