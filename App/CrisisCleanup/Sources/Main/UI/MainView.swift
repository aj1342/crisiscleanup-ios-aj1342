import SwiftUI

struct MainView: View {
    @Environment(\.translator) var translator

    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var router: NavigationRouter
    @ObservedObject var appAlerts: AppAlertViewState

    let locationManager: LocationManager

    let authenticateViewBuilder: AuthenticateViewBuilder
    let casesViewBuilder: CasesViewBuilder
    let menuViewBuilder: MenuViewBuilder
    let casesFilterViewBuilder: CasesFilterViewBuilder
    let casesSearchViewBuilder: CasesSearchViewBuilder
    let viewCaseViewBuilder: ViewCaseViewBuilder
    let caseAddNoteViewBuilder: CaseAddNoteViewBuilder
    let createEditCaseViewBuilder: CreateEditCaseViewBuilder
    let caseShareViewBuilder: CaseShareViewBuilder
    let caseFlagsViewBuilder: CaseFlagsViewBuilder
    let caseHistoryViewBuilder: CaseHistoryViewBuilder
    let transferWorkTypeViewBuilder: TransferWorkTypeViewBuilder
    let viewImageViewBuilder: ViewImageViewBuilder
    let caseSearchLocationViewBuilder: CaseSearchLocationViewBuilder
    let caseMoveOnMapViewBuilder: CaseMoveOnMapViewBuilder
    let userFeedbackViewBuilder: UserFeedbackViewBuilder
    let syncInsightsViewBuilder: SyncInsightsViewBuilder

    @State var showAuthScreen = false

    @State private var selectedTab = TopLevelDestination.cases

    var body: some View {
        Group {
            switch viewModel.viewData.state {
            case .loading:
                // TODO: Show actual splash screen (or loading animation)
                Text("Splash/loading")
            case .ready:
                let hideAuthScreen = {
                    showAuthScreen = false

                }
                if showAuthScreen || !viewModel.viewData.showMainContent {
                    authenticateViewBuilder.authenticateView(dismissScreen: hideAuthScreen)
                        .navigationBarHidden(true)
                } else {
                    let navColor = appTheme.colors.navigationContainerColor
                    NavigationStack(path: $router.path) {
                        ZStack {
                            navColor.ignoresSafeArea()
                            VStack {
                                // TODO: Why is a view required to change system bar (and tab bar) backgrounds?
                                Rectangle()
                                    .fill(.clear)
                                    .frame(height: 0)
                                    .background(.clear)

                                TabView(selection: $selectedTab) {
                                    Group {
                                        let openAuthScreen = {
                                            showAuthScreen = true
                                        }
                                        MainTabs(
                                            viewModel: viewModel,
                                            openAuthScreen: openAuthScreen,
                                            casesViewBuilder: casesViewBuilder,
                                            menuViewBuilder: menuViewBuilder,
                                            casesFilterViewBuilder: casesFilterViewBuilder,
                                            casesSearchViewBuilder: casesSearchViewBuilder,
                                            viewCaseViewBuilder: viewCaseViewBuilder,
                                            caseAddNoteViewBuilder: caseAddNoteViewBuilder,
                                            createEditCaseViewBuilder: createEditCaseViewBuilder,
                                            caseShareViewBuilder: caseShareViewBuilder,
                                            caseFlagsViewBuilder: caseFlagsViewBuilder,
                                            caseHistoryViewBuilder: caseHistoryViewBuilder,
                                            transferWorkTypeViewBuilder: transferWorkTypeViewBuilder,
                                            viewImageViewBuilder: viewImageViewBuilder,
                                            caseSearchLocationViewBuilder: caseSearchLocationViewBuilder,
                                            caseMoveOnMapViewBuilder: caseMoveOnMapViewBuilder,
                                            userFeedbackViewBuilder: userFeedbackViewBuilder,
                                            syncInsightsViewBuilder: syncInsightsViewBuilder
                                        )
                                    }
                                }
                                .tabViewStyle(
                                    backgroundColor: appTheme.colors.navigationContainerColor,
                                    selectedItemColor: .white
                                )
                            }
                        }
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(.light, for: .navigationBar)
                    }
                }
            }
        }
        .onAppear { viewModel.onViewAppear() }
        .onDisappear { viewModel.onViewDisappear() }
        .environment(\.translator, viewModel.translator)
        .environment(\.font, .bodyLarge)
        .environmentObject(router)
        .environmentObject(appAlerts)
        .environmentObject(locationManager)
    }
}

