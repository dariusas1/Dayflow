//
//  MemoryStore.swift
//  FocusLock
//
//  Hybrid memory store with BM25 + vector indexing for local knowledge and RAG
//

import Foundation
import CoreML
import NaturalLanguage
import GRDB
import os.log

// MARK: - MemoryStore Protocol

protocol MemoryStore {
    func index(_ item: MemoryItem) async throws
    func search(_ query: String, limit: Int) async throws -> [MemorySearchResult]
    func semanticSearch(_ query: String, limit: Int) async throws -> [MemorySearchResult]
    func hybridSearch(_ query: String, limit: Int) async throws -> [MemorySearchResult]
    func delete(id: UUID) async throws
    func clear() async throws
    func getStatistics() async throws -> MemoryStoreStatistics
}

// MARK: - Memory Models

struct MemoryItem: Codable, Identifiable {
    let id: UUID
    let content: String
    let timestamp: Date
    let source: MemorySource
    let embeddings: [Float]?
    let metadata: [String: AnyCodable]

    init(content: String, source: MemorySource, embeddings: [Float]? = nil, metadata: [String: Any] = [:]) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.source = source
        self.embeddings = embeddings
        self.metadata = metadata.mapValues { AnyCodable($0) }
    }
}

enum MemorySource: String, Codable, CaseIterable {
    case screenCapture = "screen_capture"
    case ocr = "ocr"
    case accessibility = "accessibility"
    case fileContent = "file_content"
    case userNote = "user_note"
    case aiSummary = "ai_summary"
    case journal = "journal"
    case todo = "todo"

    var displayName: String {
        switch self {
        case .screenCapture: return "Screen Capture"
        case .ocr: return "OCR"
        case .accessibility: return "Accessibility"
        case .fileContent: return "File Content"
        case .userNote: return "User Note"
        case .aiSummary: return "AI Summary"
        case .journal: return "Journal"
        case .todo: return "Todo"
        }
    }
}

struct MemorySearchResult: Identifiable {
    let id: UUID
    let item: MemoryItem
    let score: Double
    let matchType: MatchType
    let highlightedContent: String?

    enum MatchType {
        case keyword(score: Double)
        case semantic(score: Double)
        case hybrid(keywordScore: Double, semanticScore: Double)
    }
}

struct MemoryStoreStatistics {
    let totalItems: Int
    let indexedItems: Int
    let averageEmbeddingGenerationTime: TimeInterval
    let averageSearchTime: TimeInterval
    let storageSizeBytes: Int64
    let lastIndexTime: Date
}

// MARK: - AnyCodable Helper

enum AnyCodableValue: Equatable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictionary.mapValues { $0.value })
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values.map { AnyCodable(value: $0) })
        case .dictionary(let dictionary):
            try container.encode(dictionary.mapValues { AnyCodable(value: $0) })
        case .null:
            try container.encodeNil()
        }
    }
}

struct AnyCodable: Codable {
    let value: AnyCodableValue

    init(_ value: Any) {
        self.value = AnyCodableValue(any: value)
    }

    init(value: AnyCodableValue) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        self.value = try AnyCodableValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension AnyCodableValue {
    init(any value: Any) {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if let child = mirror.children.first {
                self.init(any: child.value)
            } else {
                self = .null
            }
            return
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
                return
            }

            if number.doubleValue.rounded() == number.doubleValue {
                self = .int(number.intValue)
            } else {
                self = .double(number.doubleValue)
            }
            return
        }

        switch value {
        case let codable as AnyCodable:
            self = codable.value
        case let codableValue as AnyCodableValue:
            self = codableValue
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .int(int)
        case let int32 as Int32:
            self = .int(Int(int32))
        case let int64 as Int64:
            self = .int(Int(int64))
        case let double as Double:
            self = .double(double)
        case let float as Float:
            self = .double(Double(float))
        case let string as String:
            self = .string(string)
        case let uuid as UUID:
            self = .string(uuid.uuidString)
        case let array as [AnyCodable]:
            self = .array(array.map { $0.value })
        case let array as [Any]:
            self = .array(array.map { AnyCodableValue(any: $0) })
        case let dictionary as [String: AnyCodable]:
            self = .dictionary(dictionary.mapValues { $0.value })
        case let dictionary as [String: Any]:
            self = .dictionary(dictionary.mapValues { AnyCodableValue(any: $0) })
        case is NSNull:
            self = .null
        default:
            self = .null
        }
    }

    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value) where value.rounded() == value:
            return Int(value)
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }

    var arrayValue: [AnyCodableValue]? {
        if case let .array(values) = self {
            return values
        }
        return nil
    }

    var dictionaryValue: [String: AnyCodableValue]? {
        if case let .dictionary(values) = self {
            return values
        }
        return nil
    }
}

