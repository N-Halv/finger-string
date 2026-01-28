# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Finger String is an iOS reminder app with an escalation-based notification system. The app ensures reminders can't be ignored by progressively escalating from push notifications to alarms until the user marks them complete or snoozed.

## Current Status

This repository is in early planning/specification stage. The README.md contains the full product requirements but no implementation code exists yet.

## Key Concepts

### Escalation Paths
Reminders follow configurable escalation paths that increase notification intensity over time (push → push → alarm → repeating alarm). Snoozing resumes from the current step, not from the beginning.

### Reminder States
- **Active**: Currently in an escalation path
- **Completed**: Marked done (green)
- **Ignored**: Dismissed without completing (red)

### iCal Integration
- Reminders can come from local storage or remote iCal links
- Local reminders stored in iCal format for shared logic
- Editing an iCal-sourced reminder creates a local override (original event ID stored to ignore)
- Editing an active reminder restarts the escalation path
