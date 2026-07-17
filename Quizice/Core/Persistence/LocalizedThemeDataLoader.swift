import CryptoKit
import Foundation

struct LocalizedThemeDataLoader {
    struct LoadedData {
        let languageCode: String
        let hash: String
        let themes: [QuizTheme]
    }

    func load() throws -> LoadedData {
        guard let url = localizedDataURL() else {
            throw ThemeDataError.localizedJSONNotFound
        }
        let data = try Data(contentsOf: url)
        let decodedData = try JSONDecoder().decode([QuizThemeDTO].self, from: data)
        return LoadedData(
            languageCode: AppLocalizationStore.shared.resolvedLanguageCode,
            hash: sha256Hash(for: data),
            themes: decodedData.map { $0.makeModel() }
        )
    }

    private func localizedDataURL() -> URL? {
        AppLocalizationStore.shared.localizedBundle.url(
            forResource: ThemeCatalogRepository.Content.dataResourceName,
            withExtension: ThemeCatalogRepository.Content.dataResourceExtension
        ) ?? Bundle.main.url(
            forResource: ThemeCatalogRepository.Content.dataResourceName,
            withExtension: ThemeCatalogRepository.Content.dataResourceExtension
        )
    }

    private func sha256Hash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum ThemeDataError: Error {
    case localizedJSONNotFound
}
