import SwiftUI

struct TrackInfoView: View {
    let track: SonosTrack?
    var emptyText = "No track information"

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: track?.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color.secondary.opacity(0.1)
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                if let track = track {
                    Text(track.title.isEmpty ? "Unknown title" : track.title)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    if !track.artist.isEmpty {
                        Text(track.artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text(emptyText).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 82)
        .background(Color.black.opacity(0.2))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
    }
}
