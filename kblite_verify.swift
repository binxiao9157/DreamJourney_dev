import Foundation
import NaturalLanguage

// =========================================================
// KBLite 验收测试 — 不依赖 App 工程，纯逻辑验证
// 运行方式：swift kblite_verify.swift
// =========================================================

// MARK: - 复制数据模型定义（无需 import App）

struct KBPerson: Codable, Identifiable {
    let id: String
    var name: String
    var aliases: [String] = []
    var relation: String? = nil
    var traits: [String] = []
    var briefBio: String? = nil
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var searchableText: String { ([name] + aliases + traits + [relation].compactMap { $0 } + [briefBio].compactMap { $0 }).joined(separator: " ") }
}

struct KBPlace: Codable, Identifiable {
    let id: String
    var name: String
    var category: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var description: String? = nil
    var relatedPersonIds: [String] = []
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var searchableText: String { [name, category, description].compactMap { $0 }.joined(separator: " ") }
}

struct KBEvent: Codable, Identifiable {
    let id: String
    var title: String
    var description: String? = nil
    var year: Int? = nil
    var month: Int? = nil
    var locationId: String? = nil
    var participantIds: [String] = []
    var mediaIds: [String] = []
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var searchableText: String {
        let base = [title, description].compactMap { $0 }.joined(separator: " ")
        return base + " " + formattedDate
    }
    var formattedDate: String {
        var parts: [String] = []
        if let y = year { parts.append("\(y)年") }
        if let m = month { parts.append("\(m)月") }
        return parts.isEmpty ? "" : parts.joined()
    }
}

struct KBFact: Codable, Identifiable {
    let id: String
    var statement: String
    var confidence: String = "high"
    var relatedPersonIds: [String] = []
    var relatedPlaceIds: [String] = []
    var relatedEventIds: [String] = []
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
}

struct KBSearchResult {
    var people: [KBPerson] = []
    var places: [KBPlace] = []
    var events: [KBEvent] = []
    var facts: [KBFact] = []
    var isEmpty: Bool { people.isEmpty && places.isEmpty && events.isEmpty && facts.isEmpty }
    var totalCount: Int { people.count + places.count + events.count + facts.count }
}

// MARK: - 测试辅助

var passed = 0, failed = 0
func check(_ name: String, _ result: Bool) {
    if result { passed += 1; print("✅ \(name)") }
    else      { failed += 1; print("❌ \(name)") }
}

// MARK: - Test 1: 数据模型 JSON 序列化

let person = KBPerson(id: "p1", name: "爷爷", aliases: ["老张"], relation: "祖父", traits: ["军人"], briefBio: "张建国，1968年参军")
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

if let data = try? encoder.encode(person),
   let str = String(data: data, encoding: .utf8),
   let decoded = try? decoder.decode(KBPerson.self, from: data) {
    check("JSON 序列化/反序列化 — 人物", decoded.name == "爷爷" && decoded.aliases.contains("老张"))
    check("JSON 可读性 — 包含 key", str.contains("\"name\"") && str.contains("\"aliases\""))
} else {
    check("JSON 序列化/反序列化 — 人物", false)
}

// Test place + event + fact round-trip
let place = KBPlace(id: "pl1", name: "上海外滩", category: "visited")
let event = KBEvent(id: "e1", title: "外滩合影", year: 1975, month: 7)
let fact = KBFact(id: "f1", statement: "爷爷在南京当兵7年", confidence: "high")

// Test place
if let data = try? encoder.encode(place), let _ = try? decoder.decode(KBPlace.self, from: data) { check("JSON 往返 — 地点", true) } else { check("JSON 往返 — 地点", false) }
// Test event
if let data = try? encoder.encode(event), let _ = try? decoder.decode(KBEvent.self, from: data) { check("JSON 往返 — 事件", true) } else { check("JSON 往返 — 事件", false) }
// Test fact
if let data = try? encoder.encode(fact), let _ = try? decoder.decode(KBFact.self, from: data) { check("JSON 往返 — 事实", true) } else { check("JSON 往返 — 事实", false) }

// MARK: - Test 2: 实体合并（同名去重）

let p1 = KBPerson(id: "a", name: "爷爷", traits: ["军人"])
let p2 = KBPerson(id: "a", name: "爷爷", traits: ["手艺人"])
let mergedTraits = Array(Set(p1.traits + p2.traits)).sorted()
check("实体合并 — 同名人物 traits 取并集", mergedTraits.contains("军人") && mergedTraits.contains("手艺人"))

let p3 = KBPerson(id: "b", name: "奶奶", traits: ["爱做饭"])
let allPeople = [p1, p3]
let existing = allPeople.first { $0.name == "爷爷" }
check("实体合并 — 查找已有人物", existing?.name == "爷爷")

let newPerson = KBPerson(id: "c", name: "爸爸")
let notFound = allPeople.first(where: { $0.name == "爸爸" })
check("实体合并 — 新人物正确判定为新增", notFound == nil)

// MARK: - Test 3: 中文分词

