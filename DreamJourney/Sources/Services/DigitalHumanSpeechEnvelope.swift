import Foundation

struct DigitalHumanSpeechEnvelope: Equatable {
    let duration: TimeInterval
    let samples: [Double]

    static func make(
        fromWAVData data: Data,
        targetFrameRate: Int = 20,
        maxFrames: Int = 180
    ) -> DigitalHumanSpeechEnvelope? {
        guard data.count >= 44,
              asciiString(in: data, range: 0..<4) == "RIFF",
              asciiString(in: data, range: 8..<12) == "WAVE",
              targetFrameRate > 0,
              maxFrames > 0 else {
            return nil
        }

        var format: PCMFormat?
        var audioRange: Range<Int>?
        var cursor = 12

        while cursor + 8 <= data.count {
            guard let chunkSize = readUInt32LE(data, at: cursor + 4) else { return nil }
            let payloadStart = cursor + 8
            let payloadEnd = payloadStart + Int(chunkSize)
            guard payloadEnd <= data.count else { return nil }

            switch asciiString(in: data, range: cursor..<(cursor + 4)) {
            case "fmt ":
                format = parsePCMFormat(data, payloadRange: payloadStart..<payloadEnd)
            case "data":
                audioRange = payloadStart..<payloadEnd
            default:
                break
            }

            cursor = payloadEnd + (Int(chunkSize) % 2)
        }

        guard let format,
              let audioRange,
              format.audioFormat == 1,
              format.channelCount > 0,
              format.sampleRate > 0,
              format.bitsPerSample == 16,
              format.blockAlign >= format.channelCount * 2,
              audioRange.count >= format.blockAlign else {
            return nil
        }

        let totalFrames = audioRange.count / format.blockAlign
        guard totalFrames > 0 else { return nil }

        let duration = Double(totalFrames) / Double(format.sampleRate)
        let bucketCount = min(
            maxFrames,
            max(1, Int(ceil(duration * Double(targetFrameRate))))
        )
        let framesPerBucket = max(1, Int(ceil(Double(totalFrames) / Double(bucketCount))))

        var rawSamples: [Double] = []
        rawSamples.reserveCapacity(bucketCount)

        for bucket in 0..<bucketCount {
            let firstFrame = bucket * framesPerBucket
            let lastFrame = min(totalFrames, firstFrame + framesPerBucket)
            guard firstFrame < lastFrame else { break }

            var powerSum = 0.0
            var measuredSamples = 0

            for frame in firstFrame..<lastFrame {
                let frameOffset = audioRange.lowerBound + frame * format.blockAlign
                for channel in 0..<format.channelCount {
                    let sampleOffset = frameOffset + channel * 2
                    guard let raw = readUInt16LE(data, at: sampleOffset) else { continue }
                    let signed = Int16(bitPattern: raw)
                    let normalized = min(1.0, Double(abs(Int(signed))) / 32768.0)
                    powerSum += normalized * normalized
                    measuredSamples += 1
                }
            }

            let rms = measuredSamples > 0 ? sqrt(powerSum / Double(measuredSamples)) : 0
            rawSamples.append(rms)
        }

        guard let maxEnergy = rawSamples.max(), maxEnergy > 0 else {
            return DigitalHumanSpeechEnvelope(
                duration: duration,
                samples: Array(repeating: 0, count: max(1, rawSamples.count))
            )
        }

        let noiseFloor = maxEnergy * 0.05
        let normalizedSamples = rawSamples.map { sample -> Double in
            let gated = max(0, sample - noiseFloor)
            let normalized = gated / max(maxEnergy - noiseFloor, 0.000_001)
            return min(1, max(0, normalized))
        }

        return DigitalHumanSpeechEnvelope(duration: duration, samples: normalizedSamples)
    }

    func javascriptArrayLiteral() -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        return "[" + samples.map {
            String(format: "%.3f", locale: locale, min(1, max(0, $0)))
        }.joined(separator: ",") + "]"
    }
}

private struct PCMFormat {
    let audioFormat: UInt16
    let channelCount: Int
    let sampleRate: Int
    let blockAlign: Int
    let bitsPerSample: Int
}

private func parsePCMFormat(_ data: Data, payloadRange: Range<Int>) -> PCMFormat? {
    guard payloadRange.count >= 16,
          let audioFormat = readUInt16LE(data, at: payloadRange.lowerBound),
          let channelCount = readUInt16LE(data, at: payloadRange.lowerBound + 2),
          let sampleRate = readUInt32LE(data, at: payloadRange.lowerBound + 4),
          let blockAlign = readUInt16LE(data, at: payloadRange.lowerBound + 12),
          let bitsPerSample = readUInt16LE(data, at: payloadRange.lowerBound + 14) else {
        return nil
    }

    return PCMFormat(
        audioFormat: audioFormat,
        channelCount: Int(channelCount),
        sampleRate: Int(sampleRate),
        blockAlign: Int(blockAlign),
        bitsPerSample: Int(bitsPerSample)
    )
}

private func asciiString(in data: Data, range: Range<Int>) -> String? {
    guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
    return String(data: data.subdata(in: range), encoding: .ascii)
}

private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16? {
    guard offset >= 0, offset + 2 <= data.count else { return nil }
    return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32? {
    guard offset >= 0, offset + 4 <= data.count else { return nil }
    return UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
}
