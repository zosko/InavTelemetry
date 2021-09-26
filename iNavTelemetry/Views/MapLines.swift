//
//  MapLines.swift
//  iNavTelemetry
//
//  Created by Bosko Petreski on 9/27/21.
//

import SwiftUI
import MapKit

struct MapViewLines: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .satellite
        mapView.delegate = context.coordinator
        if let firstCoordinate = coordinates.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            mapView.region = .init(center: firstCoordinate, span: span)
        }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
      var parent: MapViewLines

      init(_ parent: MapViewLines) {
        self.parent = parent
      }

      func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let routePolyline = overlay as? MKPolyline {
          let renderer = MKPolylineRenderer(polyline: routePolyline)
          renderer.strokeColor = .systemBlue
          renderer.lineWidth = 4
          return renderer
        }
        return MKOverlayRenderer()
      }
    }
}
