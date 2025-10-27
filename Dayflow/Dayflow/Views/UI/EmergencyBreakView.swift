//
//  EmergencyBreakView.swift
//  FocusLock
//
//  Emergency break countdown and control component
//

import SwiftUI

struct EmergencyBreakView: View {
    @ObservedObject private var emergencyBreakManager = EmergencyBreakManager.shared
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                Text("Emergency Break")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.primary)
            }

            // Countdown Timer
            VStack(spacing: 8) {
                Text("Time Remaining")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.secondary)

                Text(emergencyBreakManager.timeRemainingFormatted)
                    .font(.custom("Nunito", size: 48))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Text("Focus will resume automatically")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)

            // Progress Bar
            ProgressView(value: emergencyBreakManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2.0)
                .frame(height: 4)

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    showingDetails.toggle()
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    emergencyBreakManager.forceEndEmergencyBreak(
                        session: SessionManager.shared.currentSession!
                    )
                }) {
                    HStack {
                        Image(systemName: "stop.circle")
                        Text("End Break")
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
        .sheet(isPresented: $showingDetails) {
            EmergencyBreakDetailsView(isPresented: $showingDetails)
        }
    }
}

// MARK: - Emergency Break Details View

struct EmergencyBreakDetailsView: View {
    @ObservedObject private var emergencyBreakManager = EmergencyBreakManager.shared
    @ObservedObject private var sessionManager = SessionManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Emergency Break Details")
                .font(.custom("InstrumentSerif-Regular", size: 20))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 16) {
                DetailRow(
                    title: "Current Session",
                    value: sessionManager.currentSession?.taskName ?? "Unknown"
                )

                DetailRow(
                    title: "Break Duration",
                    value: emergencyBreakManager.totalDurationFormatted
                )

                DetailRow(
                    title: "Time Remaining",
                    value: emergencyBreakManager.timeRemainingFormatted
                )

                DetailRow(
                    title: "Progress",
                    value: "\(Int(emergencyBreakManager.progress * 100))%"
                )

                DetailRow(
                    title: "Breaks in Session",
                    value: "\(emergencyBreakManager.breakCount)"
                )
            }

            Spacer()

            Button(action: {
                isPresented = false
            }) {
                Text("Close")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.custom("Nunito", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Emergency Break Control Button

struct EmergencyBreakButton: View {
    @ObservedObject private var sessionManager = SessionManager.shared

    var body: some View {
        Button(action: {
            sessionManager.requestEmergencyBreak()
        }) {
            HStack {
                Image(systemName: sessionManager.isEmergencyBreakActive ? "pause.circle.fill" : "pause.circle")
                Text(sessionManager.isEmergencyBreakActive ? "Break Active" : "Emergency 20s")
            }
            .font(.custom("Nunito", size: 14))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(sessionManager.isEmergencyBreakActive ? Color.gray : Color.orange)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(sessionManager.isEmergencyBreakActive)
    }
}

#Preview {
    VStack(spacing: 20) {
        EmergencyBreakView()
        EmergencyBreakButton()
    }
    .padding()
}