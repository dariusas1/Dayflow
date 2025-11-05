//
//  OCRExtractor.swift
//  FocusLock
//
//  Vision framework integration for text extraction from screen captures
//

import Foundation
@preconcurrency import Vision
import CoreImage
import AppKit
import os.log

final class OCRExtractor: @unchecked Sendable {
    static let shared = OCRExtractor()

    private let logger = Logger(subsystem: "FocusLock", category: "OCRExtractor")

    // Vision OCR request configuration
    private lazy var ocrRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"] // Add more languages as needed
        request.usesLanguageCorrection = true
        return request
    }()

    // Performance optimization: Cache for recent OCR results
    private var ocrCache: [String: OCRResult] = [:]
    private let maxCacheSize = 100
    private let cacheCleanupThreshold = 120 // Clean up when cache exceeds 120 items

    // Configuration
    private let minConfidence: Float = 0.7
    private let maxProcessingTime: TimeInterval = 5.0

    private init() {
        setupVisionRequest()
    }

    // MARK: - Public Interface

    func extractText(from image: NSImage, region: CGRect? = nil) async -> OCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Generate cache key
            let cacheKey = generateCacheKey(for: image, region: region)

            // Check cache first
            if let cachedResult = ocrCache[cacheKey] {
                logger.debug("OCR cache hit for image")
                return cachedResult
            }

            // Process image
            let result = try await processImageForOCR(image, region: region)

            // Cache result
            cacheOCRResult(result, key: cacheKey)

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("OCR extraction completed in \(String(format: "%.3f", duration))s - \(result.text.count) characters extracted")

            return result

        } catch {
            logger.error("OCR extraction failed: \(error.localizedDescription)")
            return OCRResult(
                text: "",
                confidence: 0,
                regions: [],
                processingTime: CFAbsoluteTimeGetCurrent() - startTime,
                error: error
            )
        }
    }

    func extractStructuredText(from image: NSImage, region: CGRect? = nil) async -> StructuredOCRResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let ocrResult = await extractText(from: image, region: region)

        // Analyze the extracted text for structure
        let structuredAnalysis = analyzeTextStructure(ocrResult.text)

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        return StructuredOCRResult(
            ocrResult: ocrResult,
            paragraphs: structuredAnalysis.paragraphs,
            sentences: structuredAnalysis.sentences,
            words: structuredAnalysis.words,
            codeBlocks: structuredAnalysis.codeBlocks,
            lists: structuredAnalysis.lists,
            tables: structuredAnalysis.tables,
            processingTime: duration
        )
    }

    func extractCodeSnippets(from image: NSImage, region: CGRect? = nil) async -> [CodeSnippet] {
        let ocrResult = await extractText(from: image, region: region)
        return extractCodeFromText(ocrResult.text, ocrResult: ocrResult)
    }

    func extractDocuments(from image: NSImage, region: CGRect? = nil) async -> DocumentExtractionResult {
        let structuredResult = await extractStructuredText(from: image, region: region)

        let documentResult = DocumentExtractionResult(
            title: extractDocumentTitle(from: structuredResult),
            headings: extractHeadings(from: structuredResult),
            paragraphs: structuredResult.paragraphs,
            lists: structuredResult.lists,
            codeBlocks: structuredResult.codeBlocks,
            tables: structuredResult.tables,
            metadata: extractDocumentMetadata(from: structuredResult)
        )

        return documentResult
    }

    // MARK: - Private Methods

    private func setupVisionRequest() {
        // Configure the OCR request for better results
        ocrRequest = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("Vision OCR request failed: \(error.localizedDescription)")
                return
            }
        }

        ocrRequest.recognitionLevel = .accurate
        ocrRequest.usesLanguageCorrection = true
        ocrRequest.recognitionLanguages = ["en-US", "en-GB"] // Support multiple English variants
    }

    private func processImageForOCR(_ image: NSImage, region: CGRect? = nil) async throws -> OCRResult {
        return try await withCheckedThrowingContinuation { continuation in
            // Create a copy of the image data to ensure it stays valid during async processing
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let cgImage = bitmap.cgImage else {
                continuation.resume(throwing: OCRError.invalidImage)
                return
            }

            // Crop image if region is specified
            let processedImage: CGImage
            if let region = region {
                guard let croppedImage = cgImage.cropping(to: region) else {
                    continuation.resume(throwing: OCRError.regionProcessingFailed)
                    return
                }
                processedImage = croppedImage
            } else {
                processedImage = cgImage
            }

            // Create image request handler with the copied CGImage
            let requestHandler = VNImageRequestHandler(cgImage: processedImage, options: [:])

            // Perform OCR on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([self.ocrRequest])
                    
                    // Process results on main queue
                    DispatchQueue.main.async {
                        let results = self.processOCRResults()
                        continuation.resume(returning: results)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func processOCRResults() -> OCRResult {
        var extractedText = ""
        var regions: [TextRegion] = []
        var totalConfidence: Float = 0
        var observationCount = 0

        guard let observations = ocrRequest.results else {
            return OCRResult(text: "", confidence: 0, regions: [], processingTime: 0)
        }

        // Sort observations by position (top to bottom, left to right)
        let sortedObservations = observations.sorted { obs1, obs2 in
            let box1 = obs1.boundingBox
            let box2 = obs2.boundingBox

            // Primary sort by y-coordinate (top to bottom)
            if abs(box1.origin.y - box2.origin.y) > 0.01 {
                return box1.origin.y > box2.origin.y
            }

            // Secondary sort by x-coordinate (left to right)
            return box1.origin.x < box2.origin.x
        }

        for observation in sortedObservations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let confidence = topCandidate.confidence
            guard confidence >= minConfidence else { continue }

            let text = topCandidate.string
            let boundingBox = observation.boundingBox

            // Convert normalized coordinates to image coordinates
            let region = TextRegion(
                text: text,
                confidence: confidence,
                boundingBox: boundingBox,
                position: convertBoundingBoxToPoint(boundingBox)
            )

            regions.append(region)
            extractedText += text + " "
            totalConfidence += confidence
            observationCount += 1
        }

        let averageConfidence = observationCount > 0 ? totalConfidence / Float(observationCount) : 0

        return OCRResult(
            text: extractedText.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: averageConfidence,
            regions: regions,
            processingTime: 0 // Will be set by caller
        )
    }

    private func analyzeTextStructure(_ text: String) -> TextStructureAnalysis {
        var analysis = TextStructureAnalysis()

        // Split into paragraphs
        let paragraphs = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        analysis.paragraphs = paragraphs.map { paragraph in
            TextParagraph(
                content: paragraph.trimmingCharacters(in: .whitespacesAndNewlines),
                sentences: extractSentences(from: paragraph),
                wordCount: paragraph.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
            )
        }

        // Extract all sentences
        analysis.sentences = paragraphs.flatMap { extractSentences(from: $0) }

        // Extract all words
        analysis.words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.rangeOfCharacter(from: .letters) != nil }

        // Detect code blocks
        analysis.codeBlocks = extractCodeBlocks(from: text)

        // Detect lists
        analysis.lists = extractLists(from: text)

        // Detect tables (basic detection)
        analysis.tables = extractTables(from: text)

        return analysis
    }

    private func extractSentences(from text: String) -> [TextSentence] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return sentences.enumerated().map { index, sentence in
            TextSentence(
                content: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
                index: index
            )
        }
    }

    private func extractCodeBlocks(from text: String) -> [CodeBlock] {
        var codeBlocks: [CodeBlock] = []
        let lines = text.components(separatedBy: .newlines)

        // Simple code block detection based on common patterns
        var inCodeBlock = false
        var currentBlock: [String] = []
        var startLine = 0

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for code block indicators
            let codeIndicators = ["func", "function", "def", "class", "struct", "enum", "import", "from", "require", "let", "var", "const"]

            if codeIndicators.contains(where: { trimmedLine.hasPrefix($0) }) && !inCodeBlock {
                inCodeBlock = true
                startLine = index
                currentBlock.append(line)
            } else if inCodeBlock && (trimmedLine.isEmpty || trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("#")) {
                // End of code block
                inCodeBlock = false
                if currentBlock.count > 1 {
                    let codeBlock = CodeBlock(
                        code: currentBlock.joined(separator: "\n"),
                        language: detectProgrammingLanguage(from: currentBlock),
                        startLine: startLine,
                        endLine: index - 1
                    )
                    codeBlocks.append(codeBlock)
                }
                currentBlock = []
            } else if inCodeBlock {
                currentBlock.append(line)
            }
        }

        // Handle code block at end of text
        if currentBlock.count > 1 {
            let codeBlock = CodeBlock(
                code: currentBlock.joined(separator: "\n"),
                language: detectProgrammingLanguage(from: currentBlock),
                startLine: startLine,
                endLine: lines.count - 1
            )
            codeBlocks.append(codeBlock)
        }

        return codeBlocks
    }

    private func detectProgrammingLanguage(from lines: [String]) -> ProgrammingLanguage {
        let combinedText = lines.joined(separator: "\n").lowercased()

        // Language detection based on keywords and syntax
        if combinedText.contains("func ") || combinedText.contains("let ") || combinedText.contains("var ") {
            return .swift
        } else if combinedText.contains("def ") || combinedText.contains("import ") {
            return .python
        } else if combinedText.contains("function ") || combinedText.contains("const ") || combinedText.contains("let ") {
            return .javascript
        } else if combinedText.contains("public class") || combinedText.contains("private class") {
            return .java
        } else if combinedText.contains("using ") || combinedText.contains("namespace ") {
            return .csharp
        } else if combinedText.contains("#include") || combinedText.contains("int main") {
            return .cpp
        } else {
            return .unknown
        }
    }

    private func extractLists(from text: String) -> [TextList] {
        var lists: [TextList] = []
        let lines = text.components(separatedBy: .newlines)

        var currentList: [String] = []
        var listType: ListType?

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for list indicators
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") {
                if listType == nil {
                    listType = .bullet
                }
                currentList.append(trimmedLine)
            } else if trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                if listType == nil {
                    listType = .numbered
                }
                currentList.append(trimmedLine)
            } else if trimmedLine.range(of: #"^[a-zA-Z]\.\s+"#, options: .regularExpression) != nil {
                if listType == nil {
                    listType = .lettered
                }
                currentList.append(trimmedLine)
            } else if !trimmedLine.isEmpty && !currentList.isEmpty {
                // End of list
                if currentList.count > 1 {
                    let list = TextList(
                        items: currentList,
                        type: listType ?? .bullet
                    )
                    lists.append(list)
                }
                currentList = []
                listType = nil
            }
        }

        // Handle list at end of text
        if currentList.count > 1 {
            let list = TextList(
                items: currentList,
                type: listType ?? .bullet
            )
            lists.append(list)
        }

        return lists
    }

    private func extractTables(from text: String) -> [TextTable] {
        var tables: [TextTable] = []
        let lines = text.components(separatedBy: .newlines)

        // Simple table detection based on tab or pipe separators
        var currentTable: [[String]] = []
        var inTable = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.contains("\t") || trimmedLine.contains("|") {
                // Potential table row
                let cells = trimmedLine.components(separatedBy: CharacterSet(charactersIn: "\t|"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if cells.count > 1 {
                    currentTable.append(cells)
                    inTable = true
                }
            } else if inTable && !trimmedLine.isEmpty {
                // End of table
                if currentTable.count > 1 {
                    let table = TextTable(rows: currentTable)
                    tables.append(table)
                }
                currentTable = []
                inTable = false
            }
        }

        // Handle table at end of text
        if currentTable.count > 1 {
            let table = TextTable(rows: currentTable)
            tables.append(table)
        }

        return tables
    }

    private func extractCodeFromText(_ text: String, ocrResult: OCRResult) -> [CodeSnippet] {
        var codeSnippets: [CodeSnippet] = []
        let codeBlocks = extractCodeBlocks(from: text)

        for codeBlock in codeBlocks {
            let snippet = CodeSnippet(
                code: codeBlock.code,
                language: codeBlock.language,
                confidence: calculateCodeConfidence(for: codeBlock.code),
                boundingBox: findBoundingBoxForCode(codeBlock, in: ocrResult.regions),
                functions: extractFunctions(from: codeBlock.code, language: codeBlock.language),
                imports: extractImports(from: codeBlock.code, language: codeBlock.language)
            )
            codeSnippets.append(snippet)
        }

        return codeSnippets
    }

    private func calculateCodeConfidence(for code: String) -> Float {
        var confidence: Float = 0.8 // Base confidence for detected code

        // Boost confidence for well-formed code
        let hasBraces = code.contains("{") && code.contains("}")
        let hasParentheses = code.contains("(") && code.contains(")")
        let hasSemicolons = code.components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix(";") }
            .count > 0

        if hasBraces { confidence += 0.05 }
        if hasParentheses { confidence += 0.05 }
        if hasSemicolons { confidence += 0.05 }

        return min(confidence, 1.0)
    }

    private func findBoundingBoxForCode(_ codeBlock: CodeBlock, in regions: [TextRegion]) -> CGRect? {
        // Find the bounding box that contains the first line of the code block
        let firstLine = codeBlock.code.components(separatedBy: .newlines).first ?? ""

        for region in regions {
            if region.text.contains(firstLine.prefix(10)) {
                return CGRect(
                    x: region.boundingBox.origin.x,
                    y: region.boundingBox.origin.y,
                    width: region.boundingBox.size.width,
                    height: region.boundingBox.size.height
                )
            }
        }

        return nil
    }

    private func extractFunctions(from code: String, language: ProgrammingLanguage) -> [String] {
        var functions: [String] = []
        let lines = code.components(separatedBy: .newlines)

        let functionPatterns: [ProgrammingLanguage: String] = [
            .swift: #"func\s+\w+\s*\("#,
            .python: #"def\s+\w+\s*\("#,
            .javascript: #"function\s+\w+\s*\(|const\s+\w+\s*=\s*function\(|\w+\s*:\s*\("#,
            .java: #"public|private|protected\s+\w+\s+\w+\s*\("#,
            .cpp: #"\w+\s+\w+\s*\("#,
            .csharp: #"\w+\s+\w+\s*\("#,
            .unknown: #"\w+\s*\("#
        ]

        if let pattern = functionPatterns[language],
           let regex = try? NSRegularExpression(pattern: pattern, options: []) {

            for line in lines {
                let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                for match in matches {
                    if let range = Range(match.range, in: line) {
                        functions.append(String(line[range]))
                    }
                }
            }
        }

        return functions
    }

    private func extractImports(from code: String, language: ProgrammingLanguage) -> [String] {
        var imports: [String] = []
        let lines = code.components(separatedBy: .newlines)

        let importPatterns: [ProgrammingLanguage: String] = [
            .swift: #"import\s+\w+"#,
            .python: #"import\s+\w+|from\s+\w+\s+import"#,
            .javascript: #"import\s+.*\s+from|require\("#,
            .java: #"import\s+\w+"#,
            .cpp: #"#include\s+"#,
            .csharp: #"using\s+\w+"#,
            .unknown: #"import|require|include"#
        ]

        if let pattern = importPatterns[language],
           let regex = try? NSRegularExpression(pattern: pattern, options: []) {

            for line in lines {
                let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                for match in matches {
                    if let range = Range(match.range, in: line) {
                        imports.append(String(line[range]))
                    }
                }
            }
        }

        return imports
    }

    private func extractDocumentTitle(from structuredResult: StructuredOCRResult) -> String? {
        // Look for potential title in first few paragraphs
        let titleCandidates = Array(structuredResult.paragraphs.prefix(3))

        for paragraph in titleCandidates {
            let content = paragraph.content

            // Title characteristics:
            // - Single line
            // - Not too long (under 100 characters)
            // - Contains title case words
            // - Not a list item or code

            if !content.contains("\n") &&
               content.count < 100 &&
               !content.hasPrefix("-") &&
               !content.hasPrefix("*") &&
               !content.hasPrefix("•") &&
               !content.contains("func ") &&
               !content.contains("def ") &&
               !content.contains("import ") {

                // Check for title case (first letter of words capitalized)
                let words = content.components(separatedBy: .whitespaces)
                let capitalizedWords = words.filter { $0.first?.isUppercase == true && $0.count > 1 }

                if capitalizedWords.count >= words.count / 2 {
                    return content
                }
            }
        }

        return nil
    }

    private func extractHeadings(from structuredResult: StructuredOCRResult) -> [DocumentHeading] {
        var headings: [DocumentHeading] = []

        for (index, paragraph) in structuredResult.paragraphs.enumerated() {
            let content = paragraph.content

            // Look for heading patterns
            if content.range(of: #"^[A-Z][a-z\s]+:"#, options: .regularExpression) != nil ||
               content.range(of: #"^\d+\.\s+[A-Z]"#, options: .regularExpression) != nil ||
               content.count < 50 && content.hasSuffix(":") {

                let level = determineHeadingLevel(content: content)
                let heading = DocumentHeading(
                    title: content.dropLast().trimmingCharacters(in: .whitespacesAndNewlines),
                    level: level,
                    paragraphIndex: index
                )
                headings.append(heading)
            }
        }

        return headings
    }

    private func determineHeadingLevel(content: String) -> Int {
        // Simple heading level detection
        if content.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
            return 1 // Level 1 heading
        } else if content.range(of: #"^\d+\.\d+\s+"#, options: .regularExpression) != nil {
            return 2 // Level 2 heading
        } else if content.hasPrefix("##") {
            return 2
        } else if content.hasPrefix("###") {
            return 3
        } else {
            return 1 // Default to level 1
        }
    }

    private func extractDocumentMetadata(from structuredResult: StructuredOCRResult) -> DocumentMetadata {
        var metadata = DocumentMetadata()

        // Extract potential date from content
        let dateString = extractDateFromContent(structuredResult.paragraphs.map { $0.content }.joined(separator: " "))
        if let date = dateString {
            metadata.date = date
        }

        // Extract potential author
        metadata.author = extractAuthorFromContent(structuredResult.paragraphs.map { $0.content }.joined(separator: " "))

        // Extract word count
        metadata.wordCount = structuredResult.words.count

        // Extract language detection (basic)
        metadata.language = detectLanguage(from: structuredResult.paragraphs.first?.content ?? "")

        return metadata
    }

    private func extractDateFromContent(_ content: String) -> String? {
        let datePatterns = [
            #"\d{1,2}/\d{1,2}/\d{4}"#, // MM/DD/YYYY
            #"\d{4}-\d{2}-\d{2}"#, // YYYY-MM-DD
            #"(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}"#
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                if let match = matches.first, let range = Range(match.range, in: content) {
                    return String(content[range])
                }
            }
        }

        return nil
    }

    private func extractAuthorFromContent(_ content: String) -> String? {
        // Look for "by" or "author" patterns
        let authorPatterns = [
            #"by\s+[A-Z][a-z]+\s+[A-Z][a-z]+"#,
            #"author:\s*[A-Z][a-z]+"#,
            #"written\s+by\s+[A-Z][a-z]+"#
        ]

        for pattern in authorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                if let match = matches.first, let range = Range(match.range, in: content) {
                    return String(content[range])
                }
            }
        }

        return nil
    }

    private func detectLanguage(from text: String) -> String {
        // Simple language detection based on common words
        let englishWords = ["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let englishWordCount = words.filter { englishWords.contains($0) }.count

        if englishWordCount > words.count / 4 {
            return "English"
        }

        return "Unknown"
    }

    private func generateCacheKey(for image: NSImage, region: CGRect?) -> String {
        // Simple cache key based on image hash and region
        let imageData = image.tiffRepresentation ?? Data()
        let imageHash = imageData.prefix(1024).reduce(0) { $0 + Int($1) }

        if let region = region {
            return "\(imageHash)_\(region.origin.x)_\(region.origin.y)_\(region.size.width)_\(region.size.height)"
        } else {
            return "\(imageHash)_full"
        }
    }

    private func cacheOCRResult(_ result: OCRResult, key: String) {
        ocrCache[key] = result

        // Clean up cache if it gets too large
        if ocrCache.count > cacheCleanupThreshold {
            cleanupCache()
        }
    }

    private func cleanupCache() {
        // Remove oldest items to maintain cache size
        let sortedKeys = Array(ocrCache.keys).sorted()
        let keysToRemove = Array(sortedKeys.prefix(ocrCache.count - maxCacheSize))

        for key in keysToRemove {
            ocrCache.removeValue(forKey: key)
        }

        logger.debug("Cleaned up OCR cache, removed \(keysToRemove.count) items")
    }

    private func convertBoundingBoxToPoint(_ boundingBox: CGRect) -> CGPoint {
        return CGPoint(x: boundingBox.origin.x, y: 1.0 - boundingBox.origin.y - boundingBox.size.height)
    }
}

