#import "CPTDefinitions.h"

/// @file

@class CPTPlotRange;

/**
 *  @brief Enumeration of possible results of a plot range comparison.
 **/
typedef NS_CLOSED_ENUM(NSInteger, CPTPlotRangeComparisonResult) {
    CPTPlotRangeComparisonResultNumberBelowRange, ///< Number is below the range.
    CPTPlotRangeComparisonResultNumberInRange,    ///< Number is in the range.
    CPTPlotRangeComparisonResultNumberAboveRange, ///< Number is above the range.
    CPTPlotRangeComparisonResultNumberUndefined   ///< Number is undefined (e.g., @NAN).
};

/**
 *  @brief An array of plot ranges.
 **/
typedef NSArray<CPTPlotRange *> CPTPlotRangeArray;

/**
 *  @brief A mutable array of plot ranges.
 **/
typedef NSMutableArray<CPTPlotRange *> CPTMutablePlotRangeArray;

@interface CPTPlotRange : NSObject<NSCopying, NSMutableCopying, NSCoding, NSSecureCoding>

/// @name Range Limits
/// @{
@property (nonatomic, readonly, strong, nonnull) NSNumber *location;
@property (nonatomic, readonly, strong, nonnull) NSNumber *length;
@property (nonatomic, readonly, strong, nonnull) NSNumber *end;
@property (nonatomic, readonly) NSDecimal locationDecimal;
@property (nonatomic, readonly) NSDecimal lengthDecimal;
@property (nonatomic, readonly) NSDecimal endDecimal;
@property (nonatomic, readonly) double locationDouble;
@property (nonatomic, readonly) double lengthDouble;
@property (nonatomic, readonly) double endDouble;

@property (nonatomic, readonly, strong, nonnull) NSNumber *minLimit;
@property (nonatomic, readonly, strong, nonnull) NSNumber *midPoint;
@property (nonatomic, readonly, strong, nonnull) NSNumber *maxLimit;
@property (nonatomic, readonly) NSDecimal minLimitDecimal;
@property (nonatomic, readonly) NSDecimal midPointDecimal;
@property (nonatomic, readonly) NSDecimal maxLimitDecimal;
@property (nonatomic, readonly) double minLimitDouble;
@property (nonatomic, readonly) double midPointDouble;
@property (nonatomic, readonly) double maxLimitDouble;

@property (nonatomic, readonly) BOOL isInfinite;
@property (nonatomic, readonly) CPTSign lengthSign;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)plotRangeWithLocation:(nonnull NSNumber *)loc length:(nonnull NSNumber *)len;
+(nonnull instancetype)plotRangeWithLocationDecimal:(NSDecimal)loc lengthDecimal:(NSDecimal)len;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithLocation:(nonnull NSNumber *)loc length:(nonnull NSNumber *)len NS_DESIGNATED_INITIALIZER;
-(nonnull instancetype)initWithLocationDecimal:(NSDecimal)loc lengthDecimal:(NSDecimal)len;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

/// @name Checking Ranges
/// @{
-(BOOL)contains:(NSDecimal)number;
-(BOOL)containsDouble:(double)number;
-(BOOL)containsNumber:(nullable NSNumber *)number;
-(BOOL)isEqualToRange:(nullable CPTPlotRange *)otherRange;
-(BOOL)containsRange:(nullable CPTPlotRange *)otherRange;
-(BOOL)intersectsRange:(nullable CPTPlotRange *)otherRange;
/// @}

/// @name Range Comparison
/// @{
-(CPTPlotRangeComparisonResult)compareToNumber:(nonnull NSNumber *)number;
-(CPTPlotRangeComparisonResult)compareToDecimal:(NSDecimal)number;
-(CPTPlotRangeComparisonResult)compareToDouble:(double)number;
/// @}

@end
