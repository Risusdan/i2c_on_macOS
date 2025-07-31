//
//  I2CService.swift
//  studyi2c
//
//  Created by ChienLin Su on 2025/7/31.
//

import Foundation
import IOKit

// Constants for I2C/DDC communication
let I2C_DDC_7BIT_ADDRESS: UInt8 = 0x37  // DisplayPort I2C address
let I2C_DDC_DATA_ADDRESS: UInt8 = 0x51  // DDC data address

// MARK: - Service Discovery and Management

struct DisplayService {
    let displayID: CGDirectDisplayID
    let service: IOAVService?
    let edidUUID: String
    let productName: String
    let manufacturerID: String
    let location: String
}

class I2CService {
    
    // MARK: - Service Discovery
    
    static func discoverDisplayServices() -> [DisplayService] {
        var displayServices: [DisplayService] = []
        
        print("Searching for IOAVService instances...")
        
        // Directly search for DCPAVServiceProxy entries in IORegistry
        if let services = findAllIOAVServices() {
            for (index, service) in services.enumerated() {
                let displayService = DisplayService(
                    displayID: CGDirectDisplayID(index + 1), // Use index as placeholder
                    service: service.service,
                    edidUUID: service.edidUUID,
                    productName: service.productName,
                    manufacturerID: service.manufacturerID,
                    location: service.location
                )
                displayServices.append(displayService)
                print("✓ Found IOAVService \(index + 1): \(service.productName)")
            }
        }
        
        if displayServices.isEmpty {
            print("✗ No IOAVServices found")
        }
        
        return displayServices
    }
    
    private static func findAllIOAVServices() -> [(service: IOAVService, edidUUID: String, productName: String, manufacturerID: String, location: String)]? {
        let ioregRoot = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(ioregRoot) }
        
        var iterator = io_iterator_t()
        defer { IOObjectRelease(iterator) }
        
        guard IORegistryEntryCreateIterator(ioregRoot, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return nil
        }
        
        var services: [(service: IOAVService, edidUUID: String, productName: String, manufacturerID: String, location: String)] = []
        
        // Look for DCPAVServiceProxy entries
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != MACH_PORT_NULL else { break }
            defer { IOObjectRelease(entry) }
            
            let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
            defer { name.deallocate() }
            
            guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS else { continue }
            let nameString = String(cString: name)
            
            if nameString.contains("DCPAVServiceProxy") {
                if let location = getIORegistryProperty(entry: entry, key: "Location") as? String,
                   location == "External" {
                    
                    let edidUUID = getIORegistryProperty(entry: entry, key: "EDID UUID") as? String ?? ""
                    let productName = getDisplayAttributeProductName(entry: entry)
                    let manufacturerID = getDisplayAttributeManufacturerID(entry: entry)
                    
                    if let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() as IOAVService? {
                        services.append((service, edidUUID, productName, manufacturerID, location))
                    }
                }
            }
        }
        
        return services.isEmpty ? nil : services
    }
    
    private static func getIORegistryProperty(entry: io_service_t, key: String) -> Any? {
        if let property = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) {
            return property.takeRetainedValue()
        }
        return nil
    }
    
    private static func getDisplayAttributeProductName(entry: io_service_t) -> String {
        if let attrs = getIORegistryProperty(entry: entry, key: "DisplayAttributes") as? NSDictionary,
           let productAttrs = attrs["ProductAttributes"] as? NSDictionary,
           let productName = productAttrs["ProductName"] as? String {
            return productName
        }
        return ""
    }
    
    private static func getDisplayAttributeManufacturerID(entry: io_service_t) -> String {
        if let attrs = getIORegistryProperty(entry: entry, key: "DisplayAttributes") as? NSDictionary,
           let productAttrs = attrs["ProductAttributes"] as? NSDictionary,
           let manufacturerID = productAttrs["ManufacturerID"] as? String {
            return manufacturerID
        }
        return ""
    }
}

// MARK: - I2C Communication Functions

extension I2CService {
    
    // Raw I2C write function
    static func writeI2C(service: IOAVService?, chipAddress: UInt8 = I2C_DDC_7BIT_ADDRESS, dataAddress: UInt8 = I2C_DDC_DATA_ADDRESS, data: [UInt8]) -> Bool {
        guard let service = service else {
            print("❌ No IOAVService provided")
            return false
        }
        
        var buffer = data
        let result = IOAVServiceWriteI2C(service, UInt32(chipAddress), UInt32(dataAddress), &buffer, UInt32(buffer.count))
        
        if result == kIOReturnSuccess {
            print("✓ I2C write successful: \(data.count) bytes to chip 0x\(String(chipAddress, radix: 16, uppercase: true)), data addr 0x\(String(dataAddress, radix: 16, uppercase: true))")
            return true
        } else {
            print("❌ I2C write failed with error: 0x\(String(result, radix: 16, uppercase: true))")
            return false
        }
    }
    