extension AnyCodable {
    var stringValue: String? { value.stringValue }
    var intValue: Int? { value.intValue }
    var doubleValue: Double? { value.doubleValue }
    var boolValue: Bool? { value.boolValue }
    var arrayValue: [AnyCodableValue]? { value.arrayValue }
    var dictionaryValue: [String: AnyCodableValue]? { value.dictionaryValue }
}

// MARK: - BM25 Index

class BM25Index {
    private var documents: [UUID: [String]] = [:]
    private var documentLengths: [UUID: Int] = [:]
    private var termDocumentFrequencies: [String: Int] = [:]
    private var totalDocuments: Int = 0

    // BM25 parameters
    private let k1: Double = 1.2
    private let b: Double = 0.75

    init() {}

    func addDocument(id: UUID, terms: [String]) {
        // Remove existing document if present
        if documents[id] != nil {
            removeDocument(id: id)
        }

        documents[id] = terms
        documentLengths[id] = terms.count

        // Update term frequencies
        let uniqueTerms = Set(terms)
        for term in uniqueTerms {
            termDocumentFrequencies[term, default: 0] += 1
        }

        totalDocuments += 1
    }

    func removeDocument(id: UUID) {
        guard let terms = documents[id] else { return }

        // Update term frequencies
        let uniqueTerms = Set(terms)
        for term in uniqueTerms {
            if termDocumentFrequencies[term, default: 0] > 1 {
                termDocumentFrequencies[term]? -= 1
            } else {
                termDocumentFrequencies.removeValue(forKey: term)
            }
        }

        documents.removeValue(forKey: id)
        documentLengths.removeValue(forKey: id)
        totalDocuments -= 1
    }

    func search(query: String, limit: Int = 10) -> [(UUID, Double)] {
        let queryTerms = tokenize(query.lowercased())
        guard !queryTerms.isEmpty else { return [] }

        var scores: [UUID: Double] = [:]

        // Calculate average document length
        let avgDocLength = documentLengths.values.reduce(0, +) / max(documentLengths.count, 1)

        for (docId, documentTerms) in documents {
            var score: Double = 0

            for term in queryTerms {
                let termFrequency = documentTerms.filter { $0 == term }.count
                guard termFrequency > 0 else { continue }

                let docLength = Double(documentLengths[docId] ?? 0)
                let idf = calculateIDF(term: term)

                // BM25 formula
                let tfComponent = (termFrequency * (k1 + 1)) / (termFrequency + k1 * (1 - b + b * (docLength / avgDocLength)))
                score += idf * tfComponent
            }

            if score > 0 {
                scores[docId] = score
            }
        }

        return scores.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    private func calculateIDF(term: String) -> Double {
        let df = Double(termDocumentFrequencies[term] ?? 0)
        guard df > 0 && totalDocuments > 0 else { return 0 }
        return log((Double(totalDocuments) - df + 0.5) / (df + 0.5))
    }

    private func tokenize(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }
}

// MARK: - Vector Embeddings

class VectorEmbeddingGenerator {
    private var embeddingModel: NLEmbedding?
    private let logger = Logger(subsystem: "FocusLock", category: "VectorEmbeddingGenerator")

    init() {
        loadEmbeddingModel()
    }

