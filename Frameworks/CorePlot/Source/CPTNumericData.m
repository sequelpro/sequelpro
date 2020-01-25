#import "CPTNumericData.h"

#import "complex.h"
#import "CPTExceptions.h"
#import "CPTMutableNumericData.h"
#import "CPTNumericData+TypeConversion.h"
#import "CPTUtilities.h"

/// @cond
@interface CPTNumericData()

@property (nonatomic, readwrite, copy, nonnull) NSData *data;
@property (nonatomic, readwrite, assign) CPTNumericDataType dataType;
@property (nonatomic, readwrite, copy, nonnull) CPTNumberArray *shape;
@property (nonatomic, readwrite, assign) CPTDataOrder dataOrder;

-(void)commonInitWithData:(nonnull NSData *)newData dataType:(CPTNumericDataType)newDataType shape:(nullable CPTNumberArray *)shapeArray dataOrder:(CPTDataOrder)order;
-(NSUInteger)sampleIndex:(NSUInteger)idx indexList:(va_list)indexList;
-(nonnull NSData *)dataFromArray:(nonnull CPTNumberArray *)newData dataType:(CPTNumericDataType)newDataType;

@end

/// @endcond

#pragma mark -

/** @brief An annotated NSData type.
 *
 *  CPTNumericData combines a data buffer with information
 *  about the data (shape, data type, size, etc.).
 *  The data is assumed to be an array of one or more dimensions
 *  of a single type of numeric data. Each numeric value in the array,
 *  which can be more than one byte in size, is referred to as a @quote{sample}.
 *  The structure of this object is similar to the NumPy <code>ndarray</code>
 *  object.
 *
 *  The supported data types are:
 *  - 1, 2, 4, and 8-byte signed integers
 *  - 1, 2, 4, and 8-byte unsigned integers
 *  - @float and @double floating point numbers
 *  - @fcomplex and @dcomplex floating point complex numbers
 *  - @ref NSDecimal base-10 numbers
 *
 *  All integer and floating point types can be represented using big endian or little endian
 *  byte order. Complex and decimal types support only the the host system&rsquo;s native byte order.
 **/
@implementation CPTNumericData

/** @property nonnull NSData *data
 *  @brief The data buffer.
 **/
@synthesize data;

/** @property nonnull const void *bytes
 *  @brief Returns a pointer to the data buffer’s contents.
 **/
@dynamic bytes;

/** @property NSUInteger length
 *  @brief Returns the number of bytes contained in the data buffer.
 **/
@dynamic length;

/** @property CPTNumericDataType dataType
 *  @brief The type of data stored in the data buffer.
 **/
@synthesize dataType;

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

/** @property nonnull CPTNumberArray *shape
 *  @brief The shape of the data buffer array.
 *
 *  The shape describes the dimensions of the sample array stored in
 *  the data buffer. Each entry in the shape array represents the
 *  size of the corresponding array dimension and should be an unsigned
 *  integer encoded in an instance of NSNumber.
 **/
@synthesize shape;

/** @property NSUInteger numberOfDimensions
 *  @brief The number dimensions in the data buffer array.
 **/
@dynamic numberOfDimensions;

/** @property NSUInteger numberOfSamples
 *  @brief The number of samples of dataType stored in the data buffer.
 **/
@dynamic numberOfSamples;

/** @property CPTDataOrder dataOrder
 *  @brief The order that numbers are stored in a multi-dimensional data array.
 **/
@synthesize dataOrder;

#pragma mark -
#pragma mark Factory Methods

