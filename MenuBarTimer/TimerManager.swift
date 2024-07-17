import SwiftUI
import Combine

class TimerManager: ObservableObject {
    @Published var timeRemaining: Int?
    var timer: Timer?
    var isPaused: Bool = false
    
    func start(minutes: Int) {
        timeRemaining = minutes * 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTimer()
        }
    }
    
    func updateTimer() {
        if let timeRemaining = self.timeRemaining, timeRemaining > 0 {
            self.timeRemaining = timeRemaining - 1
        } else {
            self.timer?.invalidate()
            self.timeRemaining = nil
        }
    }
    
    func pause() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.updateTimer()
            }
        }
    }
    
    func end() {
        timer?.invalidate()
        timeRemaining = nil
    }
    
    func timeString() -> String {
        guard let time = timeRemaining else { return "00:00" }
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
