#import "CPTMutableTextStyle.h"

/** @brief Mutable wrapper for text style properties.
 *
 *  Use this whenever you need to customize the properties of a text style.
 **/

@implementation CPTMutableTextStyle

/** @property CPTNativeFont* font
 *  @brief The font. Default is @nil.
 *
 *  Font will override fontName and fontSize if not @nil.
 **/
@synthesize font;

/** @property CGFloat fontSize
 *  @brief The font size. Default is @num{12.0}. Ignored if font is not @nil.
 **/
@dynamic fontSize;

/** @property nullable NSString *fontName
 *  @brief The font name. Default is Helvetica. Ignored if font is not @nil.
 **/
@dynamic fontName;

/** @property nullable CPTColor *color
 *  @brief The current text color. Default is solid black.
 **/
@dynamic color;

/** @property CPTTextAlignment textAlignment
 *  @brief The paragraph alignment for multi-line text. Default is #CPTTextAlignmentLeft.
 **/
@dynamic textAlignment;

/** @property NSLineBreakMode lineBreakMode
 *  @brief The line break mode used when laying out the text. Default is @link NSParagraphStyle::NSLineBreakByWordWrapping NSLineBreakByWordWrapping @endlink.
 **/
@dynamic lineBreakMode;

@end
