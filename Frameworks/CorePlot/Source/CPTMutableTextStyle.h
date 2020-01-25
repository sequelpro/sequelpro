#import "CPTTextStyle.h"

@class CPTColor;

@interface CPTMutableTextStyle : CPTTextStyle

@property (readwrite, strong, nonatomic, nullable) CPTNativeFont *font;
@property (readwrite, copy, nonatomic, nullable) NSString *fontName;
@property (readwrite, assign, nonatomic) CGFloat fontSize;
@property (readwrite, copy, nonatomic, nullable) CPTColor *color;
@property (readwrite, assign, nonatomic) CPTTextAlignment textAlignment;
@property (readwrite, assign, nonatomic) NSLineBreakMode lineBreakMode;

@end
