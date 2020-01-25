/** @category NSCoder(CPTExtensions)
 *  @brief Core Plot extensions to NSCoder.
 **/
@interface NSCoder(CPTExtensions)

/// @name Encoding Data
/// @{
-(void)encodeCGFloat:(CGFloat)number forKey:(nonnull NSString *)key;
-(void)encodeCPTPoint:(CGPoint)point forKey:(nonnull NSString *)key;
-(void)encodeCPTSize:(CGSize)size forKey:(nonnull NSString *)key;
-(void)encodeCPTRect:(CGRect)rect forKey:(nonnull NSString *)key;

-(void)encodeCGColorSpace:(nullable CGColorSpaceRef)colorSpace forKey:(nonnull NSString *)key;
-(void)encodeCGPath:(nullable CGPathRef)path forKey:(nonnull NSString *)key;
-(void)encodeCGImage:(nullable CGImageRef)image forKey:(nonnull NSString *)key;

-(void)encodeDecimal:(NSDecimal)number forKey:(nonnull NSString *)key;
/// @}

/// @name Decoding Data
/// @{
-(CGFloat)decodeCGFloatForKey:(nonnull NSString *)key;
-(CGPoint)decodeCPTPointForKey:(nonnull NSString *)key;
-(CGSize)decodeCPTSizeForKey:(nonnull NSString *)key;
-(CGRect)decodeCPTRectForKey:(nonnull NSString *)key;

-(nullable CGColorSpaceRef)newCGColorSpaceDecodeForKey:(nonnull NSString *)key;
-(nullable CGPathRef)newCGPathDecodeForKey:(nonnull NSString *)key;
-(nullable CGImageRef)newCGImageDecodeForKey:(nonnull NSString *)key;

-(NSDecimal)decodeDecimalForKey:(nonnull NSString *)key;
/// @}

@end
