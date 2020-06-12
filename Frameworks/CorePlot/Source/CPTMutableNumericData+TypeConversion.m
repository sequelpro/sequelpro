#import "CPTMutableNumericData+TypeConversion.h"

#import "CPTNumericData+TypeConversion.h"

@implementation CPTMutableNumericData(TypeConversion)

/** @property CPTNumericDataType dataType
 *  @brief The type of data stored in the data buffer.
 **/
@dynamic dataType;

/** @property CPTDataTypeFormat dataTypeFormat
 *  @brief The format of the data stored in the data buffer.
 **/
@dynamic dataTypeFormat;

/** @property size_t sampleBytes
 *  @brief The number of bytes in a single sample of data.
 **/
@dynamic sampleBytes;

/** @property CFByteOrder byteOrder
 *  @brief The byte order used to store each sample in the data buffer.
 **/
@dynamic byteOrder;

/** @brief Converts the current numeric data to a new data type.
 *  @param newDataType The new data type format.
 *  @param newSampleBytes The number of bytes used to store each sample.
 *  @param newByteOrder The new byte order.
 *  @return A copy of the current numeric data converted to the new data type.
 **/
-(void)convertToType:(CPTDataTypeFormat)newDataType
         sampleBytes:(size_t)newSampleBytes
           byteOrder:(CFByteOrder)newByteOrder
{
    self.dataType = CPTDataType(newDataType, newSampleBytes, newByteOrder);
}

#pragma mark -
#pragma mark Accessors

/// @cond

-(void)setDataTypeFormat:(CPTDataTypeFormat)newDataTypeFormat
{
    CPTNumericDataType myDataType = self.dataType;

    if ( newDataTypeFormat != myDataType.dataTypeFormat ) {
        self.dataType = CPTDataType(newDataTypeFormat, myDataType.sampleBytes, myDataType.byteOrder);
    }
}

-(void)setSampleBytes:(size_t)newSampleBytes
{
    CPTNumericDataType myDataType = self.dataType;

    if ( newSampleBytes != myDataType.sampleBytes ) {
        self.dataType = CPTDataType(myDataType.dataTypeFormat, newSampleBytes, myDataType.byteOrder);
    }
}

-(void)setByteOrder:(CFByteOrder)newByteOrder
{
    CPTNumericDataType myDataType = self.dataType;

    if ( newByteOrder != myDataType.byteOrder ) {
        self.dataType = CPTDataType(myDataType.dataTypeFormat, myDataType.sampleBytes, newByteOrder);
    }
}

/// @endcond

@end
