#if DEBUG
import Foundation
import SanjuCore

// Only selectable alongside a UUID test-library namespace. No network requests,
// no normal library mutations, and no scenario overrides in Preview or Release.
actor UITestGenerationService: GenerationService {
    enum Mode: String { case interrupted, failure, swapFailure }
    nonisolated let isDemo = true
    let mode: Mode
    private var failedSwap = false
    init(mode: Mode) { self.mode = mode }
    func quota() async throws -> CreationQuota? { nil }
    func perform(_ operation: PendingGeneration) async throws -> GenerationReply {
        if operation.style == nil {
            if mode == .interrupted { throw GenerationError.uncertain }
            if mode == .failure { throw GenerationError.message("生成服务暂时不可用，素材已保留。") }
        } else if mode == .swapFailure && !failedSwap {
            failedSwap = true
            throw GenerationError.message("没能完成换句，未消耗换句次数。")
        }
        return try await DemoGenerationService().perform(operation)
    }
    func recover(_ operation: PendingGeneration) async throws -> GenerationReply {
        try await DemoGenerationService().perform(operation)
    }
}
#endif