/** @brief Creates and returns a new CPTNumericData instance.
 *  @param newData The data buffer.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithData:(nonnull NSData *)newData
                                  dataType:(CPTNumericDataType)newDataType
                                     shape:(nullable CPTNumberArray *)shapeArray
{
    return [[self alloc] initWithData:newData
                             dataType:newDataType
                                shape:shapeArray];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *  @param newData The data buffer.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithData:(nonnull NSData *)newData
                            dataTypeString:(nonnull NSString *)newDataTypeString
                                     shape:(nullable CPTNumberArray *)shapeArray
{
    return [[self alloc] initWithData:newData
                             dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                                shape:shapeArray];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to @par{newDataType} and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithArray:(nonnull CPTNumberArray *)newData
                                   dataType:(CPTNumericDataType)newDataType
                                      shape:(nullable CPTNumberArray *)shapeArray
{
    return [[self alloc] initWithArray:newData
                              dataType:newDataType
                                 shape:shapeArray];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to newDataTypeString and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithArray:(nonnull CPTNumberArray *)newData
                             dataTypeString:(nonnull NSString *)newDataTypeString
                                      shape:(nullable CPTNumberArray *)shapeArray
{
    return [[self alloc] initWithArray:newData
                              dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                                 shape:shapeArray];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *  @param newData The data buffer.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithData:(nonnull NSData *)newData
                                  dataType:(CPTNumericDataType)newDataType
                                     shape:(nullable CPTNumberArray *)shapeArray
                                 dataOrder:(CPTDataOrder)order
{
    return [[self alloc] initWithData:newData
                             dataType:newDataType
                                shape:shapeArray
                            dataOrder:order];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *  @param newData The data buffer.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithData:(nonnull NSData *)newData
                            dataTypeString:(nonnull NSString *)newDataTypeString
                                     shape:(nullable CPTNumberArray *)shapeArray
                                 dataOrder:(CPTDataOrder)order
{
    return [[self alloc] initWithData:newData
                             dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                                shape:shapeArray
                            dataOrder:order];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to @par{newDataType} and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithArray:(nonnull CPTNumberArray *)newData
                                   dataType:(CPTNumericDataType)newDataType
                                      shape:(nullable CPTNumberArray *)shapeArray
                                  dataOrder:(CPTDataOrder)order
{
    return [[self alloc] initWithArray:newData
                              dataType:newDataType
                                 shape:shapeArray
                             dataOrder:order];
}

/** @brief Creates and returns a new CPTNumericData instance.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to newDataTypeString and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return A new CPTNumericData instance.
 **/
+(nonnull instancetype)numericDataWithArray:(nonnull CPTNumberArray *)newData
                             dataTypeString:(nonnull NSString *)newDataTypeString
                                      shape:(nullable CPTNumberArray *)shapeArray
                                  dataOrder:(CPTDataOrder)order
{
    return [[self alloc] initWithArray:newData
                              dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                                 shape:shapeArray
                             dataOrder:order];
}

