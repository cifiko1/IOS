import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var isRunning = false
    @State private var startTime = Date()
    @State private var lapStartTime = Date()
    @State private var sectorStartTime = Date()
    @State private var totalTime = "00:00:00"
    @State private var currentLap = "00:00:00"
    @State private var bestLap = "00:00:00"
    @State private var lapTimes: [String] = []
    @State private var sectorTimes: [[String]] = []
    @State private var bestLapTime: TimeInterval = .infinity
    @State private var lapCount = 0
    @State private var sectorCount = 0
    @State private var timer: Timer?
    @State private var isFirstLap = true
    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var sectorMarkers: [CLLocationCoordinate2D] = []
    @State private var sessions: [LocationSession] = []
    @State private var showAnalytics = false
    @State private var showComparison = false
    @State private var showComparisonResults = false
    @State private var showHistory = false
    @State private var showOnboarding = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Add state for selected sessions
    @State private var selectedSessions: [UUID] = []

    var body: some View {
        NavigationView {
            ZStack {
                Color(isDarkMode ? .black : .white)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // App Name at the Top Center
                    Text("MX StopWatch GPS")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    // Total Time
                    Text(" \(totalTime)")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.top, 10)

                    // Current Lap
                    Text("Current Lap: \(currentLap)")
                        .font(.system(size: 18))
                        .padding(.top, 10)

                    // Best Lap
                    Text("Best Lap: \(bestLap)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.top, 10)

                    // First Row of Buttons (Start/Stop and Reset)
                    HStack {
                        Button(action: {
                            if isRunning {
                                stopStopwatch()
                            } else {
                                startStopwatch()
                            }
                        }) {
                            Text(isRunning ? "Stop" : "Start")
                                .frame(width: 114, height: 40)
                                .background(isRunning ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            saveSession()
                        }) {
                            Text("Reset")
                                .frame(width: 114, height: 40)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)

                    // Second Row of Buttons (Lap and Sector)
                    HStack {
                        Button(action: {
                            addLap()
                        }) {
                            Text("Lap")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            addSector()
                        }) {
                            Text("Sector")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)

                    // Scrollable List for Sectors and Laps
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                // Display sectors for the current lap (if any)
                                if !sectorTimes.isEmpty && !sectorTimes[0].isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Lap Sectors")
                                            .font(.system(size: 16, weight: .bold))
                                            .padding(.vertical, 4)

                                        // Display sectors in reverse order (most recent first)
                                        ForEach(sectorTimes[0], id: \.self) { sectorTime in
                                            Text(sectorTime)
                                                .font(.system(size: 14))
                                                .padding(.leading, 16)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }

                                // Display completed laps and their sectors
                                ForEach(lapTimes.indices, id: \.self) { index in
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Lap time
                                        Text(lapTimes[index])
                                            .font(.system(size: 16, weight: .bold))
                                            .padding(.vertical, 4)

                                        // Sector times for this lap (in reverse order)
                                        if sectorTimes.count > index + 1 {
                                            ForEach(sectorTimes[index + 1], id: \.self) { sectorTime in
                                                Text(sectorTime)
                                                    .font(.system(size: 14))
                                                    .padding(.leading, 16)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 16)
                        }
                        .frame(maxHeight: .infinity)

                        // Bottom-right corner buttons (Open Map, GPS, Analytics, Comparison, History)
                        VStack(alignment: .trailing, spacing: 8) {
                            Button(action: {
                                showAnalytics = true
                                print("Show Analytics: \(showAnalytics)") // Debugging
                            }) {
                                Text("Analytics")
                                    .frame(width: 80, height: 30)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: $showAnalytics) {
                                LocationAnalyticsView(sessions: $sessions, saveSessions: saveSessions)
                            }

                            NavigationLink(destination: MapScreen(
                                mapRegion: $mapRegion,
                                sectorMarkers: $sectorMarkers,
                                onMarkStartFinish: {
                                    addLap() // Trigger start/finish lap
                                },
                                onMarkSector: {
                                    addSector() // Trigger sector
                                }
                            )) {
                                Text("Map")
                                    .frame(width: 80, height: 30)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                locationManager.toggleGPS()
                            }) {
                                Text(locationManager.isGPSEnabled ? "GPS Off" : "GPS On")
                                    .frame(width: 80, height: 30)
                                    .background(locationManager.isGPSEnabled ? Color.green : Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                showComparison = true
                                print("Sessions: \(sessions)") // Debugging
                                print("Selected Sessions: \(selectedSessions)") // Debugging
                            }) {
                                Text("Compare")
                                    .frame(width: 80, height: 30)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: $showComparison) {
                                SessionSelectionView(sessions: $sessions, selectedSessions: $selectedSessions)
                            }
                            .onChange(of: selectedSessions) { newValue in
                                if !newValue.isEmpty {
                                    showComparisonResults = true
                                }
                            }
                            .sheet(isPresented: $showComparisonResults) {
                                CompareView(sessions: $sessions, selectedSessions: $selectedSessions)
                            }

                            Button(action: {
                                showHistory = true
                            }) {
                                Text("History")
                                    .frame(width: 80, height: 30)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .sheet(isPresented: $showHistory) {
                                HistoryView(sessions: $sessions)
                            }
                        }
                        .padding(.bottom, 16)
                        .padding(.trailing, 16)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true) // Hide the navigation bar
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // MARK: - Stopwatch Functions
    private func startStopwatch() {
        if !isRunning {
            isRunning = true
            startTime = Date()
            lapStartTime = Date()
            sectorStartTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                updateTime()
            }
        }
    }

    private func stopStopwatch() {
        isRunning = false
        timer?.invalidate()
    }

    private func resetStopwatch() {
        isRunning = false
        timer?.invalidate()
        startTime = Date()
        lapStartTime = Date()
        sectorStartTime = Date()
        totalTime = "00:00:00"
        currentLap = "00:00:00"
        bestLap = "00:00:00"
        lapTimes.removeAll()
        sectorTimes.removeAll()
        bestLapTime = .infinity
        lapCount = 0
        sectorCount = 0
        isFirstLap = true
    }

    private func updateTime() {
        let currentTime = Date().timeIntervalSince(startTime)
        let lapTime = Date().timeIntervalSince(lapStartTime)
        totalTime = formatTime(currentTime)
        currentLap = formatTime(lapTime)
    }

    private func addLap() {
        if isRunning {
            let lapTime = Date().timeIntervalSince(lapStartTime)
            if lapTime < bestLapTime {
                bestLapTime = lapTime
                bestLap = formatTime(bestLapTime)
            }
            lapCount += 1
            lapTimes.insert("Lap \(lapCount): \(formatTime(lapTime))", at: 0)
            
            // Add a new empty array for the new lap's sectors
            sectorTimes.insert([], at: 0)
            
            lapStartTime = Date()
            sectorStartTime = Date()
            sectorCount = 0 // Reset sector count for the new lap
        }
    }

    private func addSector() {
        if isRunning {
            // Ensure sectorTimes has an array for the current lap
            if sectorTimes.isEmpty {
                sectorTimes.append([])
            }
            
            let sectorTime = Date().timeIntervalSince(sectorStartTime)
            sectorCount += 1
            sectorTimes[0].insert("Sector \(sectorCount): \(formatTime(sectorTime))", at: 0)
            sectorStartTime = Date()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
    }

    // MARK: - Session Management
    private func saveSession() {
        guard !lapTimes.isEmpty else { return }
        
        let fastestLap = bestLap
        let slowestLap = lapTimes.map { $0.components(separatedBy: ": ").last ?? "00:00:00" }.max() ?? "00:00:00"
        let averageLap = calculateAverageLap()
        let consistency = calculateConsistency()
        
        let currentTotalTime = totalTime
        
        let location = locationManager.userLocation?.coordinate
        
        if let location = location {
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                let cityName = placemarks?.first?.locality
                
                let session = LocationSession(
                    id: UUID(),
                    date: Date(),
                    fastestLap: fastestLap,
                    slowestLap: slowestLap,
                    averageLap: averageLap,
                    consistency: consistency,
                    lapTimes: lapTimes,
                    sectorTimes: sectorTimes, // Nested array for sectors per lap
                    location: cityName,
                    totalTime: currentTotalTime
                )
                
                sessions.append(session)
                print("Session saved: \(session)") // Debugging
                saveSessions(sessions)
                resetStopwatch()
            }
        } else {
            let session = LocationSession(
                id: UUID(),
                date: Date(),
                fastestLap: fastestLap,
                slowestLap: slowestLap,
                averageLap: averageLap,
                consistency: consistency,
                lapTimes: lapTimes,
                sectorTimes: sectorTimes, // Nested array for sectors per lap
                location: nil,
                totalTime: currentTotalTime
            )
            
            sessions.append(session)
            print("Session saved: \(session)") // Debugging
            saveSessions(sessions)
            resetStopwatch()
        }
    }

    private func calculateAverageLap() -> String {
        guard !lapTimes.isEmpty else { return "00:00:00" }
        
        let totalLapTime = lapTimes.reduce(0) { result, lapTime in
            let timeString = lapTime.components(separatedBy: ": ").last ?? "00:00:00"
            let components = timeString.components(separatedBy: ":")
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1]) ?? 0
            let milliseconds = Int(components[2]) ?? 0
            return result + TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 100
        }
        
        let averageLapTime = totalLapTime / Double(lapTimes.count)
        return formatTime(averageLapTime)
    }

    private func calculateConsistency() -> String {
        guard lapTimes.count > 1 else { return "N/A" }
        
        let lapTimesInSeconds = lapTimes.map { lapTime in
            let timeString = lapTime.components(separatedBy: ": ").last ?? "00:00:00"
            let components = timeString.components(separatedBy: ":")
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1]) ?? 0
            let milliseconds = Int(components[2]) ?? 0
            return TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 100
        }
        
        let averageLapTime = lapTimesInSeconds.reduce(0, +) / Double(lapTimes.count)
        let variance = lapTimesInSeconds.reduce(0) { result, lapTime in
            result + pow(lapTime - averageLapTime, 2)
        } / Double(lapTimes.count)
        
        let standardDeviation = sqrt(variance)
        let referenceStandardDeviation: TimeInterval = 7.0
        let consistencyPercentage = 100 * (1 - (standardDeviation / referenceStandardDeviation))
        let clampedConsistency = max(1, min(100, consistencyPercentage))
        
        return String(format: "%.0f%%", clampedConsistency)
    }

    // MARK: - Persistence
    private func saveSessions(_ sessions: [LocationSession]) {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }
    }

    private func loadSessions() -> [LocationSession] {
        if let data = UserDefaults.standard.data(forKey: "savedSessions"),
           let decoded = try? JSONDecoder().decode([LocationSession].self, from: data) {
            return decoded
        }
        return []
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
