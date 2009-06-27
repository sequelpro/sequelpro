//
//  BWGradientBoxInspector.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWGradientBox.h"
#import "BWGradientWell.h"

@interface BWGradientBoxInspector : IBInspector 
{
	BWGradientBox *box;
	int fillPopupSelection;
}

@property int fillPopupSelection;

@end
