//
//  SPTableFooterPopUpButtonCell.m
//  sequel-pro
//
//  Created by Woody Beckert on 15/04/2016.
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
//

#import "SPTableFooterPopUpButtonCell.h"

@implementation SPTableFooterPopUpButtonCell

- (void)drawImageWithFrame:(NSRect)cellRect inView:(NSView *)controlView{
	NSImage *image = self.image;
	if([self isHighlighted] && self.alternateImage){
		image = self.alternateImage;
	}
	
	//TODO: respect -(NSCellImagePosition)imagePosition
	NSRect imageRect = NSZeroRect;
	imageRect.origin.y = (CGFloat)round(cellRect.size.height*0.5f-image.size.height*0.5f);
	imageRect.origin.x = (CGFloat)round(cellRect.size.width*0.5f-image.size.width*0.5f);
	imageRect.size = image.size;
	
	[image drawInRect:imageRect
					 fromRect:NSZeroRect
					operation:NSCompositeSourceOver
					 fraction:1.0f
		 respectFlipped:YES
							hints:nil];
}

@end