private struct TabViewContainer<Content: View>: View {
    let backgroundColor: Color

    private let content: Content

    init(
        backgroundColor: Color = appTheme.colors.navigationContainerColor,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack {
                content
            }
        }
    }
}

private struct MainTabs: View {
    @ObservedObject var viewModel: MainViewModel
    let openAuthScreen: () -> Void
    let casesViewBuilder: CasesViewBuilder
    let menuViewBuilder: MenuViewBuilder
    let casesFilterViewBuilder: CasesFilterViewBuilder
    let casesSearchViewBuilder: CasesSearchViewBuilder
    let viewCaseViewBuilder: ViewCaseViewBuilder
    let caseAddNoteViewBuilder: CaseAddNoteViewBuilder
    let createEditCaseViewBuilder: CreateEditCaseViewBuilder
    let caseShareViewBuilder: CaseShareViewBuilder
    let caseFlagsViewBuilder: CaseFlagsViewBuilder
    let caseHistoryViewBuilder: CaseHistoryViewBuilder
    let transferWorkTypeViewBuilder: TransferWorkTypeViewBuilder
    let viewImageViewBuilder: ViewImageViewBuilder
    let caseSearchLocationViewBuilder: CaseSearchLocationViewBuilder
    let caseMoveOnMapViewBuilder: CaseMoveOnMapViewBuilder
    let userFeedbackViewBuilder: UserFeedbackViewBuilder
    let syncInsightsViewBuilder: SyncInsightsViewBuilder

    var body: some View {
        TabViewContainer {
            casesViewBuilder.casesView(openAuthScreen)
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .filterCases:
                        casesFilterViewBuilder.casesFilterView
                    case .searchCases:
                        casesSearchViewBuilder.casesSearchView
                            .navigationBarHidden(true)
                    case .viewCase(let incidentId, let worksiteId):
                        viewCaseViewBuilder.viewCaseView(
                            incidentId: incidentId,
                            worksiteId: worksiteId
                        )
                    case .caseAddNote:
                        caseAddNoteViewBuilder.caseAddNoteView
                    case .createEditCase(let incidentId, let worksiteId):
                        createEditCaseViewBuilder.createEditCaseView(
                            incidentId: incidentId,
                            worksiteId: worksiteId
                        )
                    case .caseSearchLocation:
                        caseSearchLocationViewBuilder.caseSearchLocationView
                    case .caseMoveOnMap:
                        caseMoveOnMapViewBuilder.caseMoveOnMapView
                    case .caseShare:
                        caseShareViewBuilder.caseShareView
                    case .caseShareStep2:
                        caseShareViewBuilder.caseShareStep2View
                    case .caseFlags(let isFromCaseEdit):
                        caseFlagsViewBuilder.caseFlagsView(isFromCaseEdit: isFromCaseEdit)
                    case .caseHistory:
                        caseHistoryViewBuilder.caseHistoryView
                    case .caseWorkTypeTransfer:
                        transferWorkTypeViewBuilder.transferWorkTypeView
                    case .viewImage(let imageId, let isNetworkImage, let screenTitle):
                        viewImageViewBuilder.viewImageView(imageId, isNetworkImage, screenTitle)
                    case .userFeedback:
                        userFeedbackViewBuilder.userFeedbackView
                    case .syncInsights:
                        if viewModel.isNotProduction {
                            syncInsightsViewBuilder.syncInsightsView
                        }
                    default:
                        Text("Route \(route.id) needs implementing")
                    }
                }
        }
        .navTabItem(.cases, viewModel.translator)
        .tag(TopLevelDestination.cases)

        TabViewContainer {
            menuViewBuilder.menuView(openAuthScreen)
        }
        .navTabItem(.menu, viewModel.translator)
        .tag(TopLevelDestination.menu)
    }
}
