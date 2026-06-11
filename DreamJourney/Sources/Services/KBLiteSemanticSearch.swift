import Foundation
import NaturalLanguage

// MARK: - KBLiteSemanticSearch

/// Apple NLP 语义搜索增强层
/// 使用 iOS 内置 NLEmbedding（零下载、完全离线，iOS 12+）
/// 通过 mean-pooling 词向量获得句向量，用于语义相似度计算
final class KBLiteSemanticSearch {

    // MARK: - Singleton

    static let shared = KBLiteSemanticSearch()
    private init() {}

    // MARK: - Properties

    /// 是否支持语义搜索（检查中文 embedding 模型可用性）
    var isAvailable: Bool {
        embedding != nil
    }

    /// 中文词向量模型
    private let embedding: NLEmbedding? = {
        if let e = NLEmbedding.wordEmbedding(for: .simplifiedChinese) {
            return e
        }
        // Fallback: 尝试其他中文 locale
        return NLEmbedding.wordEmbedding(for: .traditionalChinese)
    }()

    /// 缓存已生成的实体句向量（entityId → [Double]）
    private var embeddingCache: [String: [Double]] = [:]

    /// 缓存是否已预热
    private var isCacheWarm = false

    // MARK: - Public API

    /// 对搜索 query 进行语义匹配
    func semanticSearch(
        query: String,
        people: [KBPerson],
        places: [KBPlace],
        events: [KBEvent],
        facts: [KBFact],
        topK: Int = 5
    ) -> KBSearchResult {
        guard isAvailable else { return KBSearchResult() }

        guard let queryEmbedding = sentenceEmbedding(for: query) else {
            return KBSearchResult()
        }

        var result = KBSearchResult()

        result.people = rankBySimilarity(queryEmbedding: queryEmbedding,
                                         items: people,
                                         textExtractor: { $0.searchableText },
                                         topK: topK)

        result.places = rankBySimilarity(queryEmbedding: queryEmbedding,
                                          items: places,
                                          textExtractor: { $0.searchableText },
                                          topK: topK)

        result.events = rankBySimilarity(queryEmbedding: queryEmbedding,
                                          items: events,
                                          textExtractor: { $0.searchableText + " " + $0.formattedDate },
                                          topK: topK)

        result.facts = rankBySimilarity(queryEmbedding: queryEmbedding,
                                         items: facts,
                                         textExtractor: { $0.statement },
                                         topK: topK)

        print("[KBLite] 🧬 语义搜索: \"\(query)\" → \(result.totalCount) 条 (人:\(result.people.count) 地:\(result.places.count) 事:\(result.events.count) 实:\(result.facts.count))")
        return result
    }

    /// 预热缓存
    func warmCache(people: [KBPerson], places: [KBPlace], events: [KBEvent], facts: [KBFact]) {
        guard isAvailable, !isCacheWarm else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var count = 0
            for p in people {
                if self.embeddingCache[p.id] == nil,
                   let emb = self.sentenceEmbedding(for: p.searchableText) {
                    self.embeddingCache[p.id] = emb
                    count += 1
                }
            }
            for p in places {
                if self.embeddingCache[p.id] == nil,
                   let emb = self.sentenceEmbedding(for: p.searchableText) {
                    self.embeddingCache[p.id] = emb
                    count += 1
                }
            }
            self.isCacheWarm = true
            print("[KBLite] 🧬 语义缓存预热完成: \(count) 实体")
        }
    }

    // MARK: - Private

    /// 生成句向量：对文本分词后取所有词向量的平均值（mean pooling）
    private func sentenceEmbedding(for text: String) -> [Double]? {
        guard let emb = embedding else { return nil }

        let words = tokenize(text)
        guard !words.isEmpty else { return nil }

        var sumVector: [Double]?
        var wordCount = 0

        for word in words {
            guard let vec = emb.vector(for: word) else { continue }
            if sumVector == nil {
                sumVector = vec
            } else {
                for i in 0..<vec.count {
                    sumVector![i] += vec[i]
                }
            }
            wordCount += 1
        }

        guard let sum = sumVector, wordCount > 0 else { return nil }

        // Mean pooling
        return sum.map { $0 / Double(wordCount) }
    }

    /// 中文分词
    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text
        tagger.enumerateTags(
            in: NSRange(text.startIndex..., in: text),
            scheme: .tokenType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { _, range, _, _ in
            if let substring = Range(range, in: text) {
                let token = String(text[substring])
                if token.count >= 1 && !token.allSatisfy({ $0.isNumber }) {
                    tokens.append(token)
                }
            }
        }
        if tokens.isEmpty {
            var i = text.startIndex
            while i < text.endIndex {
                let end = text.index(i, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                tokens.append(String(text[i..<end]))
                i = end
            }
        }
        return tokens
    }

    /// 按余弦相似度排序
    private func rankBySimilarity<T: Identifiable>(
        queryEmbedding: [Double],
        items: [T],
        textExtractor: (T) -> String,
        topK: Int
    ) -> [T] where T.ID == String {
        guard !queryEmbedding.isEmpty, !items.isEmpty else { return [] }

        var scored: [(item: T, score: Double)] = []

        for item in items {
            let itemEmbedding: [Double]?
            if let cached = embeddingCache[item.id] {
                itemEmbedding = cached
            } else {
                itemEmbedding = sentenceEmbedding(for: textExtractor(item))
                if let emb = itemEmbedding {
                    embeddingCache[item.id] = emb
                }
            }

            if let emb = itemEmbedding {
                let similarity = cosineSimilarity(queryEmbedding, emb)
                if similarity > 0.3 {
                    scored.append((item, similarity))
                }
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0.item }
    }

    /// 余弦相似度
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
}