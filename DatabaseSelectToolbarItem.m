//
//  DatabaseSelectToolbarItem.m
//  sequel-pro
//
//  Created by Abhi Beckert on 27/04/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "DatabaseSelectToolbarItem.h"


@implementation DatabaseSelectToolbarItem

- (id)initWithItemIdentifier:(NSString *)itemIdentifier
{
  if (![super initWithItemIdentifier:itemIdentifier])
    return nil;
  
  if (![NSBundle loadNibNamed:@"DatabaseSelectToolbarView" owner:self]) {
    NSLog(@"Failed to load database select toolbar item nib");
    [self release];
    return nil;
  }
  
  [self setLabel:NSLocalizedString(@"Select Database", @"toolbar item for selecting a db")];
  [self setPaletteLabel:[self label]];
  [self setView:toolbarItemView];
  
  return self;
}

- (NSPopUpButton *)databaseSelectPopupButton
{
  return dbSelectPopupButton;
}

- (NSSize)minSize
{
  return NSMakeSize(200,26);
}

- (NSSize)maxSize
{
  return NSMakeSize(200,32);
}

@end

NSString *DatabaseSelectToolbarItemIdentifier = @"DatabaseSelectToolbarItemIdentifier";