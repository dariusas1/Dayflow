//
//  SessionLogger.swift
//  FocusLock
//
//  Handles logging and persistence of focus sessions
//

import Foundation
import os.log

class SessionLogger {
    static let shared = SessionLogger()

    private let logger = Logger(subsystem: "FocusLock", category: "Session")
    private let sessionsKey = "FocusLockSessions"
    private let lastSummaryKey = "FocusLockLastSummary"

    // MARK: - Private Initialization
    private init() {}

    // MARK: - Session Management
    func saveSession(_ session: FocusSession) {
        var sessions = loadSessions()
        sessions.append(session)
        saveSessions(sessions)
        logger.info("Saved session: \(session.taskName) (\(session.durationFormatted))")
    }

    func loadSessions() -> [FocusSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return []
        }
        return sessions.sorted { $0.startTime > $1.startTime }
    }

    private func saveSessions(_ sessions: [FocusSession]) {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(encoded, forKey: sessionsKey)
    }

    // MARK: - Event Logging
    func logSessionEvent(_ event: SessionEventType, session: FocusSession) {
        logger.info("Session event: \(event.rawValue) for session: \(session.taskName)")
    }

    // MARK: - Analytics
    func getDailyAnalytics(for date: Date = Date()) -> SessionAnalytics? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let sessions = loadSessions().filter { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }

        guard !sessions.isEmpty else { return nil }

        return SessionAnalytics(sessions: sessions)
    }

    func getWeeklyAnalytics(for date: Date = Date()) -> [SessionAnalytics] {
        let calendar = Calendar.current
        var analytics: [SessionAnalytics] = []

        for i in 0..<7 {
            if let dayStart = calendar.date(byAdding: .day, value: -i, to: date) {
                if let dayAnalytics = getDailyAnalytics(for: dayStart) {
                    analytics.append(dayAnalytics)
                }
            }
        }

        return analytics.reversed() // Most recent first
    }

    // MARK: - Summary Management
    func getLastSessionSummary() -> SessionSummary? {
        guard let data = UserDefaults.standard.data(forKey: lastSummaryKey),
              let summary = try? JSONDecoder().decode(SessionSummary.self, from: data) else {
            return nil
        }
        return summary
    }

    func saveLastSessionSummary(_ summary: SessionSummary) {
        guard let encoded = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(encoded, forKey: lastSummaryKey)
    }

    // MARK: - Export
    func exportSessions(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let sessions = loadSessions()
        let data = ExportData(sessions: sessions, exportDate: Date())

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    private struct ExportData: Codable {
        let sessions: [FocusSession]
        let exportDate: Date
        var version: String = "1.0"
    }
}

// MARK: - Export Formats
extension SessionLogger {
    func exportToCSV(sessions: [FocusSession], to url: URL) -> Result<Void, Error> {
        var csvString = "Task Name,Start Time,End Time,Duration,Completed,Emergency Breaks,Interruptions\n"

        for session in sessions {
            let endTime = session.endTime?.description ?? ""
            let row = [
                session.taskName,
                session.startTime.description,
                endTime,
                String(Int(session.duration)),
                session.isCompleted.description,
                String(session.emergencyBreaks.count),
                String(session.interruptions.count)
            ].joined(separator: ",")

            csvString += row + "\n"
        }

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func exportToJSON(sessions: [FocusSession], to url: URL) -> Result<Void, Error> {
        let exportData = ExportData(sessions: sessions, exportDate: Date())

        do {
            let encoded = try JSONEncoder().encode(exportData)
            try encoded.write(to: url)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}