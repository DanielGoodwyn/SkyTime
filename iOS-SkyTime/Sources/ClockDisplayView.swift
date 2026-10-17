import SwiftUI

public struct ClockDisplayView: View {
    public let title: String
    public let hours: Int
    public let minutes: Int
    public let seconds: Int
    public let ampm: String
    
    public init(title: String, hours: Int, minutes: Int, seconds: Int, ampm: String) {
        self.title = title
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.ampm = ampm
    }
    
    public var body: some View {
        GeometryReader { geo in
            let availH = geo.size.height
            let availW = geo.size.width
            let fs = max(24.0, min(140.0, min(availH / 5.2, availW / 2.2)))
            
            VStack(spacing: 0) {
                // Header Label (SkyTime / Clock Time)
                Text(title)
                    .font(.system(size: 15, weight: .light, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(.top, 14)
                
                Spacer()
                
                // Vertically Stacked Digits
                VStack(spacing: -fs * 0.08) {
                    Text(String(format: "%02dh", hours))
                    Text(String(format: "%02dm", minutes))
                    Text(String(format: "%02ds", seconds))
                }
                .font(.system(size: fs, weight: .light, design: .default))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                
                Text(ampm)
                    .font(.system(size: fs * 0.38, weight: .light, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .padding(.top, 2)
                
                Spacer()
                Spacer().frame(height: 38) // clearance for HUD pill
            }
            .frame(width: availW, height: availH)
        }
    }
}
