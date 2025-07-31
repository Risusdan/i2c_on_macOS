//
//  I2CService.h
//  studyi2c
//
//  Created by ChienLin Su on 2025/7/31.
//

#ifndef I2CService_h
#define I2CService_h

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <stdint.h>

// IOAVService API declarations (undocumented Apple APIs)
typedef CFTypeRef IOAVService;

extern IOAVService IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVService IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVService service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVService service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);

// Constants for I2C communication
extern const uint8_t I2C_DDC_7BIT_ADDRESS;
extern const uint8_t I2C_DDC_DATA_ADDRESS;

#endif /* I2CService_h */