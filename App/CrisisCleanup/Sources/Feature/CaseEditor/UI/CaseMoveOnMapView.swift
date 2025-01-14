import MapKit
import SwiftUI

struct CaseMoveOnMapView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.translator) var t: KeyAssetTranslator

    @EnvironmentObject var locationManager: LocationManager

    @ObservedObject var viewModel: CaseMoveOnMapViewModel

    @State var map = MKMapView()
    // TODO: Read initial coordinates from view model
    @State var caseCoordinates = CLLocationCoordinate2D(
        latitude: -81.0,
        longitude: 24.0
    )
    @State var temp = ""

    var body: some View {
        VStack {
            TextField(t.t("caseView.full_address"), text: $temp)
                .textFieldBorder()
                .padding(.horizontal)

//            CreateEditCaseMapView(
//                map: $map,
//                caseCoordinates: $caseCoordinates
//            )

            HStack {
                Button {
                    map.centerCoordinate = map.userLocation.coordinate
                } label: {
                    Image("ic_use_my_location", bundle: .module)
                    Text(t.t("caseForm.use_my_location"))
                }
                .padding(.leading)
                Spacer()
            }

            // For debugging
//            Text(map.centerCoordinate.latLng.description)
//            Text(caseCoordinates.latLng.description)

            HStack{
                Button {
                    dismiss()
                } label: {
                    Text(t.t("actions.cancel"))
                }
                .styleCancel()

                Button {
                    caseCoordinates = map.centerCoordinate
                } label: {
                    Text(t.t("actions.save"))
                }
                .stylePrimary()
            }
            .padding(.horizontal)

        }
        .screenTitle(t.t("caseForm.select_on_map"))
    }
}
