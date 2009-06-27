//
//  BWSelectableToolbarHelper.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWSelectableToolbarHelper : NSObject 
{
	NSMutableDictionary *contentViewsByIdentifier, *windowSizesByIdentifier;
	NSString *selectedIdentifier, *oldWindowTitle;
	NSSize initialIBWindowSize;
	BOOL isPreferencesToolbar;
}

@property (copy) NSMutableDictionary *contentViewsByIdentifier;
@property (copy) NSMutableDictionary *windowSizesByIdentifier;
@property (copy) NSString *selectedIdentifier;
@property (copy) NSString *oldWindowTitle;
@property (assign) NSSize initialIBWindowSize;
@property (assign) BOOL isPreferencesToolbar;

@end
