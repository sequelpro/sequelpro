#import "CPTDefinitions.h"

/// @file

@class CPTAxisLabel;
@class CPTLayer;
@class CPTTextStyle;

/**
 *  @brief A set of CPTAxisLabel objects.
 **/
typedef NSSet<CPTAxisLabel *> CPTAxisLabelSet;

/**
 *  @brief A mutable set of CPTAxisLabel objects.
 **/
typedef NSMutableSet<CPTAxisLabel *> CPTMutableAxisLabelSet;

@interface CPTAxisLabel : NSObject<NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, strong, nullable) CPTLayer *contentLayer;
@property (nonatomic, readwrite, assign) CGFloat offset;
@property (nonatomic, readwrite, assign) CGFloat rotation;
@property (nonatomic, readwrite, assign) CPTAlignment alignment;
@property (nonatomic, readwrite, strong, nonnull) NSNumber *tickLocation;

/// @name Initialization
/// @{
-(nonnull instancetype)initWithText:(nullable NSString *)newText textStyle:(nullable CPTTextStyle *)style;
-(nonnull instancetype)initWithContentLayer:(nonnull CPTLayer *)layer NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Layout
/// @{
-(void)positionRelativeToViewPoint:(CGPoint)point forCoordinate:(CPTCoordinate)coordinate inDirection:(CPTSign)direction;
-(void)positionBetweenViewPoint:(CGPoint)firstPoint andViewPoint:(CGPoint)secondPoint forCoordinate:(CPTCoordinate)coordinate inDirection:(CPTSign)direction;
/// @}

@end
