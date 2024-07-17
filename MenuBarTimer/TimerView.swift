import SwiftUI

struct TimerView: View {
    @State private var minutes: String = ""
    @State private var timeRemaining: Int?
    @State private var timer: Timer?
    @State private var isPaused: Bool = false

    var body: some View {
        VStack {
            TextField("Minutes", text: $minutes, onCommit: startTimer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.mainWindow?.makeFirstResponder(nil)
                        NSApplication.shared.windows.first?.makeFirstResponder(nil)
                    }
                }

            if let timeRemaining = timeRemaining {
                Text(timeString(time: timeRemaining))
                    .font(.headline)
            }
        }
        .padding()
        .frame(width: 200, height: 100)
    }

    func startTimer() {
        guard let minutes = Int(minutes) else { return }
        timeRemaining = minutes * 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }
    }

    func updateTimer() {
        if let timeRemaining = self.timeRemaining, timeRemaining > 0 {
            self.timeRemaining = timeRemaining - 1
        } else {
            timer?.invalidate()
            timeRemaining = nil
        }
    }

    func pauseTimer() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updateTimer()
                }
            }
        }
    }

    func endTimer() {
        timer?.invalidate()
        timeRemaining = nil
    }

    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}
