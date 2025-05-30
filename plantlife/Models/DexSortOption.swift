import Foundation

// Sort options for Dex entries
enum DexSortOption: String, CaseIterable, Identifiable {
    case numberAsc = "numberAsc"
    case numberDesc = "numberDesc"
    case alphaAsc = "alphaAsc"
    case alphaDesc = "alphaDesc"
    case dateAsc = "dateAsc"
    case dateDesc = "dateDesc"
    
    var id: String { self.rawValue }
}

// Extension to work with DexRepository
extension DexRepository {
    func sort(_ entries: [DexEntry], by option: DexSortOption) -> [DexEntry] {
        switch option {
        case .numberAsc:
            return entries.sorted { $0.id < $1.id }
        case .numberDesc:
            return entries.sorted { $0.id > $1.id }
        case .alphaAsc:
            return entries.sorted { $0.latinName < $1.latinName }
        case .alphaDesc:
            return entries.sorted { $0.latinName > $1.latinName }
        case .dateAsc:
            return entries.sorted { $0.createdAt < $1.createdAt }
        case .dateDesc:
            return entries.sorted { $0.createdAt > $1.createdAt }
        }
    }
}