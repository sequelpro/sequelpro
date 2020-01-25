/// @file

/**
 *  @brief Enumeration of data formats for numeric data.
 **/
typedef NS_ENUM (NSInteger, CPTDataTypeFormat) {
    CPTUndefinedDataType = 0,        ///< Undefined
    CPTIntegerDataType,              ///< Integer
    CPTUnsignedIntegerDataType,      ///< Unsigned integer
    CPTFloatingPointDataType,        ///< Floating point
    CPTComplexFloatingPointDataType, ///< Complex floating point
    CPTDecimalDataType               ///< NSDecimal
};

/**
 *  @brief Enumeration of memory arrangements for multi-dimensional data arrays.
 *  @see See <a href="http://en.wikipedia.org/wiki/Row-major_order">Wikipedia</a> for more information.
 **/
typedef NS_CLOSED_ENUM(NSInteger, CPTDataOrder) {
    CPTDataOrderRowsFirst,   ///< Numeric data is arranged in row-major order.
    CPTDataOrderColumnsFirst ///< Numeric data is arranged in column-major order.
};

/**
 *  @brief Structure that describes the encoding of numeric data samples.
 **/
typedef struct _CPTNumericDataType {
    CPTDataTypeFormat dataTypeFormat; ///< Data type format
    size_t            sampleBytes;    ///< Number of bytes in each sample
    CFByteOrder       byteOrder;      ///< Byte order
}
CPTNumericDataType;

#if __cplusplus
extern "C" {
#endif

/// @name Data Type Utilities
/// @{
CPTNumericDataType CPTDataType(CPTDataTypeFormat format, size_t sampleBytes, CFByteOrder byteOrder);
CPTNumericDataType CPTDataTypeWithDataTypeString(NSString *__nonnull dataTypeString);
NSString *__nonnull CPTDataTypeStringFromDataType(CPTNumericDataType dataType);
BOOL CPTDataTypeIsSupported(CPTNumericDataType format);
BOOL CPTDataTypeEqualToDataType(CPTNumericDataType dataType1, CPTNumericDataType dataType2);

/// @}

#if __cplusplus
}
#endif
