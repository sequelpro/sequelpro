#import "CPTTextLayer.h"

#import "CPTPlatformSpecificCategories.h"
#import "CPTShadow.h"
#import "CPTTextStylePlatformSpecific.h"
#import "CPTUtilities.h"
#import <tgmath.h>

const CGFloat kCPTTextLayerMarginWidth = CPTFloat(2.0);

/// @cond
@interface CPTTextLayer()

@property (nonatomic, readwrite, assign) BOOL inTextUpdate;

@end

/// @endcond

#pragma mark -

/**
 *  @brief A Core Animation layer that displays text drawn in a uniform style.
 **/
@implementation CPTTextLayer

/** @property nullable NSString *text
 *  @brief The text to display.
 *
 *  Assigning a new value to this property also sets the value of the @ref attributedText property to @nil.
 *  Insert newline characters (<code>'\\n'</code>) at the line breaks to display multi-line text.
 **/
@synthesize text;

/** @property nullable CPTTextStyle *textStyle
 *  @brief The text style used to draw the text.
 *
 *  Assigning a new value to this property also sets the value of the @ref attributedText property to @nil.
 **/
@synthesize textStyle;

/** @property nullable NSAttributedString *attributedText
 *  @brief The styled text to display.
 *
 *  Assigning a new value to this property also sets the value of the @ref text property to the
 *  same string, without formatting information. It also replaces the @ref textStyle with
 *  a style matching the first position (location @num{0}) of the styled text.
 *  Insert newline characters (<code>'\\n'</code>) at the line breaks to display multi-line text.
 **/
@synthesize attributedText;

/** @property CGSize maximumSize
 *  @brief The maximum size of the layer. The default is {@num{0.0}, @num{0.0}}.
 *
 *  A text layer will size itself to fit its text drawn with its text style unless it exceeds this size.
 *  If the @par{width} and/or @par{height} of this size is less than or equal to zero (@num{0.0}),
 *  no size limit will be enforced in the corresponding dimension. The maximum layer size includes
 *  any padding applied to the layer.
 **/
@synthesize maximumSize;

@synthesize inTextUpdate;

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated CPTTextLayer object with the provided text and style. This is the designated initializer.
 *  @param newText The text to display.
 *  @param newStyle The text style used to draw the text.
 *  @return The initialized CPTTextLayer object.
 **/
-(nonnull instancetype)initWithText:(nullable NSString *)newText style:(nullable CPTTextStyle *)newStyle
{
    if ((self = [super initWithFrame:CGRectZero])) {
        textStyle      = newStyle;
        text           = [newText copy];
        attributedText = nil;
        maximumSize    = CGSizeZero;
        inTextUpdate   = NO;

        self.needsDisplayOnBoundsChange = NO;
        [self sizeToFit];
    }

    return self;
}

/** @brief Initializes a newly allocated CPTTextLayer object with the provided text and the default text style.
 *  @param newText The text to display.
 *  @return The initialized CPTTextLayer object.
 **/
-(nonnull instancetype)initWithText:(nullable NSString *)newText
{
    return [self initWithText:newText style:[CPTTextStyle textStyle]];
}

/** @brief Initializes a newly allocated CPTTextLayer object with the provided styled text.
 *  @param newText The styled text to display.
 *  @return The initialized CPTTextLayer object.
 **/
-(nonnull instancetype)initWithAttributedText:(nullable NSAttributedString *)newText
{
    CPTTextStyle *newStyle = [CPTTextStyle textStyleWithAttributes:[newText attributesAtIndex:0 effectiveRange:NULL]];

    if ((self = [self initWithText:newText.string style:newStyle])) {
        attributedText = [newText copy];

        [self sizeToFit];
    }

    return self;
}

/// @cond

-(nonnull instancetype)initWithLayer:(nonnull id)layer
{
    if ((self = [super initWithLayer:layer])) {
        CPTTextLayer *theLayer = (CPTTextLayer *)layer;

        textStyle      = theLayer->textStyle;
        text           = theLayer->text;
        attributedText = theLayer->attributedText;
        inTextUpdate   = theLayer->inTextUpdate;
    }
    return self;
}

/// @endcond

/// @name Initialization
/// @{

/** @brief Initializes a newly allocated CPTTextLayer object with the provided frame rectangle.
 *
 *  The initialized layer will have the following properties:
 *  - @ref text = @nil
 *  - @ref textStyle = @nil
 *  - @ref attributedText = @nil
 *
 *  @param newFrame The frame rectangle.
 *  @return The initialized CPTTextLayer object.
 **/
-(nonnull instancetype)initWithFrame:(CGRect __unused)newFrame
{
    return [self initWithText:nil style:nil];
}

/// @}

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.textStyle forKey:@"CPTTextLayer.textStyle"];
    [coder encodeObject:self.text forKey:@"CPTTextLayer.text"];
    [coder encodeObject:self.attributedText forKey:@"CPTTextLayer.attributedText"];

    // No need to archive these properties:
    // inTextUpdate
}

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        textStyle = [coder decodeObjectOfClass:[CPTTextStyle class]
                                        forKey:@"CPTTextLayer.textStyle"];
        text = [[coder decodeObjectOfClass:[NSString class]
                                    forKey:@"CPTTextLayer.text"] copy];
        attributedText = [[coder decodeObjectOfClass:[NSAttributedString class]
                                              forKey:@"CPTTextLayer.attributedText"] copy];

        inTextUpdate = NO;
    }
    return self;
}

/// @endcond

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setText:(nullable NSString *)newValue
{
    if ( text != newValue ) {
        text = [newValue copy];

        if ( !self.inTextUpdate ) {
            self.inTextUpdate   = YES;
            self.attributedText = nil;
            self.inTextUpdate   = NO;

            [self sizeToFit];
        }
    }
}

