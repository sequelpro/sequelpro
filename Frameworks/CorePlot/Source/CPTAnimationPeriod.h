#import "CPTAnimation.h"

@class CPTAnimationOperation;
@class CPTPlotRange;

@interface CPTAnimationPeriod : NSObject

/// @name Timing Values
/// @{
@property (nonatomic, readwrite, copy, nullable) NSValue *startValue;
@property (nonatomic, readwrite, copy, nullable) NSValue *endValue;
@property (nonatomic, readonly, nullable) Class valueClass;
@property (nonatomic, readwrite) CGFloat duration;
@property (nonatomic, readwrite) CGFloat delay;
@property (nonatomic, readonly) CGFloat startOffset;
/// @}

/// @name Factory Methods
/// @{
+(nonnull instancetype)periodWithStart:(CGFloat)aStart end:(CGFloat)anEnd duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartPoint:(CGPoint)aStartPoint endPoint:(CGPoint)anEndPoint duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartSize:(CGSize)aStartSize endSize:(CGSize)anEndSize duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartRect:(CGRect)aStartRect endRect:(CGRect)anEndRect duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartDecimal:(NSDecimal)aStartDecimal endDecimal:(NSDecimal)anEndDecimal duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartNumber:(nullable NSNumber *)aStartNumber endNumber:(nonnull NSNumber *)anEndNumber duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
+(nonnull instancetype)periodWithStartPlotRange:(nonnull CPTPlotRange *)aStartPlotRange endPlotRange:(nonnull CPTPlotRange *)anEndPlotRange duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
/// @}

/// @name Initialization
/// @{
-(nonnull instancetype)initWithStart:(CGFloat)aStart end:(CGFloat)anEnd duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartPoint:(CGPoint)aStartPoint endPoint:(CGPoint)anEndPoint duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartSize:(CGSize)aStartSize endSize:(CGSize)anEndSize duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartRect:(CGRect)aStartRect endRect:(CGRect)anEndRect duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartDecimal:(NSDecimal)aStartDecimal endDecimal:(NSDecimal)anEndDecimal duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartNumber:(nullable NSNumber *)aStartNumber endNumber:(nonnull NSNumber *)anEndNumber duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
-(nonnull instancetype)initWithStartPlotRange:(nonnull CPTPlotRange *)aStartPlotRange endPlotRange:(nonnull CPTPlotRange *)anEndPlotRange duration:(CGFloat)aDuration withDelay:(CGFloat)aDelay;
/// @}

@end

#pragma mark -

/** @category CPTAnimationPeriod(AbstractMethods)
 *  @brief CPTAnimationPeriod abstract methods—must be overridden by subclasses
 **/
@interface CPTAnimationPeriod(AbstractMethods)

/// @name Initialization
/// @{
-(void)setStartValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter;
/// @}

/// @name Interpolation
/// @{
-(nonnull NSValue *)tweenedValueForProgress:(CGFloat)progress;
/// @}

/// @name Comparison
/// @{
-(BOOL)canStartWithValueFromObject:(nonnull id)boundObject propertyGetter:(nonnull SEL)boundGetter;
/// @}

@end

#pragma mark -

@interface CPTAnimation(CPTAnimationPeriodAdditions)

/// @name CGFloat Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property from:(CGFloat)from to:(CGFloat)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property from:(CGFloat)from to:(CGFloat)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property from:(CGFloat)from to:(CGFloat)to duration:(CGFloat)duration;
/// @}

/// @name CGPoint Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPoint:(CGPoint)from toPoint:(CGPoint)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPoint:(CGPoint)from toPoint:(CGPoint)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPoint:(CGPoint)from toPoint:(CGPoint)to duration:(CGFloat)duration;
/// @}

/// @name CGSize Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromSize:(CGSize)from toSize:(CGSize)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromSize:(CGSize)from toSize:(CGSize)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromSize:(CGSize)from toSize:(CGSize)to duration:(CGFloat)duration;
/// @}

/// @name CGRect Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromRect:(CGRect)from toRect:(CGRect)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromRect:(CGRect)from toRect:(CGRect)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromRect:(CGRect)from toRect:(CGRect)to duration:(CGFloat)duration;
/// @}

/// @name NSDecimal Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromDecimal:(NSDecimal)from toDecimal:(NSDecimal)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromDecimal:(NSDecimal)from toDecimal:(NSDecimal)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromDecimal:(NSDecimal)from toDecimal:(NSDecimal)to duration:(CGFloat)duration;
/// @}

/// @name NSNumber Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromNumber:(nullable NSNumber *)from toNumber:(nonnull NSNumber *)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromNumber:(nullable NSNumber *)from toNumber:(nonnull NSNumber *)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromNumber:(nullable NSNumber *)from toNumber:(nonnull NSNumber *)to duration:(CGFloat)duration;
/// @}

/// @name CPTPlotRange Property Animation
/// @{
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPlotRange:(nonnull CPTPlotRange *)from toPlotRange:(nonnull CPTPlotRange *)to duration:(CGFloat)duration withDelay:(CGFloat)delay animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPlotRange:(nonnull CPTPlotRange *)from toPlotRange:(nonnull CPTPlotRange *)to duration:(CGFloat)duration animationCurve:(CPTAnimationCurve)animationCurve delegate:(nullable id<CPTAnimationDelegate>)delegate;
+(nonnull CPTAnimationOperation *)animate:(nonnull id)object property:(nonnull NSString *)property fromPlotRange:(nonnull CPTPlotRange *)from toPlotRange:(nonnull CPTPlotRange *)to duration:(CGFloat)duration;
/// @}

@end