    // Raw I2C read function
    static func readI2C(service: IOAVService?, chipAddress: UInt8 = I2C_DDC_7BIT_ADDRESS, offset: UInt8 = 0, length: Int) -> [UInt8]? {
        guard let service = service else {
            print("❌ No IOAVService provided")
            return nil
        }
        
        var buffer = [UInt8](repeating: 0, count: length)
        let result = IOAVServiceReadI2C(service, UInt32(chipAddress), UInt32(offset), &buffer, UInt32(length))
        
        if result == kIOReturnSuccess {
            print("✓ I2C read successful: \(length) bytes from chip 0x\(String(chipAddress, radix: 16, uppercase: true)), offset 0x\(String(offset, radix: 16, uppercase: true))")
            return buffer
        } else {
            print("❌ I2C read failed with error: 0x\(String(result, radix: 16, uppercase: true))")
            return nil
        }
    }
    
    // DDC/CI command for monitor control (example)
    static func sendDDCCommand(service: IOAVService?, command: UInt8, value: UInt16? = nil) -> Bool {
        guard let service = service else { return false }
        
        var packet: [UInt8]
        
        if let value = value {
            // Write command with value
            packet = [command, UInt8(value >> 8), UInt8(value & 0xFF)]
        } else {
            // Read command
            packet = [command]
        }
        
        // Add DDC packet structure
        var ddcPacket: [UInt8] = [UInt8(0x80 | (packet.count + 1)), UInt8(packet.count)] + packet + [0]
        
        // Calculate checksum
        let checksum = calculateChecksum(data: ddcPacket, excluding: ddcPacket.count - 1)
        ddcPacket[ddcPacket.count - 1] = checksum
        
        return writeI2C(service: service, data: ddcPacket)
    }
    
    // DDC/CI read response
    static func readDDCResponse(service: IOAVService?, length: Int = 11) -> [UInt8]? {
        return readI2C(service: service, length: length)
    }
    
    // Checksum calculation for DDC packets
    private static func calculateChecksum(data: [UInt8], excluding excludeIndex: Int) -> UInt8 {
        var checksum: UInt8 = (I2C_DDC_7BIT_ADDRESS << 1) ^ I2C_DDC_DATA_ADDRESS
        
        for (index, byte) in data.enumerated() {
            if index != excludeIndex {
                checksum ^= byte
            }
        }
        
        return checksum
    }
}

// MARK: - Firmware Flashing Utilities

extension I2CService {
    
    // Example firmware block write (4KB max)
    static func writeFirmwareBlock(service: IOAVService?, address: UInt32, data: [UInt8]) -> Bool {
        guard data.count <= 4096 else {
            print("❌ Data block too large: \(data.count) bytes (max 4096)")
            return false
        }
        
        print("📝 Writing firmware block: \(data.count) bytes to address 0x\(String(address, radix: 16, uppercase: true))")
        
        // Custom protocol implementation would go here
        // This is just a demonstration of the API capabilities
        
        var buffer = data
        let result = IOAVServiceWriteI2C(service, UInt32(I2C_DDC_7BIT_ADDRESS), address, &buffer, UInt32(buffer.count))
        
        return result == kIOReturnSuccess
    }
    
    // Example firmware block read
    static func readFirmwareBlock(service: IOAVService?, address: UInt32, length: Int) -> [UInt8]? {
        guard length <= 4096 else {
            print("❌ Read length too large: \(length) bytes (max 4096)")
            return nil
        }
        
        print("📖 Reading firmware block: \(length) bytes from address 0x\(String(address, radix: 16, uppercase: true))")
        
        var buffer = [UInt8](repeating: 0, count: length)
        let result = IOAVServiceReadI2C(service, UInt32(I2C_DDC_7BIT_ADDRESS), address, &buffer, UInt32(length))
        
        return result == kIOReturnSuccess ? buffer : nil
    }
    
    // Verify firmware block
    static func verifyFirmwareBlock(service: IOAVService?, address: UInt32, expectedData: [UInt8]) -> Bool {
        guard let readData = readFirmwareBlock(service: service, address: address, length: expectedData.count) else {
            return false
        }
        
        let matches = readData == expectedData
        print(matches ? "✓ Firmware block verification passed" : "❌ Firmware block verification failed")
        
        return matches
    }
}