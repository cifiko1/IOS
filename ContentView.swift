import SwiftUI
import MapKit
import CoreLocation
import Firebase
import FirebaseDatabase

struct ContentView: View {
    // MARK: - Timer Properties
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
    
    // MARK: - UI State
    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var sectorMarkers: [CLLocationCoordinate2D] = []
    @State private var sessions: [LocationSession] = []
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedSessions: [UUID] = []
    
    // MARK: - Feature Toggles
    @State private var showMenu = false
    @State private var bgColor = Color(.systemBackground)
    @State private var username = UserDefaults.standard.string(forKey: "username") ?? ""
    @State private var autoStartLiveSession = UserDefaults.standard.bool(forKey: "autoStartLiveSession")
    @State private var showWebSessions = false
    @State private var showColorPicker = false
    @State private var showUsernameDialog = false
    @State private var showLiveSessions = false
    @State private var showHistory = false
    @State private var showComparison = false
    @State private var showComparisonResults = false
    @State private var showAnalytics = false
    @State private var showMap = false
    
    private let menuItems = [
        "Live Sessions",
        "Web Upload",
        "History",
        "Compare",
        "Analytics",
        "Map",
        "Auto Start",
        "Background Color",
        "Set Username"
    ]

    var body: some View {
        NavigationView {
            ZStack {
                bgColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Header
                    Text("MX StopWatch GPS")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    // Timer Display
                    Text(" \(totalTime)")
                        .font(.system(size: 30, weight: .bold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.top, 10)

                    Text("Current Lap: \(currentLap)")
                        .font(.system(size: 18))
                        .padding(.top, 10)

                    Text("Best Lap: \(bestLap)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.top, 10)

                    // Control Buttons
                    HStack {
                        Button(action: toggleStopwatch) {
                            Text(isRunning ? "Stop" : "Start")
                                .frame(width: 114, height: 40)
                                .background(isRunning ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: saveAndReset) {
                            Text("Reset")
                                .frame(width: 114, height: 40)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)

                    HStack {
                        Button(action: addLap) {
                            Text("Lap")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: addSector) {
                            Text("Sector")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)

                    // Session List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if !sectorTimes.isEmpty && !sectorTimes[0].isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Lap Sectors")
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(.vertical, 4)

                                    ForEach(sectorTimes[0], id: \.self) { sectorTime in
                                        Text(sectorTime)
                                            .font(.system(size: 14))
                                            .padding(.leading, 16)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }

                            ForEach(lapTimes.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lapTimes[index])
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(.vertical, 4)

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
                }
                .padding()
                
                // FAB Menu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showMenu.toggle() }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.blue))
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .actionSheet(isPresented: $showMenu) {
                ActionSheet(title: Text("Menu"), buttons: menuActionButtons)
            }
            .sheet(isPresented: $showLiveSessions) {
                LiveSessionsView(locationManager: locationManager, isPresented: $showLiveSessions)
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(sessions: $sessions)
            }
            .sheet(isPresented: $showComparison) {
                SessionSelectionView(sessions: $sessions, selectedSessions: $selectedSessions)
            }
            .sheet(isPresented: $showComparisonResults) {
                CompareView(sessions: $sessions, selectedSessions: $selectedSessions)
            }
            .sheet(isPresented: $showAnalytics) {
                LocationAnalyticsView(sessions: $sessions, saveSessions: saveSessions)
            }
            .sheet(isPresented: $showMap) {
                MapScreen(
                    mapRegion: $mapRegion,
                    sectorMarkers: $sectorMarkers,
                    onMarkStartFinish: { addLap() },
                    onMarkSector: { addSector() }
                )
            }
            .alert("Set Username", isPresented: $showUsernameDialog, actions: {
                TextField("Username", text: $username)
                Button("Save", action: saveUsername)
                Button("Cancel", role: .cancel) {}
            })
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onAppear {
                loadSavedSettings()
                checkAutoStart()
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
            }
            .onChange(of: selectedSessions) { newValue in
                if !newValue.isEmpty {
                    showComparisonResults = true
                }
            }
        }
    }
    
    // MARK: - Menu Actions
    private var menuActionButtons: [ActionSheet.Button] {
        menuItems.map { item in
            .default(Text(item), action: { handleMenuSelection(item) })
        } + [.cancel()]
    }
    
    private func handleMenuSelection(_ item: String) {
        switch item {
        case "Live Sessions": showLiveSessions = true
        case "Web Upload": saveSession()
        case "History": showHistory = true
        case "Compare": showComparison = true
        case "Analytics": showAnalytics = true
        case "Map": showMap = true
        case "Auto Start": toggleAutoStart()
        case "Background Color": showColorPickerAlert()
        case "Set Username": showUsernameDialog = true
        default: break
        }
    }
    
    // MARK: - Timer Methods
    private func toggleStopwatch() {
        if isRunning { stopStopwatch() } else { startStopwatch() }
    }
    
    private func startStopwatch() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        lapStartTime = Date()
        sectorStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            updateTime()
        }
    }
    
    private func stopStopwatch() {
        isRunning = false
        timer?.invalidate()
    }
    
    private func saveAndReset() {
        saveSession()
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
    }
    
    private func updateTime() {
        let currentTime = Date().timeIntervalSince(startTime)
        let lapTime = Date().timeIntervalSince(lapStartTime)
        totalTime = formatTime(currentTime)
        currentLap = formatTime(lapTime)
    }
    
    private func addLap() {
        guard isRunning else { return }
        let lapTime = Date().timeIntervalSince(lapStartTime)
        if lapTime < bestLapTime {
            bestLapTime = lapTime
            bestLap = formatTime(bestLapTime)
        }
        lapCount += 1
        lapTimes.insert("Lap \(lapCount): \(formatTime(lapTime))", at: 0)
        sectorTimes.insert([], at: 0)
        lapStartTime = Date()
        sectorStartTime = Date()
        sectorCount = 0
    }
    
    private func addSector() {
        guard isRunning else { return }
        if sectorTimes.isEmpty { sectorTimes.append([]) }
        let sectorTime = Date().timeIntervalSince(sectorStartTime)
        sectorCount += 1
        sectorTimes[0].insert("Sector \(sectorCount): \(formatTime(sectorTime))", at: 0)
        sectorStartTime = Date()
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
        
        let session = LocationSession(
            id: UUID(),
            date: Date(),
            fastestLap: bestLap,
            slowestLap: lapTimes.map { $0.components(separatedBy: ": ").last ?? "00:00:00" }.max() ?? "00:00:00",
            averageLap: calculateAverageLap(),
            consistency: calculateConsistency(),
            lapTimes: lapTimes,
            sectorTimes: sectorTimes,
            location: locationManager.currentLocationName,
            totalTime: totalTime
        )
        
        sessions.append(session)
        saveSessions(sessions)
        uploadSessionToWeb(session)
        resetStopwatch()
    }
    
    private func uploadSessionToWeb(_ session: LocationSession) {
        guard let url = URL(string: "http://your-flask-server.com/upload") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "session_id": session.id.uuidString,
            "duration": session.totalTime,
            "best_lap": session.fastestLap,
            "lap_count": session.lapTimes.count,
            "timestamp": session.date.timeIntervalSince1970
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request).resume()
        } catch {
            print("Upload failed: \(error)")
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
    
    // MARK: - User Preferences
    private func toggleAutoStart() {
        autoStartLiveSession.toggle()
        UserDefaults.standard.set(autoStartLiveSession, forKey: "autoStartLiveSession")
        
        if autoStartLiveSession && !username.isEmpty {
            locationManager.startLiveSharing(username: username)
        } else {
            locationManager.stopLiveSharing()
        }
    }
    
    private func checkAutoStart() {
        if autoStartLiveSession && !username.isEmpty {
            locationManager.startLiveSharing(username: username)
        }
    }
    
    private func showColorPickerAlert() {
        let alert = UIAlertController(
            title: "Background Color",
            message: "Choose a color",
            preferredStyle: .actionSheet
        )
        
        let colors: [(String, UIColor)] = [
            ("Default", .systemBackground),
            ("Blue", .systemBlue),
            ("Red", .systemRed),
            ("Green", .systemGreen),
            ("Yellow", .systemYellow),
            ("Dark", .darkGray)
        ]
        
        for (name, color) in colors {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                self.bgColor = Color(color)
                UserDefaults.standard.set(color.hexString, forKey: "bgColor")
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func saveUsername() {
        UserDefaults.standard.set(username, forKey: "username")
        if autoStartLiveSession {
            locationManager.startLiveSharing(username: username)
        }
    }
    
    private func loadSavedSettings() {
        if let colorHex = UserDefaults.standard.string(forKey: "bgColor"),
           let color = UIColor(hex: colorHex) {
            bgColor = Color(color)
        }
        
        if let savedUsername = UserDefaults.standard.string(forKey: "username") {
            username = savedUsername
        }
        
        autoStartLiveSession = UserDefaults.standard.bool(forKey: "autoStartLiveSession")
    }
    
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

// MARK: - Extensions
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format: "#%06x", rgb)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