    private func loadEmbeddingModel() {
        // Use Apple's multilingual sentence embedding model
        NLEmbedding.sentenceEmbedding(for: .english) { [weak self] result in
            switch result {
            case .success(let embedding):
                self?.embeddingModel = embedding
                self?.logger.info("Successfully loaded sentence embedding model")
            case .failure(let error):
                self?.logger.error("Failed to load embedding model: \(error.localizedDescription)")
            }
        }
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        guard let model = embeddingModel else {
            throw EmbeddingError.modelNotLoaded
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let embedding = try model.vector(for: text)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        logger.info("Generated embedding in \(String(format: "%.3f", duration))s")

        return embedding.map { Float($0) }
    }

    func generateBatchEmbeddings(for texts: [String]) async throws -> [[Float]] {
        var embeddings: [[Float]] = []

        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    enum EmbeddingError: Error {
        case modelNotLoaded
        case processingFailed
    }
}

// MARK: - Similarity Calculator

struct SimilarityCalculator {
    static func cosineSimilarity(between vectorA: [Float], and vectorB: [Float]) -> Double {
        guard vectorA.count == vectorB.count else { return 0 }

        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }

        return Double(dotProduct) / (Double(magnitudeA) * Double(magnitudeB))
    }

    static func euclideanDistance(between vectorA: [Float], and vectorB: [Float]) -> Double {
        guard vectorA.count == vectorB.count else { return Double.greatestFiniteMagnitude }

        let squaredDifferences = zip(vectorA, vectorB).map { pow(Double($0 - $1), 2) }
        return sqrt(squaredDifferences.reduce(0, +))
    }
}

// MARK: - Main MemoryStore Implementation

class HybridMemoryStore: MemoryStore {
    static let shared = HybridMemoryStore()

    private let databaseQueue: DatabaseQueue
    private let bm25Index = BM25Index()
    private let embeddingGenerator = VectorEmbeddingGenerator()
    private let logger = Logger(subsystem: "FocusLock", category: "HybridMemoryStore")

    // Performance tracking
    private var embeddingGenerationTimes: [TimeInterval] = []
    private var searchTimes: [TimeInterval] = []

    private init() throws {
        // Initialize database
        let dbPath = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("FocusLock")
            .appendingPathComponent("MemoryStore.sqlite")

        try FileManager.default.createDirectory(at: dbPath.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)

        databaseQueue = try DatabaseQueue(path: dbPath.path)

        try setupDatabase()
        loadExistingItems()
    }

    private func setupDatabase() throws {
        try databaseQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS memory_items (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    timestamp INTEGER NOT NULL,
                    source TEXT NOT NULL,
                    embeddings BLOB,
                    metadata TEXT,
                    created_at INTEGER DEFAULT (strftime('%s', 'now')),
                    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)

            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_memory_items_timestamp
                ON memory_items(timestamp)
            """)

            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_memory_items_source
                ON memory_items(source)
            """)
        }
    }

