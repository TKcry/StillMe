import Foundation
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func checkPermission(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    func scheduleDailyReminder(at time: Date) {
        // Cancel existing reminders first
        cancelDailyReminder()
        
        let content = UNMutableNotificationContent()
        content.title = "StillMe"
        content.body = "Time to capture today's StillMe."
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Error scheduling notification: \(error)")
            } else {
                print("[NotificationService] Daily reminder scheduled at \(components.hour!):\(components.minute!)")
            }
        }
    }
    
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        print("[NotificationService] Daily reminder cancelled")
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
