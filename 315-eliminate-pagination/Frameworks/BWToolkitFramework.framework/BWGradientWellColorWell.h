//
//  BWGradientWellColorWell.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>
#import "BWGradientWell.h"

@interface BWGradientWellColorWell : NSColorWell
{
	BWGradientWell *gradientWell;
}

@property (nonatomic, retain) IBOutlet BWGradientWell *gradientWell;

@end
