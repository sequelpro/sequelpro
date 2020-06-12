#import "CPTTextStylePlatformSpecific.h"

#import "CPTColor.h"
#import "CPTMutableTextStyle.h"
#import "CPTPlatformSpecificCategories.h"
#import "CPTPlatformSpecificFunctions.h"
#import "tgmath.h"

@implementation CPTTextStyle(CPTPlatformSpecificTextStyleExtensions)

/** @property nonnull CPTDictionary *attributes
 *  @brief A dictionary of standard text attributes suitable for formatting an NSAttributedString.
 *
 *  The dictionary will contain values for the following keys that represent the receiver's text style:
 *  - #NSFontAttributeName: The font used to draw text. If missing, no font information was specified.
 *  - #NSForegroundColorAttributeName: The color used to draw text. If missing, no color information was specified.
 *  - #NSParagraphStyleAttributeName: The text alignment and line break mode used to draw multi-line text.
 **/
@dynamic attributes;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Creates and returns a new CPTTextStyle instance initialized from a dictionary of text attributes.
 *
 *  The text style will be initalized with values associated with the following keys:
 *  - #NSFontAttributeName: Sets the @link CPTTextStyle::fontName fontName @endlink
 *  and @link CPTTextStyle::fontSize fontSize @endlink.
 *  - #NSForegroundColorAttributeName: Sets the @link CPTTextStyle::color color @endlink.
 *  - #NSParagraphStyleAttributeName: Sets the @link CPTTextStyle::textAlignment textAlignment @endlink and @link CPTTextStyle::lineBreakMode lineBreakMode @endlink.
 *
 *  Properties associated with missing keys will be inialized to their default values.
 *
 *  @param attributes A dictionary of standard text attributes.
 *  @return A new CPTTextStyle instance.
 **/
+(nonnull instancetype)textStyleWithAttributes:(nullable CPTDictionary *)attributes
{
    CPTMutableTextStyle *newStyle = [CPTMutableTextStyle textStyle];

    // Font
    UIFont *styleFont = attributes[NSFontAttributeName];

    if ( styleFont ) {
        newStyle.font     = styleFont;
        newStyle.fontName = styleFont.fontName;
        newStyle.fontSize = styleFont.pointSize;
    }

    // Color
    UIColor *styleColor = attributes[NSForegroundColorAttributeName];
    if ( styleColor ) {
        newStyle.color = [CPTColor colorWithCGColor:styleColor.CGColor];
    }

    // Text alignment and line break mode
    NSParagraphStyle *paragraphStyle = attributes[NSParagraphStyleAttributeName];
    if ( paragraphStyle ) {
        newStyle.textAlignment = (CPTTextAlignment)paragraphStyle.alignment;
        newStyle.lineBreakMode = paragraphStyle.lineBreakMode;
    }

    return [newStyle copy];
}

#pragma mark -
#pragma mark Accessors

/// @cond

-(nonnull CPTDictionary *)attributes
{
    CPTMutableDictionary *myAttributes = [NSMutableDictionary dictionary];

    // Font
    UIFont *styleFont  = self.font;
    NSString *fontName = self.fontName;

    if ((styleFont == nil) && fontName ) {
        styleFont = [UIFont fontWithName:fontName size:self.fontSize];
    }

    if ( styleFont ) {
        [myAttributes setValue:styleFont
                        forKey:NSFontAttributeName];
    }

    // Color
    UIColor *styleColor = self.color.uiColor;

    if ( styleColor ) {
        [myAttributes setValue:styleColor
                        forKey:NSForegroundColorAttributeName];
    }

    // Text alignment and line break mode
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment     = (NSTextAlignment)self.textAlignment;
    paragraphStyle.lineBreakMode = self.lineBreakMode;

    [myAttributes setValue:paragraphStyle
                    forKey:NSParagraphStyleAttributeName];

    return [myAttributes copy];
}

/// @endcond

@end

#pragma mark -

@implementation CPTMutableTextStyle(CPTPlatformSpecificMutableTextStyleExtensions)

