import MapKit

private let reuseIdentifier = "reuse-identifier"

class CustomPinAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var image: UIImage?

    init(
        _ coordinate: CLLocationCoordinate2D,
        _ image: UIImage? = nil
    ) {
        self.coordinate = coordinate
        self.image = image
        super.init()
    }
}

extension MKMapView {
    func animaiteToCenter(
        _ center: CLLocationCoordinate2D,
        _ zoomLevel: Int = 11
    ) {
        let zoom = zoomLevel < 0 || zoomLevel > 20 ? 9 : zoomLevel

        // An approximation. Based off tile zoom level.
        let zoomScale = 1.0 / pow(2.0, Double(zoom))
        let latDelta = 180.0 * zoomScale
        let longDelta = 360.0 * zoomScale
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: longDelta)

        let regionCenter = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude), span: span)
        let region = regionThatFits(regionCenter)
        setRegion(region, animated: true)
    }

    private func overlayPolygons() {
        let firstHalf = [
            CLLocationCoordinate2D(latitude: -90, longitude: -180),
            CLLocationCoordinate2D(latitude: -90, longitude: 0),
            CLLocationCoordinate2D(latitude: 90, longitude: 0),
            CLLocationCoordinate2D(latitude: 90, longitude: -180)
        ]

        let secondHalf = [
            CLLocationCoordinate2D(latitude: 90, longitude: 0),
            CLLocationCoordinate2D(latitude: 90, longitude: 180),
            CLLocationCoordinate2D(latitude: -90, longitude: 180),
            CLLocationCoordinate2D(latitude: -90, longitude: 0)
        ]

        let negativePolygon = MKPolygon(coordinates: firstHalf, count: firstHalf.count)
        let positivePolygon = MKPolygon(coordinates: secondHalf, count: secondHalf.count)

        addOverlay(negativePolygon, level: .aboveRoads)
        addOverlay(positivePolygon, level: .aboveRoads)
    }

    func configureStaticMap() {
        overrideUserInterfaceStyle = .light
        mapType = .standard
        pointOfInterestFilter = .excludingAll
        camera.centerCoordinateDistance = 20
        isRotateEnabled = false
        isPitchEnabled = false
        isScrollEnabled = false

        overlayPolygons()
    }

    func staticMapAnnotationView(_ annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) else {
            if let annotation = annotation as? CustomPinAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.image = annotation.image
                return view
            }
            return nil
        }
        return annotationView
    }
}

func staticMapRenderer(for polygon: MKPolygon) -> MKPolygonRenderer {
    let renderer = MKPolygonRenderer(polygon: polygon)
    renderer.alpha = 0.5
    renderer.lineWidth = 0
    renderer.fillColor = UIColor.black
    renderer.blendMode = .color
    return renderer
}
