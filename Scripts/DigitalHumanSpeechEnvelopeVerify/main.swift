import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("DigitalHumanSpeechEnvelope verification failed: \(message)\n", stderr)
        exit(1)
    }
}

func makePCM16WAV(samples: [Int16], sampleRate: Int = 16_000) -> Data {
    var data = Data()

    func appendString(_ value: String) {
        data.append(value.data(using: .ascii)!)
    }

    func appendUInt16LE(_ value: UInt16) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: MemoryLayout<UInt16>.size))
    }

    func appendUInt32LE(_ value: UInt32) {
        var little = value.littleEndian
        data.append(Data(bytes: &little, count: MemoryLayout<UInt32>.size))
    }

    appendString("RIFF")
    appendUInt32LE(UInt32(36 + samples.count * 2))
    appendString("WAVE")
    appendString("fmt ")
    appendUInt32LE(16)
    appendUInt16LE(1)
    appendUInt16LE(1)
    appendUInt32LE(UInt32(sampleRate))
    appendUInt32LE(UInt32(sampleRate * 2))
    appendUInt16LE(2)
    appendUInt16LE(16)
    appendString("data")
    appendUInt32LE(UInt32(samples.count * 2))
    samples.forEach { sample in
        var little = sample.littleEndian
        data.append(Data(bytes: &little, count: MemoryLayout<Int16>.size))
    }
    return data
}

let sampleRate = 16_000
let silence = Array(repeating: Int16(0), count: sampleRate / 5)
let loud = (0..<(sampleRate / 5)).map { index -> Int16 in
    index.isMultiple(of: 2) ? 22_000 : -22_000
}
let wav = makePCM16WAV(samples: silence + loud + silence, sampleRate: sampleRate)

guard let envelope = DigitalHumanSpeechEnvelope.make(
    fromWAVData: wav,
    targetFrameRate: 20,
    maxFrames: 64
) else {
    fputs("DigitalHumanSpeechEnvelope verification failed: expected envelope for valid WAV\n", stderr)
    exit(1)
}

expect(envelope.duration > 0.55 && envelope.duration < 0.65, "duration should be read from WAV data")
expect(envelope.samples.count >= 10, "envelope should contain multiple timing buckets")
expect(envelope.samples.allSatisfy { $0 >= 0 && $0 <= 1 }, "envelope samples should be normalized")

let third = envelope.samples.count / 3
let headEnergy = envelope.samples.prefix(third).reduce(0, +) / Double(max(1, third))
let midEnergy = envelope.samples.dropFirst(third).prefix(third).reduce(0, +) / Double(max(1, third))
let tailEnergy = envelope.samples.suffix(third).reduce(0, +) / Double(max(1, third))

expect(midEnergy > 0.55, "middle loud section should have high energy")
expect(headEnergy < 0.12, "leading silence should have low energy")
expect(tailEnergy < 0.12, "trailing silence should have low energy")

let encoded = envelope.javascriptArrayLiteral()
expect(encoded.hasPrefix("["), "JS literal should be an array")
expect(encoded.hasSuffix("]"), "JS literal should be an array")
expect(encoded.contains(","), "JS literal should preserve several samples")

print("DigitalHumanSpeechEnvelope verification passed")
