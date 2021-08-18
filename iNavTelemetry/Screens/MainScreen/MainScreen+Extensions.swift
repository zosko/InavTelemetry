//
//  MainScreen+Extensions.swift
//  iNavTelemetry
//
//  Created by Bosko Petreski on 5/31/20.
//  Copyright © 2020 Bosko Petreski. All rights reserved.
//

import UIKit
import CoreBluetooth
import MapKit
import Toast

extension MainScreen: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    //MARK: CentralManagerDelegates
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var message = "Bluetooth"
        switch (central.state) {
        case .unknown: message = "Bluetooth Unknown."; break
        case .resetting: message = "The update is being started. Please wait until Bluetooth is ready."; break
        case .unsupported: message = "This device does not support Bluetooth low energy."; break
        case .unauthorized: message = "This app is not authorized to use Bluetooth low energy."; break
        case .poweredOff: message = "You must turn on Bluetooth in Settings in order to use the reader."; break
        default: break;
        }
        print("Bluetooth: " + message);
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !peripherals.contains(peripheral){
            peripherals.append(peripheral)
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedPeripheral.delegate = self
        connectedPeripheral.discoverServices(nil)
        self.view.makeToast("Connected")
        btnConnect.setImage(UIImage(named: "power_on"), for: .normal)
        
        if telemetry.getTelemetryType() == .MSP {
            MSPTelemetry(start: true)
        }
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("FailToConnect" + error!.localizedDescription)
        }
        self.view.makeToast("Fail to connect")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("FailToDisconnect" + error!.localizedDescription)
        }
        
        peripherals.removeAll()
        self.connectedPeripheral = nil;
        self.view.makeToast("Disconnected")
        btnConnect.setImage(UIImage(named: "power_off"), for: .normal)
        Database.shared.stopLogging()
        segmentProtocol.isEnabled = true
        if telemetry.getTelemetryType() == .MSP {
            MSPTelemetry(start: false)
        }
    }
    
    //MARK: PeripheralDelegates
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Error receiving didWriteValueFor \(characteristic) : " + error!.localizedDescription)
            return
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Error receiving notification for characteristic \(characteristic) : " + error!.localizedDescription)
            return
        }
        if telemetry.parse(incomingData: characteristic.value!) {
            refreshTelemetry(packet: telemetry.getTelemetry())
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services!{
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Error receiving didUpdateNotificationStateFor \(characteristic) : " + error!.localizedDescription)
            return
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            peripheral.setNotifyValue(true, for: characteristic)
            
            print("didDiscoverCharacteristicsFor: \(characteristic)")
            
            if characteristic.uuid == CBUUID(string: BluetoothUUID.FRSKY_CHAR.rawValue){
                print("FRSKY CONNECTED")
                self.writeCharacteristic = characteristic
                self.writeTypeCharacteristic = characteristic.properties == .write ? .withResponse : .withoutResponse
            }
            
            if characteristic.uuid == CBUUID(string: BluetoothUUID.HM10_CHAR.rawValue){
                print("HM10 CONNECTED")
                self.writeCharacteristic = characteristic
                self.writeTypeCharacteristic = characteristic.properties == .write ? .withResponse : .withoutResponse
            }

        }
    }
}

extension MainScreen: MKMapViewDelegate {
    
    // MARK: - MKMAPViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKTileOverlay {
            let renderer = MKTileOverlayRenderer(overlay: overlay)
            return renderer
        } else {
            if let routePolyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: routePolyline)
                renderer.strokeColor = UIColor.red
                renderer.lineWidth = 2
                return renderer
            }
        }
        return MKTileOverlayRenderer()
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if !(annotation is LocationPointAnnotation) {
            return nil
        }
        let reuseId = "LocationPin"
        var anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
        if anView == nil {
            anView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            anView?.canShowCallout = true
        }
        else {
            anView?.annotation = annotation
        }

        let cpa = annotation as! LocationPointAnnotation
        if cpa.imageName != nil{
            anView?.image = UIImage(named:cpa.imageName)
        }
        return anView
    }
}

extension MainScreen {
    
    // MARK: - Helpers
    func toDate(timestamp : Double) -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MMM d [hh:mm]"
        let date = Date(timeIntervalSince1970: timestamp)
        return dateFormatter.string(from: date)
    }
    func openLog(urlLog : URL){
        let jsonData = try! Data(contentsOf: urlLog)
        let logData = try! JSONDecoder().decode([TelemetryStruct].self, from: jsonData)
        
        let controller : LogScreen = self.storyboard!.instantiateViewController(identifier: "LogScreen")
        controller.logData = logData
        self.present(controller, animated: true, completion: nil)
    }
}