-(void)setTextStyle:(nullable CPTTextStyle *)newStyle
{
    if ( textStyle != newStyle ) {
        textStyle = newStyle;

        if ( !self.inTextUpdate ) {
            self.inTextUpdate   = YES;
            self.attributedText = nil;
            self.inTextUpdate   = NO;

            [self sizeToFit];
        }
    }
}

-(void)setAttributedText:(nullable NSAttributedString *)newValue
{
    if ( attributedText != newValue ) {
        attributedText = [newValue copy];

        if ( !self.inTextUpdate ) {
            self.inTextUpdate = YES;

            if ( newValue.length > 0 ) {
                self.textStyle = [CPTTextStyle textStyleWithAttributes:[newValue attributesAtIndex:0
                                                                                    effectiveRange:NULL]];
                self.text = newValue.string;
            }
            else {
                self.textStyle = nil;
                self.text      = nil;
            }

            self.inTextUpdate = NO;
            [self sizeToFit];
        }
    }
}

-(void)setMaximumSize:(CGSize)newSize
{
    if ( !CGSizeEqualToSize(maximumSize, newSize)) {
        maximumSize = newSize;
        [self sizeToFit];
    }
}

-(void)setShadow:(nullable CPTShadow *)newShadow
{
    if ( newShadow != self.shadow ) {
        super.shadow = newShadow;
        [self sizeToFit];
    }
}

-(void)setPaddingLeft:(CGFloat)newPadding
{
    if ( newPadding != self.paddingLeft ) {
        super.paddingLeft = newPadding;
        [self sizeToFit];
    }
}

-(void)setPaddingRight:(CGFloat)newPadding
{
    if ( newPadding != self.paddingRight ) {
        super.paddingRight = newPadding;
        [self sizeToFit];
    }
}

-(void)setPaddingTop:(CGFloat)newPadding
{
    if ( newPadding != self.paddingTop ) {
        super.paddingTop = newPadding;
        [self sizeToFit];
    }
}

-(void)setPaddingBottom:(CGFloat)newPadding
{
    if ( newPadding != self.paddingBottom ) {
        super.paddingBottom = newPadding;
        [self sizeToFit];
    }
}

/// @endcond

#pragma mark -
#pragma mark Layout

/**
 *  @brief Determine the minimum size needed to fit the text
 **/
-(CGSize)sizeThatFits
{
    CGSize textSize  = CGSizeZero;
    NSString *myText = self.text;

    if ( myText.length > 0 ) {
        NSAttributedString *styledText = self.attributedText;
        if ( styledText.length > 0 ) {
            textSize = [styledText sizeAsDrawn];
        }
        else {
            textSize = [myText sizeWithTextStyle:self.textStyle];
        }

        // Add small margin
        textSize.width += kCPTTextLayerMarginWidth * CPTFloat(2.0);
        textSize.width  = ceil(textSize.width);

        textSize.height += kCPTTextLayerMarginWidth * CPTFloat(2.0);
        textSize.height  = ceil(textSize.height);
    }

    return textSize;
}

/**
 *  @brief Resizes the layer to fit its contents leaving a narrow margin on all four sides.
 **/
-(void)sizeToFit
{
    if ( self.text.length > 0 ) {
        CGSize sizeThatFits = [self sizeThatFits];
        CGRect newBounds    = self.bounds;
        newBounds.size         = sizeThatFits;
        newBounds.size.width  += self.paddingLeft + self.paddingRight;
        newBounds.size.height += self.paddingTop + self.paddingBottom;

        CGSize myMaxSize = self.maximumSize;
        if ( myMaxSize.width > CPTFloat(0.0)) {
            newBounds.size.width = MIN(newBounds.size.width, myMaxSize.width);
        }
        if ( myMaxSize.height > CPTFloat(0.0)) {
            newBounds.size.height = MIN(newBounds.size.height, myMaxSize.height);
        }

        newBounds.size.width  = ceil(newBounds.size.width);
        newBounds.size.height = ceil(newBounds.size.height);

        self.bounds = newBounds;
        [self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

#pragma mark -
#pragma mark Drawing of text

/// @cond

-(void)renderAsVectorInContext:(nonnull CGContextRef)context
{
    if ( self.hidden ) {
        return;
    }

    NSString *myText = self.text;
    if ( myText.length > 0 ) {
        [super renderAsVectorInContext:context];

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, CPTFloat(0.0), self.bounds.size.height);
        CGContextScaleCTM(context, CPTFloat(1.0), CPTFloat(-1.0));
#endif

        CGRect newBounds = CGRectInset(self.bounds, kCPTTextLayerMarginWidth, kCPTTextLayerMarginWidth);
        newBounds.origin.x += self.paddingLeft;
#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        newBounds.origin.y += self.paddingTop;
#else
        newBounds.origin.y += self.paddingBottom;
#endif
        newBounds.size.width  -= self.paddingLeft + self.paddingRight;
        newBounds.size.height -= self.paddingTop + self.paddingBottom;

        NSAttributedString *styledText = self.attributedText;
        if ((styledText.length > 0) && [styledText respondsToSelector:@selector(drawInRect:)] ) {
            [styledText drawInRect:newBounds
                         inContext:context];
        }
        else {
            [myText drawInRect:newBounds
                 withTextStyle:self.textStyle
                     inContext:context];
        }

#if TARGET_OS_SIMULATOR || TARGET_OS_IPHONE
        CGContextRestoreGState(context);
#endif
    }
}

/// @endcond

#pragma mark -
#pragma mark Description

/// @cond

-(nullable NSString *)description
{
    return [NSString stringWithFormat:@"<%@ \"%@\">", super.description, self.text];
}

/// @endcond

@end
