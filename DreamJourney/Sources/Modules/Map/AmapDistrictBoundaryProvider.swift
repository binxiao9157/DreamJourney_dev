import CoreLocation
import Foundation
import UIKit

actor AmapDistrictBoundaryProvider {
    typealias DistrictPayloadLoader = @Sendable (_ keyword: String) async throws -> Data

    static let shared = AmapDistrictBoundaryProvider()

    private let endpoint = URL(string: "https://restapi.amap.com/v3/config/district")!
    private var cache: [String: [FootprintIlluminationRegion]] = [:]
    private var lastRequestDate: Date?
    private var backendPayloadLoader: DistrictPayloadLoader?

    func configureBackendPayloadLoader(_ loader: DistrictPayloadLoader?) {
        backendPayloadLoader = loader
    }

    func regions(
        scope: FootprintIlluminationScope,
        points: [FamilyFootprintPoint],
        generation: FamilyFootprintGeneration = .all
    ) async -> [FootprintIlluminationRegion] {
        let apiKey = AppConfiguration.string(forKey: "AMapWebServiceKey")
            ?? AppConfiguration.string(forKey: "AMapAPIKey")
        guard backendPayloadLoader != nil || apiKey != nil else {
            return []
        }

        let keywords = Self.keywords(scope: scope, points: points, generation: generation)
        guard !keywords.isEmpty else { return [] }

        var resolved: [FootprintIlluminationRegion] = []
        for keyword in keywords {
            let cacheKey = "\(scope.title):\(keyword)"
            if let cached = cache[cacheKey] {
                resolved.append(contentsOf: cached)
                continue
            }

            do {
                let regions = try await requestRegionWithRetry(
                    keyword: keyword,
                    scope: scope,
                    generation: generation,
                    apiKey: apiKey
                )
                if !regions.isEmpty {
                    cache[cacheKey] = regions
                }
                resolved.append(contentsOf: regions)
            } catch {
                continue
            }
        }
        return resolved
    }

    private func requestRegionWithRetry(
        keyword: String,
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        apiKey: String?
    ) async throws -> [FootprintIlluminationRegion] {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let regions = try await requestRegion(
                    keyword: keyword,
                    scope: scope,
                    generation: generation,
                    apiKey: apiKey
                )
                if !regions.isEmpty || attempt == 2 {
                    return regions
                }
            } catch {
                lastError = error
            }
            try await Task.sleep(nanoseconds: UInt64(450_000_000 * (attempt + 1)))
        }
        if let lastError { throw lastError }
        return []
    }

    private func requestRegion(
        keyword: String,
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        apiKey: String?
    ) async throws -> [FootprintIlluminationRegion] {
        try await throttleRequests()
        let payload = try await requestDistrictPayload(keyword: keyword, apiKey: apiKey, retryCount: 2)
        guard payload.status == "1" else { throw AmapDistrictBoundaryError.serviceUnavailable(payload.info) }

        return payload.districts.compactMap { district in
            Self.region(from: district, fallbackName: keyword, scope: scope, generation: generation)
        }
    }

    private func requestDistrictPayload(keyword: String, apiKey: String?, retryCount: Int) async throws -> AmapDistrictResponse {
        if let backendPayloadLoader {
            let data = try await backendPayloadLoader(keyword)
            return try JSONDecoder().decode(AmapDistrictResponse.self, from: data)
        }

        guard let apiKey else {
            return AmapDistrictResponse(status: "0", info: "MISSING_AMAP_KEY", districts: [])
        }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "keywords", value: keyword),
            URLQueryItem(name: "subdistrict", value: "0"),
            URLQueryItem(name: "extensions", value: "all"),
            URLQueryItem(name: "output", value: "JSON")
        ]
        guard let url = components.url else { return AmapDistrictResponse(status: "0", info: "INVALID_URL", districts: []) }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return AmapDistrictResponse(status: "0", info: "HTTP_\(http.statusCode)", districts: [])
        }
        let payload = try JSONDecoder().decode(AmapDistrictResponse.self, from: data)
        if payload.status == "1" || retryCount <= 0 || payload.info != "CUQPS_HAS_EXCEEDED_THE_LIMIT" {
            return payload
        }
        try await Task.sleep(nanoseconds: 750_000_000)
        return try await requestDistrictPayload(keyword: keyword, apiKey: apiKey, retryCount: retryCount - 1)
    }

    private func throttleRequests() async throws {
        if let lastRequestDate {
            let elapsed = Date().timeIntervalSince(lastRequestDate)
            let minimumInterval: TimeInterval = 0.35
            if elapsed < minimumInterval {
                let wait = UInt64((minimumInterval - elapsed) * 1_000_000_000)
                try await Task.sleep(nanoseconds: wait)
            }
        }
        lastRequestDate = Date()
    }

    private static func region(
        from district: AmapDistrict,
        fallbackName: String,
        scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration
    ) -> FootprintIlluminationRegion? {
        let polygons = parsePolyline(district.polyline)
        guard !polygons.isEmpty else { return nil }
        let regionName = district.name ?? fallbackName
        let style = style(for: scope, generation: generation, regionName: regionName)
        let overlays = polygons.map {
            FootprintIlluminationOverlaySpec(coordinates: $0, style: style)
        }
        let center = parseCenter(district.center) ?? center(of: polygons.flatMap { $0 })
        guard let center else { return nil }

        return FootprintIlluminationRegion(
            name: displayName(regionName),
            center: center,
            overlaySpecs: overlays,
            approximateAreaKm2: approximateAreaKm2(polygons.flatMap { $0 }),
            source: .amapDistrict
        )
    }

    private static func keywords(
        scope: FootprintIlluminationScope,
        points: [FamilyFootprintPoint],
        generation: FamilyFootprintGeneration
    ) -> [String] {
        let cityNames = Array(Set(points.map { FootprintIlluminationCatalog.normalizedCityName($0.location) })).sorted()
        switch scope {
        case .city:
            if cityNames.contains("杭州") || cityNames.isEmpty {
                return ["西湖区", "拱墅区", "上城区", "滨江区", "萧山区", "余杭区", "临平区", "富阳区", "临安区", "桐庐县", "建德市", "淳安县"]
            }
            return cityNames
        case .nation:
            return cityNames.filter { isMainlandDistrictKeyword($0) }
        case .world:
            let countries = Set(points.map {
                FootprintIlluminationCatalog.countryName(latitude: $0.latitude, longitude: $0.longitude, location: $0.location)
            })
            return countries.contains("中国") ? ["中国"] : []
        }
    }

    private static func parsePolyline(_ value: String?) -> [[CLLocationCoordinate2D]] {
        guard let value, !value.isEmpty else { return [] }
        return value.split(separator: "|").compactMap { part in
            let coordinates = part.split(separator: ";").compactMap { raw -> CLLocationCoordinate2D? in
                let fields = raw.split(separator: ",")
                guard fields.count == 2,
                      let longitude = CLLocationDegrees(fields[0]),
                      let latitude = CLLocationDegrees(fields[1]) else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            return coordinates.count >= 3 ? coordinates : nil
        }
    }

    private static func parseCenter(_ value: String?) -> CLLocationCoordinate2D? {
        guard let value else { return nil }
        let fields = value.split(separator: ",")
        guard fields.count == 2,
              let longitude = CLLocationDegrees(fields[0]),
              let latitude = CLLocationDegrees(fields[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func center(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }
        let latitude = coordinates.reduce(0) { $0 + $1.latitude } / Double(coordinates.count)
        let longitude = coordinates.reduce(0) { $0 + $1.longitude } / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func approximateAreaKm2(_ coordinates: [CLLocationCoordinate2D]) -> Int {
        guard let minLatitude = coordinates.map(\.latitude).min(),
              let maxLatitude = coordinates.map(\.latitude).max(),
              let minLongitude = coordinates.map(\.longitude).min(),
              let maxLongitude = coordinates.map(\.longitude).max() else {
            return 0
        }
        let latKm = max(0.1, abs(maxLatitude - minLatitude) * 111.0)
        let lonKm = max(0.1, abs(maxLongitude - minLongitude) * 111.0 * cos((minLatitude + maxLatitude) * .pi / 360))
        return max(1, Int(latKm * lonKm * 0.58))
    }

    private static func style(
        for scope: FootprintIlluminationScope,
        generation: FamilyFootprintGeneration,
        regionName: String
    ) -> FootprintIlluminationStyle {
        switch generation {
        case .ancestors:
            return .ancestorFill
        case .parents:
            return .parentFill
        case .current:
            return .currentFill
        case .next:
            return .futureFill
        case .all:
            if regionName.contains("绍兴") {
                return .ancestorFill
            }
            if regionName.contains("浙江") {
                return .parentFill
            }
            if regionName.contains("江苏") || regionName.contains("上海") || regionName.contains("广东") {
                return .currentFill
            }
        }
        switch scope {
        case .city: return .cityFill
        case .nation: return .nationFill
        case .world: return .worldFill
        }
    }

    private static func displayName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "区", with: "")
            .replacingOccurrences(of: "县", with: "")
    }

    private static func isMainlandDistrictKeyword(_ keyword: String) -> Bool {
        !keyword.contains("温哥华") && !keyword.contains("新加坡") && !keyword.contains("香港")
    }
}

private enum AmapDistrictBoundaryError: Error {
    case serviceUnavailable(String?)
}

private struct AmapDistrictResponse: Decodable {
    let status: String
    let info: String?
    let districts: [AmapDistrict]
}

private struct AmapDistrict: Decodable {
    let name: String?
    let center: String?
    let polyline: String?
}
