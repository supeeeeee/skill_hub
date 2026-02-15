import SwiftUI

struct InlineLogView: View {
    let log: ActivityLog
    
    var body: some View {
        HStack {
            Circle()
                .fill(logColor)
                .frame(width: 8, height: 8)
            Text(log.message)
                .font(.monospaced(.caption)())
            Spacer()
            Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
    }
    
    var logColor: Color {
        switch log.type {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}