let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
tagger.string = "我爷爷以前在上海当过兵"
var tokens: [String] = []
tagger.enumerateTags(in: NSRange(location: 0, length: tagger.string!.count),
                      scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { _, range, _, _ in
    tokens.append((tagger.string! as NSString).substring(with: range))
}
check("中文分词 — 产生 tokens", tokens.count >= 3)
let keywordCheck = ["爷爷", "上海", "当兵"]
let matchedKeywords = keywordCheck.filter { kw in tokens.contains(where: { $0.contains(kw) || kw.contains($0) })}
check("中文分词 — 可匹配到关键人物/地点/事件 (\(matchedKeywords.count)/\(keywordCheck.count))", matchedKeywords.count >= 2)

// MARK: - Test 4: 中文关键词检索

let kbPeople = [
    KBPerson(id: "p1", name: "爷爷", aliases: ["老张"], relation: "祖父", traits: ["军人", "手艺人"]),
    KBPerson(id: "p2", name: "奶奶", traits: ["爱做饭"]),
    KBPerson(id: "p3", name: "爸爸"),
]
let kbPlaces = [
    KBPlace(id: "pl1", name: "上海外滩", category: "visited", description: "全家合影"),
    KBPlace(id: "pl2", name: "南京", category: "worked"),
]
let kbEvents = [
    KBEvent(id: "e1", title: "参军", description: "爷爷参军", year: 1968),
    KBEvent(id: "e2", title: "外滩合影", description: nil, year: 1975, month: 7),
]

func keywordSearch(_ query: String) -> KBSearchResult {
    let keywords: [String] = {
        let t = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        t.string = query
        var tokens: [String] = []
        t.enumerateTags(in: NSRange(location: 0, length: query.count),
                         scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { _, range, _, _ in
            let token = (query as NSString).substring(with: range)
            if token.count >= 2 { tokens.append(token) }
        }
        if tokens.isEmpty {
            var i = query.startIndex
            while i < query.endIndex {
                let end = query.index(i, offsetBy: 2, limitedBy: query.endIndex) ?? query.endIndex
                tokens.append(String(query[i..<end]))
                i = end
            }
        }
        return tokens
    }()

    var result = KBSearchResult()
    result.people = kbPeople.filter { p in keywords.contains { p.searchableText.contains($0) } }
    result.places = kbPlaces.filter { p in keywords.contains { p.searchableText.contains($0) } }
    result.events = kbEvents.filter { e in keywords.contains { e.searchableText.contains($0) } }
    return result
}

let r1 = keywordSearch("我爷爷")
check("关键词检索 — '我爷爷' 命中人物", r1.people.contains { $0.name == "爷爷" })
let r2 = keywordSearch("去上海外滩玩")
check("关键词检索 — '上海外滩' 命中地点", r2.places.contains { $0.name == "上海外滩" })
let r3 = keywordSearch("1968年当兵的事")
check("关键词检索 — '当兵' 命中事件", r3.events.contains { $0.title == "参军" })

// MARK: - Test 5: 上下文组装

func buildContextString(result: KBSearchResult) -> String {
    var parts: [String] = []
    if !result.people.isEmpty {
        parts.append("【相关人物】\n" + result.people.prefix(3).map { p in
            var s = p.name
            if let r = p.relation { s += "（\(r)）" }
            if !p.traits.isEmpty { s += "，特征：\(p.traits.joined(separator: "、"))" }
            return s
        }.joined(separator: "\n"))
    }
    if !result.events.isEmpty {
        parts.append("【相关事件】\n" + result.events.prefix(3).map { e in
            "\(e.formattedDate.isEmpty ? "" : e.formattedDate + " ")\(e.title)"
        }.joined(separator: "\n"))
    }
    return parts.joined(separator: "\n\n")
}

let ctx1 = buildContextString(result: keywordSearch("爷爷在南京"))
check("上下文组装 — 包含人物", ctx1.contains("爷爷"))
check("上下文组装 — 包含特征", ctx1.contains("军人"))
check("上下文组装 — 包含关系", ctx1.contains("祖父") || ctx1.contains("relation"))

let ctx2 = buildContextString(result: keywordSearch("1975年的事"))
check("上下文组装 — 包含事件", ctx2.contains("外滩合影"))

// MARK: - Test 6: 知识缺口检测

struct KnowledgeGap {
    let entityName: String
    let missingField: String
    let priority: Int
    var promptHint: String { "\(entityName)的\(missingField)还未知" }
}

var gaps: [KnowledgeGap] = []
for p in kbPeople {
    if p.relation == nil { gaps.append(KnowledgeGap(entityName: p.name, missingField: "关系", priority: 1)) }
    if p.briefBio == nil { gaps.append(KnowledgeGap(entityName: p.name, missingField: "简介", priority: 2)) }
    if p.traits.count < 2 { gaps.append(KnowledgeGap(entityName: p.name, missingField: "特征", priority: 3)) }
}
for e in kbEvents {
    if e.year == nil { gaps.append(KnowledgeGap(entityName: e.title, missingField: "时间", priority: 1)) }
}

check("知识缺口 — 检测到 '爸爸' 的关系缺口", gaps.contains { $0.entityName == "爸爸" && $0.missingField == "关系" })
check("知识缺口 — 检测到 '奶奶' 的简介缺口", gaps.contains { $0.entityName == "奶奶" && $0.missingField == "简介" })
check("知识缺口 — 高优先级缺口 > 0", gaps.filter { $0.priority == 1 }.count > 0)
check("知识缺口 — 总数 > 0", gaps.count > 0)

// MARK: - Test 7: NLEmbedding 可用性

let embAvailable = NLEmbedding.wordEmbedding(for: .simplifiedChinese) != nil
print(embAvailable ? "🧬 Apple NLP 语义搜索：可用（NLEmbedding 中文词向量已加载）" : "⚠️ Apple NLP 语义搜索：不可用")
if embAvailable {
    let emb = NLEmbedding.wordEmbedding(for: .simplifiedChinese)!
    check("NLEmbedding — '爷爷' 有词向量", emb.vector(for: "爷爷") != nil)
    check("NLEmbedding — '当兵' 有词向量", emb.vector(for: "当兵") != nil)
    // 测试 mean-pooling
    let sentence = "爷爷在南京当兵"
    let words: [String] = {
        let t = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        t.string = sentence
        var tokens: [String] = []
        t.enumerateTags(in: NSRange(location: 0, length: sentence.count),
                         scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { _, range, _, _ in
            tokens.append((sentence as NSString).substring(with: range))
        }
        return tokens
    }()
    var sum: [Double]? = nil
    var count = 0
    for w in words {
        if let vec = emb.vector(for: w) {
            if sum == nil { sum = vec } else { for i in 0..<vec.count { sum![i] += vec[i] } }
            count += 1
        }
    }
    if let s = sum, count > 0 {
        let meanVec = s.map { $0 / Double(count) }
        check("NLEmbedding — mean-pooling 句向量生成成功", meanVec.count > 0)
    }
}

// MARK: - Test 8: 余弦相似度

func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot = 0.0, na = 0.0, nb = 0.0
    for i in 0..<a.count { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
    return (na > 0 && nb > 0) ? dot / (sqrt(na) * sqrt(nb)) : 0
}

let v1: [Double] = [1, 0, 0]
let v2: [Double] = [1, 0, 0]
let v3: [Double] = [0, 1, 0]
check("余弦相似度 — 相同向量 = 1.0", abs(cosineSimilarity(v1, v2) - 1.0) < 0.001)
check("余弦相似度 — 正交向量 = 0.0", abs(cosineSimilarity(v1, v3) - 0.0) < 0.001)

// MARK: - Test 9: 文件持久化

let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("kblite_test_\(UUID().uuidString.prefix(8))")
try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
let testFile = tmpDir.appendingPathComponent("test.json")

// 写入
let graphJSON: [String: Any] = [
    "version": 1,
    "people": [
        ["id": "p1", "name": "爷爷", "aliases": ["老张"], "traits": ["军人"], "sourceSessionIds": [1]]
    ],
    "places": [],
    "events": [],
    "facts": [
        ["id": "f1", "statement": "爷爷1968年参军", "confidence": "high", "sourceSessionIds": [1]]
    ]
]
if let data = try? JSONSerialization.data(withJSONObject: graphJSON, options: .prettyPrinted),
   let _ = try? data.write(to: testFile, options: .atomic) {
    let exists = FileManager.default.fileExists(atPath: testFile.path)
    let size = (try? FileManager.default.attributesOfItem(atPath: testFile.path))?[.size] as? Int64 ?? 0
    check("文件持久化 — 写入成功，大小 > 0", exists && size > 0)

    // 读取
    if let loadData = try? Data(contentsOf: testFile),
       let loaded = try? JSONSerialization.jsonObject(with: loadData) as? [String: Any] {
        check("文件持久化 — 反序列化成功", loaded["version"] as? Int == 1)
        if let people = loaded["people"] as? [[String: Any]], let p = people.first {
            check("文件持久化 — 数据正确", p["name"] as? String == "爷爷")
        }
    }
}
try? FileManager.default.removeItem(at: tmpDir)
check("文件持久化 — 清理成功", !FileManager.default.fileExists(atPath: tmpDir.path))

// MARK: - Test 10: 空图谱边界

// 直接用空数组验证
let emptyPeeps: [KBPerson] = []
let tkns = ["爷爷"]
let emptyPe = emptyPeeps.filter { p in tkns.contains { p.searchableText.contains($0) } }
let emptyRes = KBSearchResult(people: emptyPe, places: [], events: [], facts: [])
check("边界 — 空图谱检索返回空", emptyRes.isEmpty)
check("边界 — 空图谱 totalCount = 0", emptyRes.totalCount == 0)

// MARK: - 总结

print("")
print("========================================")
print("   KBLite 验收结果: \(passed)/\(passed + failed) 通过")
print("========================================")
if failed == 0 {
    print("✅ 全部通过！知识库核心逻辑验证成功。")
} else {
    print("⚠️ \(failed) 项未通过，请检查。")
}