    private func loadExistingItems() {
        Task {
            do {
                let items = try getAllStoredItems()
                logger.info("Loaded \(items.count) existing items into memory index")

                // Rebuild BM25 index
                for item in items {
                    let terms = tokenizeForBM25(item.content)
                    bm25Index.addDocument(id: item.id, terms: terms)
                }

            } catch {
                logger.error("Failed to load existing items: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - MemoryStore Protocol Implementation

    func index(_ item: MemoryItem) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Generate embeddings if not provided
        let finalItem: MemoryItem
        if item.embeddings == nil {
            let embeddings = try await embeddingGenerator.generateEmbedding(for: item.content)
            var updatedItem = item
            finalItem = MemoryItem(
                content: item.content,
                source: item.source,
                embeddings: embeddings,
                metadata: item.metadata
            )
        } else {
            finalItem = item
        }

        // Store in database
        try await storeItem(finalItem)

        // Update BM25 index
        let terms = tokenizeForBM25(finalItem.content)
        bm25Index.addDocument(id: finalItem.id, terms: terms)

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Indexed item in \(String(format: "%.3f", duration))s")
    }

    func search(_ query: String, limit: Int = 10) async throws -> [MemorySearchResult] {
        let startTime = CFAbsoluteTimeGetCurrent()

        let results = bm25Index.search(query: query, limit: limit)

        let searchResults = try await results.compactMap { [weak self] (id, score) -> MemorySearchResult? in
            guard let self = self,
                  let item = try await self.getItem(id: id) else { return nil }

            let highlightedContent = self.highlightText(item.content, query: query)

            return MemorySearchResult(
                id: id,
                item: item,
                score: score,
                matchType: .keyword(score: score),
                highlightedContent: highlightedContent
            )
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        searchTimes.append(duration)
        if searchTimes.count > 100 { searchTimes.removeFirst() }

        logger.info("Keyword search completed in \(String(format: "%.3f", duration))s")

        return searchResults
    }

    func semanticSearch(_ query: String, limit: Int = 10) async throws -> [MemorySearchResult] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Generate embedding for query
        let queryEmbedding = try await embeddingGenerator.generateEmbedding(for: query)

        // Get all items with embeddings
        let itemsWithEmbeddings = try await getItemsWithEmbeddings()

        // Calculate similarities
        var similarities: [(UUID, Double)] = []
        for item in itemsWithEmbeddings {
            guard let itemEmbeddings = item.embeddings else { continue }

            let similarity = SimilarityCalculator.cosineSimilarity(
                between: queryEmbedding,
                and: itemEmbeddings
            )

            if similarity > 0.3 { // Threshold for semantic similarity
                similarities.append((item.id, similarity))
            }
        }

        // Sort by similarity and take top results
        similarities.sort { $0.1 > $1.1 }
        let topResults = Array(similarities.prefix(limit))

        let searchResults = try await topResults.compactMap { [weak self] (id, score) -> MemorySearchResult? in
            guard let self = self,
                  let item = try await self.getItem(id: id) else { return nil }

            return MemorySearchResult(
                id: id,
                item: item,
                score: score,
                matchType: .semantic(score: score),
                highlightedContent: nil
            )
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        searchTimes.append(duration)
        if searchTimes.count > 100 { searchTimes.removeFirst() }

        logger.info("Semantic search completed in \(String(format: "%.3f", duration))s")

        return searchResults
    }

    func hybridSearch(_ query: String, limit: Int = 10) async throws -> [MemorySearchResult] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get both keyword and semantic results
        async let keywordResults = search(query, limit: limit * 2)
        async let semanticResults = semanticSearch(query, limit: limit * 2)

        let (keyword, semantic) = try await (keywordResults, semanticResults)

        // Combine and deduplicate results
        var combinedResults: [UUID: MemorySearchResult] = [:]

        // Add keyword results
        for result in keyword {
            combinedResults[result.id] = result
        }

        // Add semantic results or update with hybrid score
        for result in semantic {
            if let existing = combinedResults[result.id] {
                // Combine scores using weighted average
                switch (existing.matchType, result.matchType) {
                case (.keyword(let keywordScore), .semantic(let semanticScore)):
                    let combinedScore = 0.6 * keywordScore + 0.4 * semanticScore
                    combinedResults[result.id] = MemorySearchResult(
                        id: result.id,
                        item: result.item,
                        score: combinedScore,
                        matchType: .hybrid(keywordScore: keywordScore, semanticScore: semanticScore),
                        highlightedContent: existing.highlightedContent
                    )
                default:
                    break
                }
            } else {
                combinedResults[result.id] = result
            }
        }

        // Sort by combined score and limit results
        let finalResults = combinedResults.values
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        searchTimes.append(duration)
        if searchTimes.count > 100 { searchTimes.removeFirst() }

        logger.info("Hybrid search completed in \(String(format: "%.3f", duration))s")

        return Array(finalResults)
    }

    func delete(id: UUID) async throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM memory_items WHERE id = ?", arguments: [id.uuidString])
        }

        bm25Index.removeDocument(id: id)
        logger.info("Deleted item \(id.uuidString)")
    }

    func clear() async throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM memory_items")
        }

