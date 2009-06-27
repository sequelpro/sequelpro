//
//  BWStyledTextFieldInspector.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWStyledTextField.h"

@interface BWStyledTextFieldInspector : IBInspector 
{
	BWStyledTextField *textField;
	int shadowPositionPopupSelection, fillPopupSelection;
}

@property int shadowPositionPopupSelection, fillPopupSelection;

@end
