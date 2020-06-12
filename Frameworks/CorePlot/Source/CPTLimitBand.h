/// @file

@class CPTFill;
@class CPTLimitBand;
@class CPTPlotRange;

/**
 *  @brief An array of limit bands.
 **/
typedef NSArray<CPTLimitBand *> CPTLimitBandArray;

/**
 *  @brief A mutable array of limit bands.
 **/
typedef NSMutableArray<CPTLimitBand *> CPTMutableLimitBandArray;

@interface CPTLimitBand : NSObject<NSCopying, NSCoding, NSSecureCoding>

@property (nonatomic, readwrite, strong, nullable) CPTPlotRange *range;
@property (nonatomic, readwrite, strong, nullable) CPTFill *fill;

/// @name Factory Methods
/// @{
+(nonnull instancetype)limitBandWithRange:(nullable CPTPlotRange *)newRange fill:(nullable CPTFill *)newFill;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithRange:(nullable CPTPlotRange *)newRange fill:(nullable CPTFill *)newFill NS_DESIGNATED_INITIALIZER;
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
/// @}

@end
