// 効果音（音声ファイルを使わず、その場で波形を作って鳴らす）と振動。
// 音楽アプリの再生は止めない（.ambient）。

import AVFoundation
import UIKit

final class SoundPlayer {
    static let shared = SoundPlayer()

    var soundOn = true
    var hapticsOn = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    enum Wave {
        case sine, triangle, square, saw
    }

    struct Note {
        let freq: Double
        let dur: Double
        var delay: Double = 0
        var glideTo: Double? = nil
    }

    private func startIfNeeded() -> Bool {
        if started { return true }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            player.play()
            started = true
        } catch {
            started = false
        }
        return started
    }

    func play(_ notes: [Note], wave: Wave, volume: Float) {
        guard soundOn, startIfNeeded() else { return }
        let sampleRate = format.sampleRate
        let total = notes.map { $0.delay + $0.dur }.max() ?? 0
        let frames = AVAudioFrameCount(total * sampleRate) + 1
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { data[i] = 0 }
        for note in notes {
            let start = Int(note.delay * sampleRate)
            let length = Int(note.dur * sampleRate)
            var phase = 0.0
            for j in 0..<length {
                let t = Double(j) / sampleRate
                var f = note.freq
                if let to = note.glideTo { f = note.freq * pow(to / note.freq, t / note.dur) }
                phase += f / sampleRate
                let p = phase - floor(phase)
                let v: Double
                switch wave {
                case .sine: v = sin(2 * Double.pi * p)
                case .triangle: v = 4 * abs(p - 0.5) - 1
                case .square: v = p < 0.5 ? 1 : -1
                case .saw: v = 2 * p - 1
                }
                let attack = min(1, t / 0.012)
                let release = max(0, 1 - t / note.dur)
                let index = start + j
                if index < Int(frames) { data[index] += Float(v * attack * release * release) * volume }
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    // MARK: 効果音

    func tap() {
        play([Note(freq: 880, dur: 0.05)], wave: .triangle, volume: 0.12)
        impact(.light)
    }

    func draw() {
        play([Note(freq: 520, dur: 0.07, glideTo: 700)], wave: .sine, volume: 0.15)
    }

    func discard() {
        play([Note(freq: 240, dur: 0.07), Note(freq: 180, dur: 0.09, delay: 0.01)], wave: .triangle, volume: 0.2)
        impact(.medium)
    }

    func win() {
        let notes = [523.0, 659, 784, 1047].enumerated().map { Note(freq: $0.element, dur: 0.22, delay: Double($0.offset) * 0.09) }
        play([Note(freq: 620, dur: 0.24, glideTo: 980)] + notes.map { Note(freq: $0.freq, dur: $0.dur, delay: $0.delay + 0.22) }, wave: .triangle, volume: 0.2)
        success()
    }

    func sleep() {
        play([392.0, 330, 262].enumerated().map { Note(freq: $0.element, dur: 0.3, delay: Double($0.offset) * 0.18) }, wave: .sine, volume: 0.16)
    }

    func fanfare() {
        play([523.0, 523, 659, 784, 659, 1047].enumerated().map { Note(freq: $0.element, dur: 0.24, delay: Double($0.offset) * 0.12) }, wave: .triangle, volume: 0.18)
        success()
    }

    // MARK: 振動

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsOn else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func success() {
        guard hapticsOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
