#import "CPTNumericDataTypeConversionPerformanceTests.h"

#import "CPTNumericData+TypeConversion.h"
#import <mach/mach_time.h>

static const size_t numberOfSamples = 10000000;

@implementation CPTNumericDataTypeConversionPerformanceTests

-(void)testFloatToDoubleConversion
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength:numberOfSamples * sizeof(float)];
    float *samples      = (float *)[data mutableBytes];

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sinf(i);
    }

    CPTNumericData *floatNumericData = [[CPTNumericData alloc] initWithData:data
                                                                   dataType:CPTDataType(CPTFloatingPointDataType, sizeof(float), CFByteOrderGetCurrent())
                                                                      shape:nil];

    __block CPTNumericData *doubleNumericData = nil;

    [self measureBlock: ^{
        doubleNumericData = [floatNumericData dataByConvertingToType:CPTFloatingPointDataType sampleBytes:sizeof(double) byteOrder:CFByteOrderGetCurrent()];
    }];
}

-(void)testDoubleToFloatConversion
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength:numberOfSamples * sizeof(double)];
    double *samples     = (double *)[data mutableBytes];

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sin(i);
    }

    CPTNumericData *doubleNumericData = [[CPTNumericData alloc] initWithData:data
                                                                    dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), CFByteOrderGetCurrent())
                                                                       shape:nil];

    __block CPTNumericData *floatNumericData = nil;

    [self measureBlock: ^{
        floatNumericData = [doubleNumericData dataByConvertingToType:CPTFloatingPointDataType sampleBytes:sizeof(float) byteOrder:CFByteOrderGetCurrent()];
    }];
}

-(void)testIntegerToDoubleConversion
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength:numberOfSamples * sizeof(NSInteger)];
    NSInteger *samples  = (NSInteger *)[data mutableBytes];

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = (NSInteger)(sin(i) * 1000.0);
    }

    CPTNumericData *integerNumericData = [[CPTNumericData alloc] initWithData:data
                                                                     dataType:CPTDataType(CPTIntegerDataType, sizeof(NSInteger), CFByteOrderGetCurrent())
                                                                        shape:nil];

    __block CPTNumericData *doubleNumericData = nil;

    [self measureBlock: ^{
        doubleNumericData = [integerNumericData dataByConvertingToType:CPTFloatingPointDataType sampleBytes:sizeof(double) byteOrder:CFByteOrderGetCurrent()];
    }];
}

-(void)testDoubleToIntegerConversion
{
    NSMutableData *data = [[NSMutableData alloc] initWithLength:numberOfSamples * sizeof(double)];
    double *samples     = (double *)[data mutableBytes];

    for ( NSUInteger i = 0; i < numberOfSamples; i++ ) {
        samples[i] = sin(i) * 1000.0;
    }

    CPTNumericData *doubleNumericData = [[CPTNumericData alloc] initWithData:data
                                                                    dataType:CPTDataType(CPTFloatingPointDataType, sizeof(double), CFByteOrderGetCurrent())
                                                                       shape:nil];

    __block CPTNumericData *integerNumericData = nil;

    [self measureBlock: ^{
        integerNumericData = [doubleNumericData dataByConvertingToType:CPTIntegerDataType sampleBytes:sizeof(NSInteger) byteOrder:CFByteOrderGetCurrent()];
    }];
}

@end
