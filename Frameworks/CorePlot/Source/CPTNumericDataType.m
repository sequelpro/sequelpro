#import "CPTNumericDataType.h"

#import "complex.h"

static CPTDataTypeFormat DataTypeForDataTypeString(NSString *__nonnull dataTypeString);
static size_t SampleBytesForDataTypeString(NSString *__nonnull dataTypeString);
static CFByteOrder ByteOrderForDataTypeString(NSString *__nonnull dataTypeString);

#pragma mark -
#pragma mark Data type utilities

/** @brief Initializes a CPTNumericDataType struct with the given parameter values.
 *  @param format The data type format.
 *  @param sampleBytes The number of bytes in each sample.
 *  @param byteOrder The byte order used to store the data samples.
 *  @return The initialized CPTNumericDataType struct.
 **/
CPTNumericDataType CPTDataType(CPTDataTypeFormat format, size_t sampleBytes, CFByteOrder byteOrder)
{
    CPTNumericDataType result;

    result.dataTypeFormat = format;
    result.sampleBytes    = sampleBytes;
    result.byteOrder      = byteOrder;

    return result;
}

/** @brief Initializes a CPTNumericDataType struct from a data type string.
 *  @param dataTypeString The data type string.
 *  @return The initialized CPTNumericDataType struct.
 **/
CPTNumericDataType CPTDataTypeWithDataTypeString(NSString *__nonnull dataTypeString)
{
    CPTNumericDataType type;

    type.dataTypeFormat = DataTypeForDataTypeString(dataTypeString);

    type.sampleBytes = SampleBytesForDataTypeString(dataTypeString);
    type.byteOrder   = ByteOrderForDataTypeString(dataTypeString);

    return type;
}

/** @brief Generates a string representation of the given data type.
 *  @param dataType The data type.
 *  @return The string representation of the given data type.
 **/
NSString *CPTDataTypeStringFromDataType(CPTNumericDataType dataType)
{
    NSString *byteOrderString = nil;
    NSString *typeString      = nil;

    switch ( dataType.byteOrder ) {
        case CFByteOrderLittleEndian:
            byteOrderString = @"<";
            break;

        case CFByteOrderBigEndian:
            byteOrderString = @">";
            break;

        default:
            break;
    }

    switch ( dataType.dataTypeFormat ) {
        case CPTFloatingPointDataType:
            typeString = @"f";
            break;

        case CPTIntegerDataType:
            typeString = @"i";
            break;

        case CPTUnsignedIntegerDataType:
            typeString = @"u";
            break;

        case CPTComplexFloatingPointDataType:
            typeString = @"c";
            break;

        case CPTDecimalDataType:
            typeString = @"d";
            break;

        case CPTUndefinedDataType:
            [NSException raise:NSGenericException format:@"Unsupported data type"];
    }

    return [NSString stringWithFormat:@"%@%@%lu",
            byteOrderString,
            typeString,
            dataType.sampleBytes];
}

/** @brief Validates a data type format.
 *  @param format The data type format.
 *  @return Returns @YES if the format is supported by CPTNumericData, @NO otherwise.
 **/
BOOL CPTDataTypeIsSupported(CPTNumericDataType format)
{
    BOOL result = YES;

    switch ( format.byteOrder ) {
        case CFByteOrderUnknown:
        case CFByteOrderLittleEndian:
        case CFByteOrderBigEndian:
            // valid byte order--continue checking
            break;

        default:
            // invalid byte order
            result = NO;
            break;
    }

    if ( result ) {
        BOOL valid = NO;

        switch ( format.dataTypeFormat ) {
            case CPTUndefinedDataType:
                // valid; any sampleBytes is ok
                valid = YES;
                break;

            case CPTIntegerDataType:
                switch ( format.sampleBytes ) {
                    case sizeof(int8_t):
                    case sizeof(int16_t):
                    case sizeof(int32_t):
                    case sizeof(int64_t):
                        valid = YES;
                        break;
                }
                break;

            case CPTUnsignedIntegerDataType:
                switch ( format.sampleBytes ) {
                    case sizeof(uint8_t):
                    case sizeof(uint16_t):
                    case sizeof(uint32_t):
                    case sizeof(uint64_t):
                        valid = YES;
                        break;
                }
                break;

            case CPTFloatingPointDataType:
                switch ( format.sampleBytes ) {
                    case sizeof(float):
                    case sizeof(double):
                        valid = YES;
                        break;
                }
                break;

            case CPTComplexFloatingPointDataType:
                switch ( format.sampleBytes ) {
                    case sizeof(float complex):
                    case sizeof(double complex):
                        // only the native byte order is supported
                        valid = (format.byteOrder == CFByteOrderGetCurrent());
                        break;
                }
                break;

            case CPTDecimalDataType:
                // only the native byte order is supported
                valid = (format.sampleBytes == sizeof(NSDecimal)) && (format.byteOrder == CFByteOrderGetCurrent());
                break;
        }

        result = valid;
    }

    return result;
}

/** @brief Compares two data types for equality.
 *  @param dataType1 The first data type format.
 *  @param dataType2 The second data type format.
 *  @return Returns @YES if the two data types have the same format, size, and byte order.
 **/
BOOL CPTDataTypeEqualToDataType(CPTNumericDataType dataType1, CPTNumericDataType dataType2)
{
    return (dataType1.dataTypeFormat == dataType2.dataTypeFormat) &&
           (dataType1.sampleBytes == dataType2.sampleBytes) &&
           (dataType1.byteOrder == dataType2.byteOrder);
}

#pragma mark -
#pragma mark Private functions

CPTDataTypeFormat DataTypeForDataTypeString(NSString *__nonnull dataTypeString)
{
    CPTDataTypeFormat result = CPTUndefinedDataType;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
    NSCAssert([dataTypeString length] >= 3, @"dataTypeString is too short");
#pragma clang diagnostic pop

    switch ( [dataTypeString.lowercaseString characterAtIndex:1] ) {
        case 'f':
            result = CPTFloatingPointDataType;
            break;

        case 'i':
            result = CPTIntegerDataType;
            break;

        case 'u':
            result = CPTUnsignedIntegerDataType;
            break;

        case 'c':
            result = CPTComplexFloatingPointDataType;
            break;

        case 'd':
            result = CPTDecimalDataType;
            break;

        default:
            [NSException raise:NSGenericException
                        format:@"Unknown type in dataTypeString"];
    }

    return result;
}

size_t SampleBytesForDataTypeString(NSString *__nonnull dataTypeString)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
    NSCAssert([dataTypeString length] >= 3, @"dataTypeString is too short");
    NSInteger result = [dataTypeString substringFromIndex:2].integerValue;
    NSCAssert(result > 0, @"sample bytes is negative.");
#pragma clang diagnostic pop

    return (size_t)result;
}

CFByteOrder ByteOrderForDataTypeString(NSString *__nonnull dataTypeString)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
    NSCAssert([dataTypeString length] >= 3, @"dataTypeString is too short");
#pragma clang diagnostic pop

    CFByteOrder result = CFByteOrderUnknown;

    switch ( [dataTypeString.lowercaseString characterAtIndex:0] ) {
        case '=':
            result = CFByteOrderGetCurrent();
            break;

        case '<':
            result = CFByteOrderLittleEndian;
            break;

        case '>':
            result = CFByteOrderBigEndian;
            break;

        default:
            [NSException raise:NSGenericException
                        format:@"Unknown byte order in dataTypeString"];
    }

    return result;
}
