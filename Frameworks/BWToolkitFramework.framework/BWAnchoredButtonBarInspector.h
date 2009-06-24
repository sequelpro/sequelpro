//
//  BWAnchoredButtonBarViewInspector.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>

@interface BWAnchoredButtonBarInspector : IBInspector 
{
	IBOutlet NSMatrix *matrix;
	IBOutlet NSImageView *selectionView;
	IBOutlet NSView *contentView;
}

- (IBAction)selectMode1:(id)sender;
- (IBAction)selectMode2:(id)sender;
- (IBAction)selectMode3:(id)sender;

@end