        bm25Index = BM25Index()
        logger.info("Cleared all items from memory store")
    }

    func getStatistics() async throws -> MemoryStoreStatistics {
        let items = try getAllStoredItems()
        let indexedItems = items.filter { $0.embeddings != nil }

        let avgEmbeddingTime = embeddingGenerationTimes.isEmpty ? 0 :
            embeddingGenerationTimes.reduce(0, +) / Double(embeddingGenerationTimes.count)

        let avgSearchTime = searchTimes.isEmpty ? 0 :
            searchTimes.reduce(0, +) / Double(searchTimes.count)

        // Calculate storage size
        let storageSize = try databaseQueue.read { db -> Int64 in
            try Int64.fetchOne(db, sql: "SELECT SUM(LENGTH(embeddings) + LENGTH(content) + LENGTH(metadata)) FROM memory_items") ?? 0
        }

        let lastIndexTime = items.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()

        return MemoryStoreStatistics(
            totalItems: items.count,
            indexedItems: indexedItems.count,
            averageEmbeddingGenerationTime: avgEmbeddingTime,
            averageSearchTime: avgSearchTime,
            storageSizeBytes: storageSize,
            lastIndexTime: lastIndexTime
        )
    }

    // MARK: - Private Helper Methods

    private func storeItem(_ item: MemoryItem) async throws {
        let metadataData = try JSONEncoder().encode(item.metadata)

        let embeddingsData: Data?
        if let embeddings = item.embeddings {
            embeddingsData = Data(bytes: embeddings, count: embeddings.count * MemoryLayout<Float>.size)
        } else {
            embeddingsData = nil
        }

        try databaseQueue.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO memory_items
                (id, content, timestamp, source, embeddings, metadata)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [
                item.id.uuidString,
                item.content,
                Int(item.timestamp.timeIntervalSince1970),
                item.source.rawValue,
                embeddingsData,
                String(data: metadataData, encoding: .utf8)
            ])
        }
    }

    private func getItem(id: UUID) async throws -> MemoryItem? {
        return try databaseQueue.read { db -> MemoryItem? in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT id, content, timestamp, source, embeddings, metadata
                FROM memory_items WHERE id = ?
            """, arguments: [id.uuidString]) else { return nil }

            return try parseMemoryItem(from: row)
        }
    }

    private func getAllStoredItems() async throws -> [MemoryItem] {
        return try databaseQueue.read { db -> [MemoryItem] in
            try Row.fetchAll(db, sql: """
                SELECT id, content, timestamp, source, embeddings, metadata
                FROM memory_items ORDER BY timestamp DESC
            """).compactMap { try parseMemoryItem(from: $0) }
        }
    }

    private func getItemsWithEmbeddings() async throws -> [MemoryItem] {
        return try databaseQueue.read { db -> [MemoryItem] in
            try Row.fetchAll(db, sql: """
                SELECT id, content, timestamp, source, embeddings, metadata
                FROM memory_items
                WHERE embeddings IS NOT NULL
                ORDER BY timestamp DESC
            """).compactMap { try parseMemoryItem(from: $0) }
        }
    }

    private func parseMemoryItem(from row: Row) throws -> MemoryItem {
        let idString: String = row["id"]
        let content: String = row["content"]
        let timestamp: Int = row["timestamp"]
        let sourceString: String = row["source"]
        let embeddingsData: Data? = row["embeddings"]
        let metadataString: String? = row["metadata"]

        guard let id = UUID(uuidString: idString),
              let source = MemorySource(rawValue: sourceString) else {
                throw DatabaseError.invalidData
            }

        let embeddings: [Float]?
        if let data = embeddingsData {
            embeddings = data.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float.self))
            }
        } else {
            embeddings = nil
        }

        var metadata: [String: AnyCodable] = [:]
        if let metadataString = metadataString,
           let data = metadataString.data(using: .utf8) {
            metadata = try JSONDecoder().decode([String: AnyCodable].self, from: data)
        }

        return MemoryItem(
            id: id,
            content: content,
            timestamp: Date(timeIntervalSince1970: Double(timestamp)),
            source: source,
            embeddings: embeddings,
            metadata: metadata
        )
    }

    private func tokenizeForBM25(_ text: String) -> [String] {
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
    }

    private func highlightText(_ text: String, query: String) -> String {
        let queryTerms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var highlightedText = text

        for term in queryTerms {
            let range = highlightedText.lowercased().range(of: term)
            if let range = range {
                highlightedText = String(highlightedText.prefix(upTo: range.lowerBound)) +
                    "**" + String(highlightedText[range]) + "**" +
                    String(highlightedText.suffix(from: range.upperBound))
            }
        }

        return highlightedText
    }

    enum DatabaseError: Error {
        case invalidData
        case storageError
    }
}