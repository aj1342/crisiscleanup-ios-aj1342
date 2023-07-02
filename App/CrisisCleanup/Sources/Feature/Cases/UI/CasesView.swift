import Foundation
import MapKit
import SVGView
import SwiftUI

struct CasesView: View {
    @Environment(\.translator) var t: KeyAssetTranslator
    @EnvironmentObject var router: NavigationRouter

    @ObservedObject var viewModel: CasesViewModel
    let incidentSelectViewBuilder: IncidentSelectViewBuilder

    @State var map = MKMapView()

    @State var openIncidentSelect = false

    func animateToSelectedIncidentBounds(_ bounds: LatLngBounds) {
        let latDelta = bounds.northEast.latitude - bounds.southWest.latitude
        let longDelta = bounds.northEast.longitude - bounds.southWest.longitude
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: longDelta)

        let center = bounds.center
        let regionCenter = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude), span: span)
        let region = map.regionThatFits(regionCenter)
        map.setRegion(region, animated: true)
    }

    func casesCountText(_ visibleCount: Int, _ totalCount: Int) -> String {
        {
            if visibleCount == totalCount || visibleCount == 0 {
                if (visibleCount == 0) {
                    return t("info.t_of_t_cases").replacingOccurrences(of: "{visible_count}", with: "\(totalCount)")
                } else if totalCount == 1 {
                    return t("info.1_of_1_case")
                } else {
                    return t("info.t_of_t_cases").replacingOccurrences(of: "{visible_count}", with: "\(totalCount)")
                }
            } else {
                return t("info.v_of_t_cases")
                    .replacingOccurrences(of: "{visible_count}", with: "\(visibleCount)")
                    .replacingOccurrences(of: "{total_count}", with: "\(totalCount)")
            }
        }()
    }

    var body: some View {
        ZStack {

            MapView(
                map: $map,
                viewModel: viewModel,
                onSelectWorksite: { worksiteId in
                    let incidentId = viewModel.incidentsData.selectedId
                    router.viewCase(incidentId: incidentId, worksiteId: worksiteId)
                }
            )
                .onReceive(viewModel.$incidentLocationBounds) { bounds in
                    animateToSelectedIncidentBounds(bounds.bounds)
                }
                .onReceive(viewModel.$incidentMapMarkers) { incidentAnnotations in
                    let annotations = map.annotations
                    if incidentAnnotations.annotationIdSet.isEmpty || annotations.count > 1500 {
                        map.removeAnnotations(annotations)
                    }
                    map.addAnnotations(incidentAnnotations.newAnnotations)
                }

            if viewModel.showDataProgress {
                VStack {
                    ProgressView(value: viewModel.dataProgress, total: 1)
                        .progressViewStyle(
                            LinearProgressViewStyle(tint: appTheme.colors.primaryOrangeColor)
                        )

                    Spacer()
                }
            }

            if viewModel.isMapBusy {
                VStack {
                    ProgressView()
                        .frame(alignment: .center)
                }
            }

            VStack {
                HStack {
                    VStack(spacing: 0) {
                        Button {
                            openIncidentSelect.toggle()
                        } label: {
                            IncidentDisasterImage(viewModel.incidentsData.selected)
                        }
                        .sheet(isPresented: $openIncidentSelect) {
                            incidentSelectViewBuilder.incidentSelectView( onDismiss: {openIncidentSelect = false} )
                        }
                        .disabled(viewModel.incidentsData.incidents.isEmpty)

                        MapControls(
                            viewModel: viewModel,
                            map: map,
                            animateToSelectedIncidentBounds: animateToSelectedIncidentBounds
                        )

                        Spacer()

                    }
                    VStack {
                        HStack {
                            Spacer()

                            let (casesCount, totalCount) = viewModel.casesCount
                            if totalCount >= 0 {
                                Text(casesCountText(casesCount, totalCount))
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(appTheme.colors.navigationContainerColor)
                                    .foregroundColor(Color.white)
                                    .cornerRadius(appTheme.cornerRadius)
                            }

                            Spacer()

                            Button {
                                router.openSearchCases()
                            } label: {
                                Image("ic_search", bundle: .module)
                                    .background(Color.white)
                                    .foregroundColor(Color.black)
                                    .cornerRadius(appTheme.cornerRadius)
                            }

                            Button {
                                router.openFilterCases()
                            } label: {
                                // TODO: Use component
                                Image("ic_dials", bundle: .module)
                                    .background(Color.white)
                                    .foregroundColor(Color.black)
                                    .cornerRadius(appTheme.cornerRadius)
                            }

                        }
                        Spacer()
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "plus")
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(Color.black)
                            .cornerRadius(appTheme.cornerRadius)

                        Image("ic_table", bundle: .module)
                            .background(Color.yellow)
                            .foregroundColor(Color.black)
                            .cornerRadius(appTheme.cornerRadius)
                            .padding(.top)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.onViewAppear()
            map.selectedAnnotations = []
        }
        .onDisappear { viewModel.onViewDisappear() }
    }
}

private struct MapControls: View {
    @Environment(\.translator) var t: KeyAssetTranslator

    @ObservedObject var viewModel: CasesViewModel
    var map: MKMapView
    var animateToSelectedIncidentBounds: (LatLngBounds) -> Void

    func zoomDelta(scale: Double) {
        var region = map.region
        let latDelta = region.span.latitudeDelta * scale
        let longDelta = region.span.longitudeDelta * scale
        region.span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: longDelta)
        map.setRegion(region, animated: true)
    }

    var body: some View {
        Image(systemName: "plus")
            .padding()
            .background(Color.white)
            .foregroundColor(Color.black)
            .cornerRadius(appTheme.cornerRadius)
            .padding(.vertical)
            .onTapGesture { zoomDelta(scale: 0.5) }

        Image(systemName: "minus")
            .padding()
            .background(Color.white)
            .foregroundColor(Color.black)
            .cornerRadius(appTheme.cornerRadius)
            .onTapGesture { zoomDelta(scale: 1.5) }

        Image("ic_zoom_incident", bundle: .module)
            .background(Color.white)
            .foregroundColor(Color.black)
            .cornerRadius(appTheme.cornerRadius)
            .padding(.top)
            .onTapGesture {
                map.setCamera(MKMapCamera(lookingAtCenter: map.centerCoordinate, fromDistance: CLLocationDistance(50*1000), pitch: 0.0, heading: 0.0), animated: true)
            }

        Image("ic_zoom_interactive", bundle: .module)
            .background(Color.white)
            .foregroundColor(Color.black)
            .cornerRadius(appTheme.cornerRadius)
            .padding(.top)
            .onTapGesture {
                let bounds = viewModel.incidentLocationBounds.bounds
                animateToSelectedIncidentBounds(bounds)
            }

        Image("ic_layers", bundle: .module)
            .background(Color.white)
            .foregroundColor(Color.black)
            .cornerRadius(appTheme.cornerRadius)
            .padding(.top)
    }
}
