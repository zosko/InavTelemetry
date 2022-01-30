//
//  BluetoothManagerSpec.swift
//  iNavTelemetryTests
//
//  Created by Bosko Petreski on 30.1.22.
//

import XCTest
import Combine
import CoreBluetooth

@testable import iNavTelemetry

final class BluetoothCommunicatorMock: BluetoothProtocol {
    var dataReceived: Published<Data?>.Publisher { $_dataReceived }
    var isScanning: Published<Bool>.Publisher { $_isScanning }
    var connected: Published<Bool>.Publisher { $_connected }
    
    @Published var _dataReceived: Data? = nil
    @Published var _isScanning: Bool = false
    @Published var _connected: Bool = false
    
    var devicesFound: [CBPeripheral] = []
    
    func search() -> AnyPublisher<[CBPeripheral], Never> {
        Future { promise in
            self._isScanning = true
            promise(.success(self.devicesFound))
        }.eraseToAnyPublisher()
    }
    
    func connect(_ peripheral: CBPeripheral) {
        _connected = peripheral == devicesFound.first!
    }
    
    func disconnect(_ peripheral: CBPeripheral) {
        _connected = !(peripheral == devicesFound.first!)
    }
    
    func write(data: Data) {
        
    }
}

class BluetoothManagerSpec: XCTestCase {

    func testBluetoothManager() throws {
        let testData = "test_data".data(using: .utf8)
        
        let communicator = BluetoothCommunicatorMock()
        let manager = BluetoothManager(bluetoothCommunicator: communicator)
        
        communicator._dataReceived = testData
        
        XCTAssertEqual(manager.dataReceived, testData)
        XCTAssertEqual(manager.peripherals, [])
        XCTAssertFalse(manager.isScanning)
        XCTAssertFalse(manager.connected)
        
        manager.search()
        XCTAssertTrue(manager.isScanning)
        XCTAssertFalse(manager.connected)
    }
}