// MARK: - Data Models

struct OCRResult {
    let text: String
    let confidence: Float
    let regions: [TextRegion]
    let processingTime: TimeInterval
    let error: Error?

    init(text: String, confidence: Float, regions: [TextRegion], processingTime: TimeInterval, error: Error? = nil) {
        self.text = text
        self.confidence = confidence
        self.regions = regions
        self.processingTime = processingTime
        self.error = error
    }
}

struct TextRegion {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let position: CGPoint
}

struct StructuredOCRResult {
    let ocrResult: OCRResult
    let paragraphs: [TextParagraph]
    let sentences: [TextSentence]
    let words: [String]
    let codeBlocks: [CodeBlock]
    let lists: [TextList]
    let tables: [TextTable]
    let processingTime: TimeInterval
}

struct TextParagraph {
    let content: String
    let sentences: [TextSentence]
    let wordCount: Int
}

struct TextSentence {
    let content: String
    let index: Int
}

struct CodeBlock {
    let code: String
    let language: ProgrammingLanguage
    let startLine: Int
    let endLine: Int
}

enum ProgrammingLanguage {
    case swift
    case python
    case javascript
    case java
    case cpp
    case csharp
    case unknown
}

struct TextList {
    let items: [String]
    let type: ListType
}

enum ListType {
    case bullet
    case numbered
    case lettered
}

struct TextTable {
    let rows: [[String]]
}

struct CodeSnippet {
    let code: String
    let language: ProgrammingLanguage
    let confidence: Float
    let boundingBox: CGRect?
    let functions: [String]
    let imports: [String]
}

struct DocumentExtractionResult {
    let title: String?
    let headings: [DocumentHeading]
    let paragraphs: [TextParagraph]
    let lists: [TextList]
    let codeBlocks: [CodeBlock]
    let tables: [TextTable]
    let metadata: DocumentMetadata
}

struct DocumentHeading {
    let title: String
    let level: Int
    let paragraphIndex: Int
}

struct DocumentMetadata {
    var date: String?
    var author: String?
    var wordCount: Int = 0
    var language: String = "Unknown"
}

struct TextStructureAnalysis {
    var paragraphs: [TextParagraph] = []
    var sentences: [TextSentence] = []
    var words: [String] = []
    var codeBlocks: [CodeBlock] = []
    var lists: [TextList] = []
    var tables: [TextTable] = []
}

enum OCRError: Error {
    case invalidImage
    case regionProcessingFailed
    case visionFrameworkError
    case processingTimeout
}