/** @brief Creates and returns a new CPTMutableTextStyle instance initialized from a dictionary of text attributes.
 *
 *  The text style will be initalized with values associated with the following keys:
 *  - #NSFontAttributeName: Sets the @link CPTMutableTextStyle::fontName fontName @endlink
 *  and @link CPTMutableTextStyle::fontSize fontSize @endlink.
 *  - #NSForegroundColorAttributeName: Sets the @link CPTMutableTextStyle::color color @endlink.
 *  - #NSParagraphStyleAttributeName: Sets the @link CPTMutableTextStyle::textAlignment textAlignment @endlink and @link CPTMutableTextStyle::lineBreakMode lineBreakMode @endlink.
 *
 *  Properties associated with missing keys will be inialized to their default values.
 *
 *  @param attributes A dictionary of standard text attributes.
 *  @return A new CPTMutableTextStyle instance.
 **/
+(nonnull instancetype)textStyleWithAttributes:(nullable CPTDictionary *)attributes
{
    CPTMutableTextStyle *newStyle = [CPTMutableTextStyle textStyle];

    // Font
    UIFont *styleFont = attributes[NSFontAttributeName];

    if ( styleFont ) {
        newStyle.font     = styleFont;
        newStyle.fontName = styleFont.fontName;
        newStyle.fontSize = styleFont.pointSize;
    }

    // Color
    UIColor *styleColor = attributes[NSForegroundColorAttributeName];

    if ( styleColor ) {
        newStyle.color = [CPTColor colorWithCGColor:styleColor.CGColor];
    }

    // Text alignment and line break mode
    NSParagraphStyle *paragraphStyle = attributes[NSParagraphStyleAttributeName];

    if ( paragraphStyle ) {
        newStyle.textAlignment = (CPTTextAlignment)paragraphStyle.alignment;
        newStyle.lineBreakMode = paragraphStyle.lineBreakMode;
    }

    return newStyle;
}

@end

#pragma mark -

@implementation NSString(CPTTextStyleExtensions)

#pragma mark -
#pragma mark Layout

/** @brief Determines the size of text drawn with the given style.
 *  @param style The text style.
 *  @return The size of the text when drawn with the given style.
 **/
-(CGSize)sizeWithTextStyle:(nullable CPTTextStyle *)style
{
    CGRect rect = [self boundingRectWithSize:CPTSizeMake(10000.0, 10000.0)
                                     options:CPTStringDrawingOptions
                                  attributes:style.attributes
                                     context:nil];

    CGSize textSize = rect.size;

    textSize.width  = ceil(textSize.width);
    textSize.height = ceil(textSize.height);

    return textSize;
}

#pragma mark -
#pragma mark Drawing

/** @brief Draws the text into the given graphics context using the given style.
 *  @param rect The bounding rectangle in which to draw the text.
 *  @param style The text style.
 *  @param context The graphics context to draw into.
 **/
-(void)drawInRect:(CGRect)rect withTextStyle:(nullable CPTTextStyle *)style inContext:(nonnull CGContextRef)context
{
    if ( style.color == nil ) {
        return;
    }

    CGContextSaveGState(context);
    CGColorRef textColor = style.color.cgColor;

    CGContextSetStrokeColorWithColor(context, textColor);
    CGContextSetFillColorWithColor(context, textColor);

    CPTPushCGContext(context);

#if TARGET_OS_SIMULATOR || TARGET_OS_TV
    [self drawWithRect:rect
               options:CPTStringDrawingOptions
            attributes:style.attributes
               context:nil];
#else
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    // -drawWithRect:options:attributes:context: method is available in iOS 7.0 and later
    if ( [self respondsToSelector:@selector(drawWithRect:options:attributes:context:)] ) {
        [self drawWithRect:rect
                   options:CPTStringDrawingOptions
                attributes:style.attributes
                   context:nil];
    }
    else {
        UIColor *styleColor = style.attributes[NSForegroundColorAttributeName];
        [styleColor set];

        UIFont *theFont    = style.font;
        NSString *fontName = style.fontName;

        if ((theFont == nil) && fontName ) {
            theFont = [UIFont fontWithName:fontName size:style.fontSize];
        }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self drawInRect:rect
                withFont:theFont
           lineBreakMode:style.lineBreakMode
               alignment:(NSTextAlignment)style.textAlignment];
#pragma clang diagnostic pop
    }
#else
    UIColor *styleColor = style.attributes[NSForegroundColorAttributeName];
    [styleColor set];

    UIFont *theFont = self.font;
    if ( theFont == nil ) {
        theFont = [UIFont fontWithName:style.fontName size:style.fontSize];
    }

    [self drawInRect:rect
            withFont:theFont
       lineBreakMode:style.lineBreakMode
           alignment:(NSTextAlignment)style.textAlignment];
#endif
#endif

    CGContextRestoreGState(context);
    CPTPopCGContext();
}

@end
