# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Finger String is an iOS reminder app with an escalation-based notification system. Reminders progressively escalate from push notifications to alarms until the user marks them complete or snoozed.

## Tech Stack

- SwiftUI + iOS 17+
- SwiftData for persistence
- UNUserNotificationCenter for notifications

## Build & Run

1. Open Xcode and create a new iOS App project named "FingerString"
2. Copy the contents of `FingerString/` into the project
3. Build and run on iOS 17+ simulator or device

Note: The project requires notification permissions. Request in Settings if not prompted.

## Architecture

### Models (`Models/`)
- `Reminder.swift` - Core SwiftData model with title, date, time, state, escalation tracking
- `EscalationPath.swift` - SwiftData model defining escalation steps (preset or custom)
- `EscalationStep.swift` - Codable struct for individual steps (type, delay, repeat interval)
- `ICalSource.swift` - SwiftData model for remote iCal URLs

### Services (`Services/`)
- `EscalationEngine.swift` - Schedules/cancels notification sequences, handles snooze resume
- `NotificationManager.swift` - UNUserNotificationCenter wrapper with Complete/Ignore/Snooze actions
- `ICalParser.swift` - Parses VEVENT components from iCal/ICS files
- `ICalSyncService.swift` - Fetches and syncs remote iCal sources

### Views (`Views/`)
- `ReminderListView.swift` - Main list grouped by Active/Upcoming/Closed
- `CreateReminderView.swift` - Form for new reminders with path picker
- `ReminderDetailView.swift` - View/edit with action buttons (Complete, Snooze, Ignore)
- `EscalationPathPickerView.swift` - Preset and custom path selection
- `SettingsView.swift` - iCal source management

## Key Concepts

### Escalation Paths
Preset paths: Gentle, Standard, Urgent, Nuclear. Each defines steps with notification type (push/alarm), delay from trigger time, and optional repeat interval.

### Snooze Behavior
Snoozing reschedules from the **current escalation step**, not from the beginning. Step index is preserved across snooze.

### iCal Integration
- Remote iCal sources sync periodically
- Editing an iCal event creates a local override (original event ID stored in `ignoredEventIds`)
- Local reminders can be serialized to iCal format via `ICalSerializer`

### iOS Background Limitations
iOS doesn't allow true background alarms. Strategy: pre-schedule all escalation notifications when reminder activates. Up to 64 notifications per reminder for repeating steps.