#pragma mark -
#pragma mark Init/Dealloc

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *  @param newData The data buffer.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithData:(nonnull NSData *)newData
                           dataType:(CPTNumericDataType)newDataType
                              shape:(nullable CPTNumberArray *)shapeArray
{
    return [self initWithData:newData
                     dataType:newDataType
                        shape:shapeArray
                    dataOrder:CPTDataOrderRowsFirst];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *  @param newData The data buffer.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithData:(nonnull NSData *)newData
                     dataTypeString:(nonnull NSString *)newDataTypeString
                              shape:(nullable CPTNumberArray *)shapeArray
{
    return [self initWithData:newData
                     dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                        shape:shapeArray];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to @par{newDataType} and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithArray:(nonnull CPTNumberArray *)newData
                            dataType:(CPTNumericDataType)newDataType
                               shape:(nullable CPTNumberArray *)shapeArray
{
    return [self initWithData:[self dataFromArray:newData dataType:newDataType]
                     dataType:newDataType
                        shape:shapeArray];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to newDataTypeString and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array. Multi-dimensional data arrays will be assumed to be stored in #CPTDataOrderRowsFirst.
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithArray:(nonnull CPTNumberArray *)newData
                      dataTypeString:(nonnull NSString *)newDataTypeString
                               shape:(nullable CPTNumberArray *)shapeArray
{
    return [self initWithArray:newData
                      dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                         shape:shapeArray];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data. This is the designated initializer.
 *  @param newData The data buffer.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithData:(nonnull NSData *)newData
                           dataType:(CPTNumericDataType)newDataType
                              shape:(nullable CPTNumberArray *)shapeArray
                          dataOrder:(CPTDataOrder)order
{
    if ((self = [super init])) {
        [self commonInitWithData:newData
                        dataType:newDataType
                           shape:shapeArray
                       dataOrder:order];
    }

    return self;
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *  @param newData The data buffer.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithData:(nonnull NSData *)newData
                     dataTypeString:(nonnull NSString *)newDataTypeString
                              shape:(nullable CPTNumberArray *)shapeArray
                          dataOrder:(CPTDataOrder)order
{
    return [self initWithData:newData
                     dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                        shape:shapeArray
                    dataOrder:order];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to @par{newDataType} and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataType The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithArray:(nonnull CPTNumberArray *)newData
                            dataType:(CPTNumericDataType)newDataType
                               shape:(nullable CPTNumberArray *)shapeArray
                           dataOrder:(CPTDataOrder)order
{
    return [self initWithData:[self dataFromArray:newData dataType:newDataType]
                     dataType:newDataType
                        shape:shapeArray
                    dataOrder:order];
}

/** @brief Initializes a newly allocated CPTNumericData object with the provided data.
 *
 *  Objects in newData should be instances of NSNumber, NSDecimalNumber, NSString, or NSNull.
 *  Numbers and strings will be converted to newDataTypeString and stored in the receiver.
 *  Any instances of NSNull will be treated as @quote{not a number} (@NAN) values for floating point types and zero (@num{0}) for integer types.
 *  @param newData An array of numbers.
 *  @param newDataTypeString The type of data stored in the buffer.
 *  @param shapeArray The shape of the data buffer array.
 *  @param order The data order for a multi-dimensional data array (row-major or column-major).
 *  @return The initialized CPTNumericData instance.
 **/
-(nonnull instancetype)initWithArray:(nonnull CPTNumberArray *)newData
                      dataTypeString:(nonnull NSString *)newDataTypeString
                               shape:(nullable CPTNumberArray *)shapeArray
                           dataOrder:(CPTDataOrder)order
{
    return [self initWithArray:newData
                      dataType:CPTDataTypeWithDataTypeString(newDataTypeString)
                         shape:shapeArray
                     dataOrder:order];
}

/// @cond

-(nonnull instancetype)init
{
    return [self initWithData:[NSData data]
                     dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), CFByteOrderGetCurrent())
                        shape:nil];
}

-(void)commonInitWithData:(nonnull NSData *)newData
                 dataType:(CPTNumericDataType)newDataType
                    shape:(nullable CPTNumberArray *)shapeArray
                dataOrder:(CPTDataOrder)order
{
    NSParameterAssert(CPTDataTypeIsSupported(newDataType));

    self.data      = newData;
    self.dataType  = newDataType;
    self.dataOrder = order;

    CPTNumberArray *theShape = shapeArray;

    if ( theShape == nil ) {
        self.shape = @[@(self.numberOfSamples)];
    }
    else {
        NSUInteger prod = 1;
        for ( NSNumber *cNum in theShape ) {
            prod *= cNum.unsignedIntegerValue;
        }

        if ( prod != self.numberOfSamples ) {
            [NSException raise:CPTNumericDataException
                        format:@"Shape product (%lu) does not match data size (%lu)", (unsigned long)prod, (unsigned long)self.numberOfSamples];
        }

        self.shape = theShape;
    }
}

/// @endcond

#pragma mark -
#pragma mark Accessors

/// @cond

-(NSUInteger)numberOfDimensions
{
    return self.shape.count;
}

-(nonnull const void *)bytes
{
    return self.data.bytes;
}

-(NSUInteger)length
{
    return self.data.length;
}

-(NSUInteger)numberOfSamples
{
    return self.length / self.dataType.sampleBytes;
}

-(CPTDataTypeFormat)dataTypeFormat
{
    return self.dataType.dataTypeFormat;
}

-(size_t)sampleBytes
{
    return self.dataType.sampleBytes;
}

-(CFByteOrder)byteOrder
{
    return self.dataType.byteOrder;
}

-(void)setData:(nonnull NSData *)newData
{
    if ( data != newData ) {
        if ( [self isKindOfClass:[CPTMutableNumericData class]] ) {
            data = [newData mutableCopy];
        }
        else {
            data = [newData copy];
        }
    }
}

-(void)setDataType:(CPTNumericDataType)newDataType
{
    CPTNumericDataType oldDataType = dataType;

    if ( CPTDataTypeEqualToDataType(oldDataType, newDataType)) {
        return;
    }

    NSParameterAssert(CPTDataTypeIsSupported(newDataType));
    NSParameterAssert(newDataType.dataTypeFormat != CPTUndefinedDataType);
    NSParameterAssert(newDataType.byteOrder != CFByteOrderUnknown);

    dataType = newDataType;

    if ((oldDataType.sampleBytes == sizeof(int8_t)) && (newDataType.sampleBytes == sizeof(int8_t))) {
        return;
    }

    if ((oldDataType.dataTypeFormat != CPTUndefinedDataType) && (oldDataType.byteOrder != CFByteOrderUnknown)) {
        NSMutableData *myData     = (NSMutableData *)self.data;
        CFByteOrder hostByteOrder = CFByteOrderGetCurrent();

        NSUInteger sampleCount = myData.length / oldDataType.sampleBytes;

        if ( oldDataType.byteOrder != hostByteOrder ) {
            [self swapByteOrderForData:myData sampleSize:oldDataType.sampleBytes];
        }

        if ( newDataType.sampleBytes > oldDataType.sampleBytes ) {
            NSData *oldData = [myData copy];
            myData.length = sampleCount * newDataType.sampleBytes;
            [self convertData:oldData dataType:&oldDataType toData:myData dataType:&newDataType];
        }
        else {
            [self convertData:myData dataType:&oldDataType toData:myData dataType:&newDataType];
            myData.length = sampleCount * newDataType.sampleBytes;
        }

        if ( newDataType.byteOrder != hostByteOrder ) {
            [self swapByteOrderForData:myData sampleSize:newDataType.sampleBytes];
        }
    }
}

-(void)setShape:(nonnull CPTNumberArray *)newShape
{
    if ( newShape != shape ) {
        shape = [newShape copy];

        NSMutableData *myData = (NSMutableData *)self.data;

        if ( [myData isKindOfClass:[NSMutableData class]] ) {
            NSUInteger sampleCount = 1;
            for ( NSNumber *num in shape ) {
                sampleCount *= num.unsignedIntegerValue;
            }

            myData.length = sampleCount * self.sampleBytes;
        }
    }
}

/// @endcond

#pragma mark -
#pragma mark Samples

/** @brief Gets the offset of a given sample in the data buffer.
 *  @param idx The zero-based indices into a multi-dimensional sample array. Each index should of type @ref NSUInteger and the number of indices
 *  (including @par{idx}) should match the @ref numberOfDimensions.
 *  @return The sample offset in the data buffer. To get the byte offset, multiply this value by
 *  @ref sampleBytes. If any index is greater than or equal to the corresponding
 *  dimension of the data buffer, this method returns @ref NSNotFound.
 **/
-(NSUInteger)sampleIndex:(NSUInteger)idx, ...
{
    va_list indices;

    va_start(indices, idx);

    NSUInteger newIndex = [self sampleIndex:idx indexList:indices];

    va_end(indices);

    return newIndex;
}

/** @brief Gets the value of a given sample in the data buffer.
 *  @param sample The zero-based index into the sample array. The array is treated as if it only has one dimension.
 *  @return The sample value wrapped in an instance of NSNumber or @nil if the sample index is out of bounds.
 *
 *  @note NSNumber does not support complex numbers. Complex number types will be cast to
 *  @float or @double before being wrapped in an instance of NSNumber.
 **/
-(NSNumber *)sampleValue:(NSUInteger)sample
{
    NSNumber *result = nil;

    if ( sample < self.numberOfSamples ) {
        // Code generated with "CPTNumericData+TypeConversions_Generation.py"
        // ========================================================================

        switch ( self.dataTypeFormat ) {
            case CPTUndefinedDataType:
                [NSException raise:NSInvalidArgumentException format:@"Unsupported data type (CPTUndefinedDataType)"];
                break;

            case CPTIntegerDataType:
                switch ( self.sampleBytes ) {
                    case sizeof(int8_t):
                        result = @(*(const int8_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(int16_t):
                        result = @(*(const int16_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(int32_t):
                        result = @(*(const int32_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(int64_t):
                        result = @(*(const int64_t *)[self samplePointer:sample]);
                        break;
                }
                break;

            case CPTUnsignedIntegerDataType:
                switch ( self.sampleBytes ) {
                    case sizeof(uint8_t):
                        result = @(*(const uint8_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(uint16_t):
                        result = @(*(const uint16_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(uint32_t):
                        result = @(*(const uint32_t *)[self samplePointer:sample]);
                        break;

                    case sizeof(uint64_t):
                        result = @(*(const uint64_t *)[self samplePointer:sample]);
                        break;
                }
                break;

            case CPTFloatingPointDataType:
                switch ( self.sampleBytes ) {
                    case sizeof(float):
                        result = @(*(const float *)[self samplePointer:sample]);
                        break;

                    case sizeof(double):
                        result = @(*(const double *)[self samplePointer:sample]);
                        break;
                }
                break;

            case CPTComplexFloatingPointDataType:
                switch ( self.sampleBytes ) {
                    case sizeof(float complex):
                        result = @(crealf(*(const float complex *)[self samplePointer:sample]));
                        break;

                    case sizeof(double complex):
                        result = @(creal(*(const double complex *)[self samplePointer:sample]));
                        break;
                }
                break;

            case CPTDecimalDataType:
                switch ( self.sampleBytes ) {
                    case sizeof(NSDecimal):
                        result = [NSDecimalNumber decimalNumberWithDecimal:*(const NSDecimal *)[self samplePointer:sample]];
                        break;
                }
                break;
        }

        // End of code generated with "CPTNumericData+TypeConversions_Generation.py"
        // ========================================================================
    }

    return result;
}

/** @brief Gets the value of a given sample in the data buffer.
 *  @param idx The zero-based indices into a multi-dimensional sample array. Each index should of type @ref NSUInteger and the number of indices
 *  (including @par{idx}) should match the @ref numberOfDimensions.
 *  @return The sample value wrapped in an instance of NSNumber or @nil if any of the sample indices are out of bounds.
 *
 *  @note NSNumber does not support complex numbers. Complex number types will be cast to
 *  @float or @double before being wrapped in an instance of NSNumber.
 **/
-(NSNumber *)sampleValueAtIndex:(NSUInteger)idx, ...
{
    NSUInteger newIndex;

    if ( self.numberOfDimensions > 1 ) {
        va_list indices;
        va_start(indices, idx);

        newIndex = [self sampleIndex:idx indexList:indices];

        va_end(indices);
    }
    else {
        newIndex = idx;
    }

    return [self sampleValue:newIndex];
}

/** @brief Gets a pointer to a given sample in the data buffer.
 *  @param sample The zero-based index into the sample array. The array is treated as if it only has one dimension.
 *  @return A pointer to the sample or @NULL if the sample index is out of bounds.
 **/
-(nullable const void *)samplePointer:(NSUInteger)sample
{
    if ( sample < self.numberOfSamples ) {
        return (const void *)((const char *)self.bytes + sample * self.sampleBytes);
    }
    else {
        return NULL;
    }
}

/** @brief Gets a pointer to a given sample in the data buffer.
 *  @param idx The zero-based indices into a multi-dimensional sample array. Each index should of type @ref NSUInteger and the number of indices
 *  (including @par{idx}) should match the @ref numberOfDimensions.
 *  @return A pointer to the sample or @NULL if any of the sample indices are out of bounds.
 **/
-(nullable const void *)samplePointerAtIndex:(NSUInteger)idx, ...
{
    NSUInteger newIndex;

    if ( self.numberOfDimensions > 1 ) {
        va_list indices;
        va_start(indices, idx);

        newIndex = [self sampleIndex:idx indexList:indices];

        va_end(indices);
    }
    else {
        newIndex = idx;
    }

    return [self samplePointer:newIndex];
}

/** @brief Gets an array data samples from the receiver.
 *  @return An NSArray of NSNumber objects representing the data from the receiver.
 *
 *  @note NSNumber does not support complex numbers. Complex number types will be cast to
 *  @float or @double before being wrapped in an instance of NSNumber.
 **/
-(nonnull CPTNumberArray *)sampleArray
{
    NSUInteger sampleCount = self.numberOfSamples;

    CPTMutableNumberArray *samples = [[NSMutableArray alloc] initWithCapacity:sampleCount];

    for ( NSUInteger i = 0; i < sampleCount; i++ ) {
        NSNumber *sampleValue = [self sampleValue:i];
        if ( sampleValue ) {
            [samples addObject:sampleValue];
        }
    }

    CPTNumberArray *result = [NSArray arrayWithArray:samples];

    return result;
}

/// @cond

/** @internal
 *  @brief Gets the offset of a given sample in the data buffer. This method does not call @par{va_end()}
 *  on the @par{indexList}.
 *  @param idx The zero-based indices into a multi-dimensional sample array. Each index should of type @ref NSUInteger and the number of indices
 *  (including @par{idx}) should match the @ref numberOfDimensions.
 *  @param indexList A @par{va_list} of the additional indices.
 *  @return The sample offset in the data buffer. To get the byte offset, multiply this value by
 *  @ref sampleBytes. If any index is greater than or equal to the corresponding
 *  dimension of the data buffer, this method returns @ref NSNotFound.
 **/
-(NSUInteger)sampleIndex:(NSUInteger)idx indexList:(va_list)indexList
{
    CPTNumberArray *theShape = self.shape;
    NSUInteger numDims       = theShape.count;
    NSUInteger newIndex      = 0;

    if ( numDims > 1 ) {
        NSUInteger *dims        = calloc(numDims, sizeof(NSUInteger));
        NSUInteger *dimProducts = calloc(numDims, sizeof(NSUInteger));
        NSUInteger *indices     = calloc(numDims, sizeof(NSUInteger));
        NSUInteger argIndex     = 0;

        indices[0] = idx;
        for ( NSNumber *dim in theShape ) {
            if ( argIndex > 0 ) {
                indices[argIndex] = va_arg(indexList, NSUInteger);
            }
            dims[argIndex] = dim.unsignedIntegerValue;

            if ( indices[argIndex] >= dims[argIndex] ) {
                free(dims);
                free(dimProducts);
                free(indices);
                return NSNotFound;
            }

            argIndex++;
        }

        switch ( self.dataOrder ) {
            case CPTDataOrderRowsFirst:
                dimProducts[numDims - 1] = dims[numDims - 1];
                for ( NSUInteger i = numDims - 2; i > 0; i-- ) {
                    dimProducts[i] = dimProducts[i + 1] * dims[i];
                }

                for ( NSUInteger i = 0; i < numDims - 1; i++ ) {
                    newIndex += dimProducts[i + 1] * indices[i];
                }
                newIndex += indices[numDims - 1];

                break;

            case CPTDataOrderColumnsFirst:
                dimProducts[0] = dims[0];
                for ( NSUInteger i = 1; i < numDims - 1; i++ ) {
                    dimProducts[i] = dimProducts[i - 1] * dims[i];
                }

                newIndex = indices[0];
                for ( NSUInteger i = 1; i < numDims; i++ ) {
                    newIndex += dimProducts[i - 1] * indices[i];
                }

                break;
        }

        free(dims);
        free(dimProducts);
        free(indices);
    }
    else {
        newIndex = idx;
    }

    return newIndex;
}

-(nonnull NSData *)dataFromArray:(nonnull CPTNumberArray *)newData dataType:(CPTNumericDataType)newDataType
{
    NSParameterAssert(CPTDataTypeIsSupported(newDataType));
    NSParameterAssert(newDataType.dataTypeFormat != CPTUndefinedDataType);
    NSParameterAssert(newDataType.dataTypeFormat != CPTComplexFloatingPointDataType);

    NSMutableData *sampleData = [[NSMutableData alloc] initWithLength:newData.count * newDataType.sampleBytes];

    // Code generated with "CPTNumericData+TypeConversions_Generation.py"
    // ========================================================================

    switch ( newDataType.dataTypeFormat ) {
        case CPTUndefinedDataType:
            // Unsupported
            break;

        case CPTIntegerDataType:
            switch ( newDataType.sampleBytes ) {
                case sizeof(int8_t):
                {
                    int8_t *toBytes = (int8_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(charValue)] ) {
                            *toBytes++ = (int8_t)[sample charValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(int16_t):
                {
                    int16_t *toBytes = (int16_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(shortValue)] ) {
                            *toBytes++ = (int16_t)[sample shortValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(int32_t):
                {
                    int32_t *toBytes = (int32_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(longValue)] ) {
                            *toBytes++ = (int32_t)[sample longValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(int64_t):
                {
                    int64_t *toBytes = (int64_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(longLongValue)] ) {
                            *toBytes++ = (int64_t)[sample longLongValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;
            }
            break;

        case CPTUnsignedIntegerDataType:
            switch ( newDataType.sampleBytes ) {
                case sizeof(uint8_t):
                {
                    uint8_t *toBytes = (uint8_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(unsignedCharValue)] ) {
                            *toBytes++ = (uint8_t)[sample unsignedCharValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(uint16_t):
                {
                    uint16_t *toBytes = (uint16_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(unsignedShortValue)] ) {
                            *toBytes++ = (uint16_t)[sample unsignedShortValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(uint32_t):
                {
                    uint32_t *toBytes = (uint32_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(unsignedLongValue)] ) {
                            *toBytes++ = (uint32_t)[sample unsignedLongValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;

                case sizeof(uint64_t):
                {
                    uint64_t *toBytes = (uint64_t *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(unsignedLongLongValue)] ) {
                            *toBytes++ = (uint64_t)[sample unsignedLongLongValue];
                        }
                        else {
                            *toBytes++ = 0;
                        }
                    }
                }
                break;
            }
            break;

        case CPTFloatingPointDataType:
            switch ( newDataType.sampleBytes ) {
                case sizeof(float):
                {
                    float *toBytes = (float *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(floatValue)] ) {
                            *toBytes++ = (float)[sample floatValue];
                        }
                        else {
                            *toBytes++ = NAN;
                        }
                    }
                }
                break;

                case sizeof(double):
                {
                    double *toBytes = (double *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(doubleValue)] ) {
                            *toBytes++ = (double)[sample doubleValue];
                        }
                        else {
                            *toBytes++ = (double)NAN;
                        }
                    }
                }
                break;
            }
            break;

        case CPTComplexFloatingPointDataType:
            switch ( newDataType.sampleBytes ) {
                case sizeof(float complex):
                {
                    float complex *toBytes = (float complex *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(floatValue)] ) {
                            *toBytes++ = (float complex)[sample floatValue];
                        }
                        else {
                            *toBytes++ = CMPLXF(NAN, NAN);
                        }
                    }
                }
                break;

                case sizeof(double complex):
                {
                    double complex *toBytes = (double complex *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(doubleValue)] ) {
                            *toBytes++ = (double complex)[sample doubleValue];
                        }
                        else {
                            *toBytes++ = CMPLX(NAN, NAN);
                        }
                    }
                }
                break;
            }
            break;

        case CPTDecimalDataType:
            switch ( newDataType.sampleBytes ) {
                case sizeof(NSDecimal):
                {
                    NSDecimal *toBytes = (NSDecimal *)sampleData.mutableBytes;
                    for ( id sample in newData ) {
                        if ( [sample respondsToSelector:@selector(decimalValue)] ) {
                            *toBytes++ = [sample decimalValue];
                        }
                        else {
                            *toBytes++ = CPTDecimalNaN();
                        }
                    }
                }
                break;
            }
            break;
    }

    // End of code generated with "CPTNumericData+TypeConversions_Generation.py"
    // ========================================================================

    if ((newDataType.byteOrder != CFByteOrderGetCurrent()) && (newDataType.byteOrder != CFByteOrderUnknown)) {
        [self swapByteOrderForData:sampleData sampleSize:newDataType.sampleBytes];
    }

    return sampleData;
}

/// @endcond

#pragma mark -
#pragma mark Description

/// @cond

-(nonnull NSString *)description
{
    NSUInteger sampleCount             = self.numberOfSamples;
    NSMutableString *descriptionString = [NSMutableString stringWithCapacity:sampleCount * 3];

    [descriptionString appendFormat:@"<%@ [", super.description];
    for ( NSUInteger i = 0; i < sampleCount; i++ ) {
        if ( i > 0 ) {
            [descriptionString appendFormat:@","];
        }
        [descriptionString appendFormat:@" %@", [self sampleValue:i]];
    }
    [descriptionString appendFormat:@" ] {%@, %@, %@}>",
     CPTDataTypeStringFromDataType(self.dataType),
     self.shape,
     (self.dataOrder == CPTDataOrderRowsFirst ? @"by rows" : @"by columns")];

    return descriptionString;
}

/// @endcond

#pragma mark -
#pragma mark NSMutableCopying Methods

/// @cond

-(nonnull id)mutableCopyWithZone:(nullable NSZone *)zone
{
    return [[CPTMutableNumericData allocWithZone:zone] initWithData:self.data
                                                           dataType:self.dataType
                                                              shape:self.shape
                                                          dataOrder:self.dataOrder];
}

/// @endcond

#pragma mark -
#pragma mark NSCopying Methods

/// @cond

-(nonnull id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithData:self.data
                                                  dataType:self.dataType
                                                     shape:self.shape
                                                 dataOrder:self.dataOrder];
}

/// @endcond

#pragma mark -
#pragma mark NSCoding Methods

/// @cond

-(void)encodeWithCoder:(nonnull NSCoder *)encoder
{
    [encoder encodeObject:self.data forKey:@"CPTNumericData.data"];

    CPTNumericDataType selfDataType = self.dataType;
    [encoder encodeInteger:selfDataType.dataTypeFormat forKey:@"CPTNumericData.dataType.dataTypeFormat"];
    [encoder encodeInt64:(int64_t)selfDataType.sampleBytes forKey:@"CPTNumericData.dataType.sampleBytes"];
    [encoder encodeInt64:selfDataType.byteOrder forKey:@"CPTNumericData.dataType.byteOrder"];

    [encoder encodeObject:self.shape forKey:@"CPTNumericData.shape"];
    [encoder encodeInteger:self.dataOrder forKey:@"CPTNumericData.dataOrder"];
}

/// @endcond

/** @brief Returns an object initialized from data in a given unarchiver.
 *  @param decoder An unarchiver object.
 *  @return An object initialized from data in a given unarchiver.
 */
-(nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
    if ((self = [super init])) {
        NSData *newData;
        CPTNumericDataType newDataType;
        CPTNumberArray *shapeArray;
        CPTDataOrder order;

        newData = [decoder decodeObjectOfClass:[NSData class]
                                        forKey:@"CPTNumericData.data"];

        newDataType = CPTDataType((CPTDataTypeFormat)[decoder decodeIntegerForKey:@"CPTNumericData.dataType.dataTypeFormat"],
                                  (size_t)[decoder decodeInt64ForKey:@"CPTNumericData.dataType.sampleBytes"],
                                  (CFByteOrder)[decoder decodeInt64ForKey:@"CPTNumericData.dataType.byteOrder"]);

        shapeArray = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSNumber class]]]
                                             forKey:@"CPTNumericData.shape"];

        order = (CPTDataOrder)[decoder decodeIntegerForKey:@"CPTNumericData.dataOrder"];

        [self commonInitWithData:newData dataType:newDataType shape:shapeArray dataOrder:order];
    }

    return self;
}

#pragma mark -
#pragma mark NSSecureCoding Methods

/// @cond

+(BOOL)supportsSecureCoding
{
    return YES;
}

/// @endcond

@end
