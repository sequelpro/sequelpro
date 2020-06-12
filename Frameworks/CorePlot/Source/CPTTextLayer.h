#import "CPTBorderedLayer.h"
#import "CPTTextStyle.h"

/// @file

extern const CGFloat kCPTTextLayerMarginWidth; ///< Margin width around the text.

@interface CPTTextLayer : CPTBorderedLayer

@property (readwrite, copy, nonatomic, nullable) NSString *text;
@property (readwrite, strong, nonatomic, nullable) CPTTextStyle *textStyle;
@property (readwrite, copy, nonatomic, nullable) NSAttributedString *attributedText;
@property (readwrite, nonatomic) CGSize maximumSize;

/// @name Initialization
/// @{
-(nonnull instancetype)initWithText:(nullable NSString *)newText;
-(nonnull instancetype)initWithText:(nullable NSString *)newText style:(nullable CPTTextStyle *)newStyle NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithAttributedText:(nullable NSAttributedString *)newText;

-(nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithLayer:(nonnull id)layer NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Layout
/// @{
-(CGSize)sizeThatFits;
-(void)sizeToFit;
/// @}

@end
