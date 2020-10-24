//
//  ViewController.swift
//  iNavTelemetry
//
//  Created by Bosko Petreski on 5/28/20.
//  Copyright © 2020 Bosko Petreski. All rights reserved.
//

import UIKit
import MBProgressHUD
import MapKit
import CoreBluetooth

class MainScreen: UIViewController {

    // MARK: IBOutlets
    @IBOutlet var mapPlane : MKMapView!
    @IBOutlet var btnConnect : UIButton!
    @IBOutlet var lblLatitude: UILabel!
    @IBOutlet var lblLongitude: UILabel!
    @IBOutlet var lblSatellites: UILabel!
    @IBOutlet var lblDistance: UILabel!
    @IBOutlet var lblAltitude: UILabel!
    @IBOutlet var lblSpeed: UILabel!
    @IBOutlet var lblVoltage: UILabel!
    @IBOutlet var lblCurrent: UILabel!
    @IBOutlet var lblArmed: UILabel!
    @IBOutlet var lblStabilization: UILabel!
    @IBOutlet var lblSignalStrength: UILabel!
    @IBOutlet var lblFuel: UILabel!
    @IBOutlet var imgCompass: UIImageView!
    @IBOutlet var imgHorizontPlane: UIImageView!
    @IBOutlet var imgHorizontLine: UIImageView!
    @IBOutlet var switchLive: UISwitch!
    
    //MARK: - Variables
    var planeAnnotation : LocationPointAnnotation!
    var gsAnnotation : LocationPointAnnotation!
    var telemetry = SmartPort()
    var locationManager:CLLocationManager?
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    var peripherals : [CBPeripheral] = []
    var oldLocation : CLLocationCoordinate2D!
    
    //MARK: - IBActions
    @IBAction func onBtnConnect(_ sender: Any) {
        if connectedPeripheral != nil {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
            connectedPeripheral = nil;
            peripherals.removeAll()
        }
        else{
            peripherals.removeAll()
            centralManager.scanForPeripherals(withServices: [CBUUID(string: "FFE0")], options: nil)
            MBProgressHUD.showAdded(to: self.view, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MBProgressHUD.hide(for: self.view, animated: true)
                self.stopSearchReader()
            }
        }
    }
    @IBAction func onBtnSetHomePosition(_ sender: Any){
        if planeAnnotation.coordinate.latitude != CLLocationCoordinate2D(latitude: 0, longitude: 0).latitude {
            gsAnnotation.coordinate = planeAnnotation.coordinate
            let region = MKCoordinateRegion(center: gsAnnotation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapPlane.setRegion(region, animated: true)
        }
    }
    
    //MARK: - CustomFunctions
    func addSocketListeners(){
        SocketComunicator.shared.planesLocation { (data) in
            let annotations = self.mapPlane.annotations as! [LocationPointAnnotation]
            let annotationsToRemove = annotations.filter { $0.imageName == "other_plane" }
            self.mapPlane.removeAnnotations(annotationsToRemove)
            
            for (key,planeData) in data {
                let object = planeData as! [String:Any]
                let lat = CLLocationDegrees(object["lat"] as! Double)
                let lng = CLLocationDegrees(object["lng"] as! Double)
                
                let location = CLLocation(latitude: lat, longitude: lng)
                let otherPlane = LocationPointAnnotation()
                otherPlane.title = key
                otherPlane.imageName = "other_plane"
                otherPlane.coordinate = location.coordinate
                self.mapPlane.addAnnotation(otherPlane)
            }
        }
    }
    func addAnnotations(){
        planeAnnotation = LocationPointAnnotation()
        planeAnnotation.title = "My Plane"
        planeAnnotation.imageName = "my_plane"
        
        gsAnnotation = LocationPointAnnotation()
        gsAnnotation.title = "Ground Station"
        gsAnnotation.imageName = "gs"
        mapPlane.addAnnotations([gsAnnotation,planeAnnotation])
    }
    func refreshTelemetry(packet: SmartPortStruct){
        lblLatitude.text = "Latitude\n \(packet.lat)"
        lblLongitude.text = "Longitude\n \(packet.lng)"
        lblSatellites.text = "Satellites\n \(packet.gps_sats)"
        lblDistance.text = "Distance\n \(packet.distance) m"
        lblAltitude.text = "Altitude\n \(packet.alt) m"
        lblSpeed.text = "Speed\n \(packet.speed) km/h"
        lblVoltage.text = "Voltage\n \(packet.voltage) V"
        lblCurrent.text = "Current\n \(packet.current) Amp"
        lblStabilization.text = "Flymode\n \(telemetry.getStabilization())"
        lblArmed.text = "Armed\n \(telemetry.getArmed())"
        lblSignalStrength.text = "Signal\n \(packet.rssi) %"
        lblFuel.text = "Fuel\n \(packet.fuel) %"
        
        refreshLocation(latitude: packet.lat, longitude: packet.lng)
        refreshCompass(degree: packet.heading)
        refreshHorizon(pitch: -packet.pitch, roll: packet.roll)
        
        if switchLive.isOn {
            SocketComunicator.shared.sendPlaneData(packet: packet)
        }
    }
    
    func refreshCompass(degree: Int){
        imgCompass.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi * Double(degree) / 180.0))
    }
    func refreshHorizon(pitch: Int, roll: Int){
        imgHorizontPlane.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi * Double(roll) / 180.0))
        imgHorizontLine.frame.origin.y = CGFloat(pitch)
    }
    func refreshLocation(latitude: Double, longitude: Double){
        let location = CLLocation(latitude: latitude, longitude: longitude)
        planeAnnotation.coordinate = location.coordinate
        
        guard let tmpOldLocation = oldLocation else { return }
        let polyline = MKPolyline(coordinates: [tmpOldLocation,planeAnnotation.coordinate], count: 2)
        mapPlane.addOverlay(polyline)
        oldLocation = planeAnnotation.coordinate
    }
    func stopSearchReader(){
        centralManager.stopScan()
        
        let alert = UIAlertController.init(title: "Search device", message: "Choose Tracker device", preferredStyle: .actionSheet)
        
        for periperal in peripherals{
            let action = UIAlertAction.init(title: periperal.name ?? "no_name", style: .default) { (action) in
                self.centralManager.connect(periperal, options: nil)
            }
            alert.addAction(action)
        }
        let actionCancel = UIAlertAction.init(title: "Cancel", style: .destructive) { (action) in
        }
        alert.addAction(actionCancel)
        
        if let presenter = alert.popoverPresentationController {
            presenter.sourceView = btnConnect;
            presenter.sourceRect = btnConnect.bounds;
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UIViewDelegates
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager.init(delegate: self, queue: nil)
        addAnnotations()
        addSocketListeners()
        
        
//        let urlTeplate = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
//        let overlay = MKTileOverlay(urlTemplate: urlTeplate)
//        overlay.canReplaceMapContent = true
//        mapPlane.addOverlay(overlay, level: .aboveLabels)
    }
}

