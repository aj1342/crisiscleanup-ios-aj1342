extension MainComponent {
    var appDatabase: AppDatabase { shared { .shared } }

    var languageDao: LanguageDao {
        LanguageDao(appDatabase)
    }

    var incidentDao: IncidentDao {
        IncidentDao(appDatabase)
    }

    var locationDao: LocationDao {
        LocationDao(appDatabase)
    }

    public var incidentsRepository: IncidentsRepository {
        shared {
            OfflineFirstIncidentsRepository(
                dataSource: networkDataSource,
                appPreferencesDataStore: appPreferences,
                incidentDao: incidentDao,
                locationDao: locationDao,
                loggerFactory: loggerFactory
            )
        }
    }

    public var workTypeStatusRepository: WorkTypeStatusRepository {
        shared {
            CrisisCleanupWorkTypeStatusRepository(
                dataSource: networkDataSource,
                loggerFactory: loggerFactory
            )
        }
    }
    public var languageTranslationsRepository: LanguageTranslationsRepository {
        shared {
            OfflineFirstLanguageTranslationsRepository(
                dataSource: networkDataSource,
                appPreferencesDataStore: appPreferences,
                languageDao: languageDao,
                statusRepository: workTypeStatusRepository,
                loggerFactory: loggerFactory
            )
        }
    }
}