#import "CPTMutableNumericData.h"
#import "CPTNumericDataType.h"

/** @category CPTMutableNumericData(TypeConversion)
 *  @brief Type conversion methods for CPTMutableNumericData.
 **/
@interface CPTMutableNumericData(TypeConversion)

/// @name Data Format
/// @{
@property (nonatomic, readwrite, assign) CPTNumericDataType dataType;
@property (nonatomic, readwrite, assign) CPTDataTypeFormat dataTypeFormat;
@property (nonatomic, readwrite, assign) size_t sampleBytes;
@property (nonatomic, readwrite, assign) CFByteOrder byteOrder;
/// @}

/// @name Type Conversion
/// @{
-(void)convertToType:(CPTDataTypeFormat)newDataType sampleBytes:(size_t)newSampleBytes byteOrder:(CFByteOrder)newByteOrder;
/// @}

@end
