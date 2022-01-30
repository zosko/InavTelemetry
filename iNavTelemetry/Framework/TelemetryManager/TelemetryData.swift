//
//  TelemetryData.swift
//  iNavTelemetry
//
//  Created by Bosko Petreski on 1/19/22.
//

import Foundation
import MapKit
import CoreBluetooth

struct Packet {
    var lat: Double = 0.0
    var lng: Double = 0.0
    var alt: Int = 0
    var galt: Int = 0
    var gps_sats: Int = 0
    var distance: Int = 0
    var speed: Int = 0
    var voltage: Double = 0.0
    var rssi: Int = 0
    var current: Int = 0
    var heading: Int = 0
    var flight_mode: Int = 0
    var fuel: Int = 0
    var roll: Int = 0
    var pitch: Int = 0
}

struct Plane: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let mine: Bool
}

struct LogTelemetry: Codable {
    var id: String = ""
    var lat: Double = 0.0
    var lng: Double = 0.0
    
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

struct InstrumentTelemetry {
    enum Stabilization : String {
        case undefined
        case manual
        case horizon
        case angle
        
        var name: String { self.rawValue.capitalized }
    }

    enum Engine: String {
        case undefined
        case disarmed
        case armed
        
        var name: String { self.rawValue.capitalized }
    }
    
    private(set) var packet: Packet
    private(set) var telemetryType: TelemetryType
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: packet.lat, longitude: packet.lng) }
    var stabilization: Stabilization {
        switch telemetryType {
        case .smartPort:
            let mode = packet.flight_mode / 10 % 10
            switch mode {
            case 1: return .angle
            case 2: return .horizon
            default: return .manual
            }
        case .msp:
            let flags = packet.flight_mode
            switch flags {
            case 4, 5: return .angle
            case 8, 9: return .horizon
            default: return .manual
            }
        default:
            return .undefined
        }
    }
    var engine: Engine {
        switch telemetryType {
        case .smartPort:
            let mode = packet.flight_mode % 10
            return mode == 5 ? .armed : .disarmed
        case .msp:
            let flags = packet.flight_mode
            return (flags == 1 || flags == 5 || flags == 9) ? .armed : .disarmed
        case .mavLink_v1, .mavLink_v2:
            let flags = packet.flight_mode
            return flags == 128 ? .armed : .disarmed
        default:
            return .undefined
        }
    }
}
