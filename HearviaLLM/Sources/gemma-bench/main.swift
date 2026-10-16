import Foundation
import HearviaGemma

// Downloads TranslateGemma if needed, then times translating sentences one at a time, the way the on-device engine
// sends finished sentences. Usage: gemma-bench [target=zh] [source=en]
// Build with xcodebuild (MLX needs its Metal library).

let arguments = CommandLine.arguments.dropFirst()
let target = arguments.first ?? "zh"
let source = arguments.dropFirst().first ?? "en"
let sentences = [
    "Good evening.",
    "Tonight we are looking at how small changes in daily routines can improve sleep quality.",
    "Researchers followed 200 volunteers for six months.",
    "Those who kept a consistent bedtime fell asleep 20 minutes faster on average.",
    "Turning off screens an hour before bed also helped, but the effect was smaller than expected.",
    "So for the next quarter we'll focus on onboarding, and the pricing page goes out next week.",
    "Let's start with where we landed last quarter.",
    "Activation went up, but too many people drop off during setup."
]

func seconds(since start: ContinuousClock.Instant) -> Double {
    let elapsed = start.duration(to: .now).components
    return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
}

if !TranslateGemma.isDownloaded {
    print("Downloading \(TranslateGemma.repo) to \(TranslateGemma.directory.path)…")
    let start = ContinuousClock.now
    try await TranslateGemma.download { progress in
        print(String(format: "\r  %3.0f%%", progress * 100), terminator: "")
        fflush(stdout)
    }
    print(String(format: "\ndownloaded in %.0f s", seconds(since: start)))
}

var start = ContinuousClock.now
let translator = try await GemmaTranslator.load()
print(String(format: "loaded in %.2f s", seconds(since: start)))

_ = try await translator.translate("Hello.", from: source, to: target) // warm-up: first run compiles kernels
var times: [Double] = []
for sentence in sentences {
    start = ContinuousClock.now
    let translation = try await translator.translate(sentence, from: source, to: target)
    let elapsed = seconds(since: start)
    times.append(elapsed)
    print(String(format: "%5.2f s  %@\n         %@", elapsed, sentence, translation))
}
let sorted = times.sorted()
print(String(format: "per sentence: median %.2f s, max %.2f s, mean %.2f s",
             sorted[sorted.count / 2], sorted.last ?? 0, times.reduce(0, +) / Double(times.count)))
