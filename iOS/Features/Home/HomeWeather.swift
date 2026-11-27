import CoreLocation
import Observation
import SwiftUI

struct WeatherCity: Identifiable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double

    static let options = [
        WeatherCity(id: "杭州", latitude: 30.27, longitude: 120.15),
        WeatherCity(id: "北京", latitude: 39.90, longitude: 116.41),
        WeatherCity(id: "上海", latitude: 31.23, longitude: 121.47),
        WeatherCity(id: "广州", latitude: 23.13, longitude: 113.26),
        WeatherCity(id: "成都", latitude: 30.57, longitude: 104.07),
        WeatherCity(id: "苏州", latitude: 31.30, longitude: 120.59),
        WeatherCity(id: "厦门", latitude: 24.48, longitude: 118.09)
    ]
}

@MainActor
@Observable
final class HomeWeather: NSObject, CLLocationManagerDelegate {
    struct Reading: Decodable {
        let temperature_2m: Double
        let weather_code: Int

        var description: String {
            switch weather_code {
            case 0: "晴"
            case 1...3: "多云"
            case 45...48: "雾"
            case 51...67, 80...82: "雨"
            case 71...77, 85...86: "雪"
            case 95...99: "雷雨"
            default: "天气"
            }
        }

        var symbol: String {
            switch weather_code {
            case 0: "sun.max"
            case 1...3: "cloud.sun"
            case 45...48: "cloud.fog"
            case 71...77, 85...86: "snowflake"
            case 95...99: "cloud.bolt.rain"
            default: "cloud.rain"
            }
        }
    }

    private struct Response: Decodable { let current: Reading }
    private let manager = CLLocationManager()
    private var request: Task<Void, Never>?
    private var wantsLocation = false
    var reading: Reading?
    var locating = false
    var message: String?
    var currentCity: WeatherCity?

    func load(_ city: WeatherCity) {
        request?.cancel()
        reading = nil
        message = nil
        let latitude = (city.latitude * 100).rounded() / 100
        let longitude = (city.longitude * 100).rounded() / 100
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,weather_code")
        ]
        request = Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url.url!, timeoutInterval: 12))
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let result = try JSONDecoder().decode(Response.self, from: data)
                guard !Task.isCancelled else { return }
                reading = result.current
            } catch {
                if !Task.isCancelled { message = "天气暂不可用" }
            }
        }
    }

    func locate() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        wantsLocation = true
        resolveAuthorization()
    }

    private func resolveAuthorization() {
        guard wantsLocation else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard !locating else { return }
            locating = true
            manager.requestLocation()
        default:
            wantsLocation = false
            message = "可手动选择城市"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.resolveAuthorization() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latitude = locations.last?.coordinate.latitude
        let longitude = locations.last?.coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self else { return }
            locating = false
            wantsLocation = false
            guard let latitude, let longitude else {
                message = "定位未成功，可手动选城市"
                return
            }
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN"))
            let name = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea ?? "当前位置"
            currentCity = WeatherCity(id: name, latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locating = false
            self?.wantsLocation = false
            self?.message = "定位未成功，可手动选城市"
        }
    }
}

struct HomeWeatherBar: View {
    @AppStorage("yuto.weather.city") private var preferred = WeatherCity.options[0].id
    @State private var weather = HomeWeather()
    @State private var usesLocation = false

    private var city: WeatherCity {
        if usesLocation, let current = weather.currentCity { return current }
        return WeatherCity.options.first { $0.id == preferred } ?? WeatherCity.options[0]
    }

    var body: some View {
        Menu {
            Button("使用当前位置", systemImage: "location") {
                usesLocation = true
                weather.locate()
            }
            ForEach(WeatherCity.options) { option in
                Button(option.id) {
                    usesLocation = false
                    preferred = option.id
                    weather.load(option)
                }
            }
            if let message = weather.message { Text(message) }
            Button("刷新天气", systemImage: "arrow.clockwise") { weather.load(city) }
            Link("天气由 Open-Meteo 提供", destination: URL(string: "https://open-meteo.com/")!)
        } label: {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill").font(.caption2)
                    Text(city.id)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                if weather.locating {
                    Text("正在定位").font(.footnote)
                } else if let reading = weather.reading {
                    Label("\(Int(reading.temperature_2m.rounded()))° · \(reading.description)", systemImage: reading.symbol)
                        .font(.footnote).foregroundStyle(YutoTheme.muted)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .foregroundStyle(YutoTheme.sage)
        .accessibilityLabel("天气城市，\(city.id)")
        .accessibilityValue(weather.reading.map { "\(Int($0.temperature_2m.rounded()))度，\($0.description)" } ?? weather.message ?? "正在更新")
        .task { weather.load(city) }
        .onChange(of: weather.currentCity) { _, _ in if usesLocation { weather.load(city) } }
    }
}
