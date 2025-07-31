//
//  main.swift
//  studyi2c
//
//  Created by ChienLin Su on 2025/7/31.
//

import Foundation

print("🔧 I2C Communication Demo via IOAVService APIs")
print(String(repeating: "=", count: 50))

// Discover all available display services
print("\n📡 Discovering Display Services...")
let displayServices = I2CService.discoverDisplayServices()

if displayServices.isEmpty {
    print("❌ No external displays with IOAVService found")
    print("   Make sure you have an external monitor connected via DisplayPort/USB-C")
    exit(1)
}

print("\n📋 Found \(displayServices.count) display service(s):")
for (index, service) in displayServices.enumerated() {
    print("  \(index + 1). Display ID: \(service.displayID)")
    print("     Product: \(service.productName)")
    print("     Manufacturer: \(service.manufacturerID)")
    print("     EDID UUID: \(service.edidUUID)")
    print("     Location: \(service.location)")
}

// Test with the first available service
let testService = displayServices[0]
print("\n🧪 Testing I2C communication with: \(testService.productName)")

// Test 1: Basic I2C Write
print("\n📝 Test 1: Basic I2C Write")
let testData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
let writeSuccess = I2CService.writeI2C(service: testService.service, data: testData)
print("Result: \(writeSuccess ? "✓ Success" : "❌ Failed")")

// Test 2: Basic I2C Read
print("\n📖 Test 2: Basic I2C Read")
if let readData = I2CService.readI2C(service: testService.service, length: 16) {
    print("✓ Read \(readData.count) bytes:")
    print("  Data: \(readData.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
} else {
    print("❌ Read failed")
}

// Test 3: DDC/CI Command Example (Monitor Brightness Query)
print("\n💡 Test 3: DDC/CI Brightness Query")
if I2CService.sendDDCCommand(service: testService.service, command: 0x10) {
    usleep(50000) // Wait 50ms for response
    if let response = I2CService.readDDCResponse(service: testService.service) {
        print("✓ DDC Response received:")
        print("  Raw data: \(response.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        
        // Parse brightness values (if valid DDC response)
        if response.count >= 10 && response[0] == 0x6F {
            let maxBrightness = UInt16(response[6]) * 256 + UInt16(response[7])
            let currentBrightness = UInt16(response[8]) * 256 + UInt16(response[9])
            print("  Current Brightness: \(currentBrightness)")
            print("  Maximum Brightness: \(maxBrightness)")
        }
    }
}

// Test 4: Firmware Block Operations (Demo)
print("\n🔧 Test 4: Firmware Block Operations Demo")
let firmwareAddress: UInt32 = 0x1000
let testFirmwareData = Array<UInt8>(0x00...0xFF) // 256 bytes of test data

print("Writing \(testFirmwareData.count) bytes to firmware address 0x\(String(firmwareAddress, radix: 16, uppercase: true))")
if I2CService.writeFirmwareBlock(service: testService.service, address: firmwareAddress, data: testFirmwareData) {
    print("✓ Firmware write successful")
    
    // Verify the write
    print("Verifying firmware block...")
    if I2CService.verifyFirmwareBlock(service: testService.service, address: firmwareAddress, expectedData: testFirmwareData) {
        print("✓ Firmware verification successful")
    } else {
        print("❌ Firmware verification failed")
    }
} else {
    print("❌ Firmware write failed")
}

// Test 5: Large Data Transfer Test (up to 4KB)
print("\n📦 Test 5: Large Data Transfer Test")
let largeTestData = Array<UInt8>(repeating: 0xAA, count: 4096) // 4KB test data
print("Testing maximum 4KB data transfer...")

if I2CService.writeFirmwareBlock(service: testService.service, address: 0x2000, data: largeTestData) {
    print("✓ 4KB write successful")
} else {
    print("❌ 4KB write failed")
}

print("\n🎉 I2C Communication Demo Complete!")
print(String(repeating: "=", count: 50))

print("\n📚 Next Steps for MCU Firmware Flashing:")
print("1. Implement your MCU-specific protocol over these I2C primitives")
print("2. Add proper error handling and retry logic")
print("3. Implement firmware validation and checksums")
print("4. Add progress reporting for large firmware updates")
print("5. Test with your specific monitor scaler IC")

print("\n⚠️  Important Notes:")
print("- These APIs are undocumented and may change in future macOS updates")
print("- Requires admin privileges for IOKit access")
print("- Works best on Apple Silicon Macs (M1/M2)")
print("- Maximum transfer size is 4KB per operation")
print("- Always verify firmware integrity after writing")

