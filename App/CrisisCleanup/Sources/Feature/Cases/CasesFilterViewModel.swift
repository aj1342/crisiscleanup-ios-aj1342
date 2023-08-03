import Atomics
import Combine
import SwiftUI

class CasesFilterViewModel: ObservableObject {
    private let workTypeStatusRepository: WorkTypeStatusRepository
    private let casesFilterRepository: CasesFilterRepository
    private let incidentSelector: IncidentSelector
    private let incidentsRepository: IncidentsRepository
    private let languageRepository: LanguageTranslationsRepository
    let translator: KeyTranslator
    private let logger: AppLogger

    @Published private(set) var casesFilters: CasesFilter = CasesFilter()

    @Published private(set) var workTypeStatuses = [WorkTypeStatus]()

    @Published private(set) var worksiteFlags = [WorksiteFlagType]()

    @Published private(set) var workTypes = [String]()

    let collapsibleFilterSections: [CollapsibleFilterSection] = [
        .distance,
        .general,
        .personalInfo,
        .flags,
        .work,
        .dates
    ]
    let filterSectionTitles: [String]
    let indexedTitles: [(Int, String)]

    let distanceOptions: [(Double, String)]

    private var distanceOptionCached = ManagedAtomic<AtomicDoubleOptional>(AtomicDoubleOptional())

    private var subscriptions = Set<AnyCancellable>()

    init(
        workTypeStatusRepository: WorkTypeStatusRepository,
        casesFilterRepository: CasesFilterRepository,
        incidentSelector: IncidentSelector,
        incidentsRepository: IncidentsRepository,
        languageRepository: LanguageTranslationsRepository,
        translator: KeyTranslator,
        loggerFactory: AppLoggerFactory
    ) {
        self.workTypeStatusRepository = workTypeStatusRepository
        self.casesFilterRepository = casesFilterRepository
        self.incidentSelector = incidentSelector
        self.incidentsRepository = incidentsRepository
        self.languageRepository = languageRepository
        self.translator = translator
        logger = loggerFactory.getLogger("filter-cases")

        let sectionTranslationKey: [CollapsibleFilterSection: String] = [
            .distance: "worksiteFilters.distance",
            .general: "worksiteFilters.general",
            .personalInfo: "worksiteFilters.personal_info",
            .flags: "worksiteFilters.flags",
            .work: "worksiteFilters.work",
            .dates: "worksiteFilters.dates",
        ]
        filterSectionTitles = collapsibleFilterSections.map { section in
            if let sectionKey = sectionTranslationKey[section] {
                return translator.t(sectionKey)
            }
            return ""
        }
        indexedTitles = Array(filterSectionTitles.enumerated())

        distanceOptions = [
            (0, translator.t("worksiteFilters.any_distance")),
            (0.3, translator.t("worksiteFilters.point_3_miles")),
            (1, translator.t("worksiteFilters.one_mile")),
            (5, translator.t("worksiteFilters.five_miles")),
            (20, translator.t("worksiteFilters.twenty_miles")),
            (50, translator.t("worksiteFilters.fifty_miles")),
            (100, translator.t("worksiteFilters.one_hundred_miles")),
        ]

        worksiteFlags = WorksiteFlagType.allCases.sorted(by: { a, b in
            a.literal.localizedCompare(b.literal) == .orderedAscending
        })
    }

    func onViewAppear() {
        subscribeToFilterData()
    }

    func onViewDisappear() {
        subscriptions = cancelSubscriptions(subscriptions)
    }

    private func subscribeToFilterData() {
        casesFilterRepository.casesFilters
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .assign(to: \.casesFilters, on: self)
            .store(in: &subscriptions)

        workTypeStatusRepository.workTypeStatusFilterOptions
            .eraseToAnyPublisher()
            .receive(on: RunLoop.main)
            .assign(to: \.workTypeStatuses, on: self)
            .store(in: &subscriptions)

        incidentSelector.incidentId
            .eraseToAnyPublisher()
            .map { id in self.incidentsRepository.streamIncident(id).eraseToAnyPublisher() }
            .switchToLatest()
            .eraseToAnyPublisher()
            .map { incident in
                if let formFields = incident?.formFields {
                    let formFieldRootNode = FormFieldNode.buildTree(
                        formFields,
                        self.languageRepository
                    )
                        .map { $0.flatten() }

                    if let node = formFieldRootNode.first(where: { $0.fieldKey == WorkFormGroupKey }) {
                        return node.children.filter { $0.parentKey == WorkFormGroupKey }
                            .map { $0.formField.selectToggleWorkType }
                            .sorted(by: { a, b in a.localizedCompare(b) == .orderedAscending })
                    }
                }
                return []
            }
            .receive(on: RunLoop.main)
            .assign(to: \.workTypes, on: self)
            .store(in: &subscriptions)
    }

    private func changeDistanceFilter() {
        if let distance = distanceOptionCached.exchange(
            AtomicDoubleOptional(),
            ordering: .sequentiallyConsistent
        ).value {
            changeDistanceFilter(distance)
        }
    }

    private func changeDistanceFilter(_ distance: Double) {
        changeFilters(casesFilters.copy { $0.distance = distance })
    }

    func tryChangeDistanceFilter(distance: Double) {
        // TODO: Require permission if not granted. Cache and set later as necessary.
        //        distanceOptionCached.set(distance)
        changeDistanceFilter(distance)
    }

    func changeFilters(_ filters: CasesFilter) {
        casesFilters = filters
    }

    func clearFilters() {
        let filters = CasesFilter()
        changeFilters(filters)
        applyFilters(filters)
    }

    func applyFilters(_ filters: CasesFilter) {
        casesFilterRepository.changeFilters(filters)
    }
}

enum CollapsibleFilterSection {
    case distance,
         general,
         personalInfo,
         flags,
         work,
         dates
}
