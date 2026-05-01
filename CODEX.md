# CODEX.md

## Project

Name: Mew Focus

Platform: macOS Menu Bar App

Stack: SwiftUI + AppKit + Tuist

Mew Focus is a small macOS menu bar focus timer app with a cat-themed visual identity. The app should feel lightweight, calm, and immediately usable from the menu bar.

## Core Features

- Menu bar cat animation
- Remaining time display
- Circular timer UI
- Preset selection
- Custom duration setting
- Start, pause, reset, and end session controls
- Timer completion notification
- Local session persistence and focus statistics

## Architecture

Use a Clean Architecture-inspired module structure.

Dependency direction:

- `MewFocusApp` depends on `MewFocusPresentation` and `MewFocusData`.
- `MewFocusPresentation` depends on `MewFocusDomain` and `MewFocusDesign`.
- `MewFocusData` depends on `MewFocusDomain`.
- `MewFocusDomain` depends on no app-specific module.
- `MewFocusDesign` depends on no app-specific module.

Tuist targets:

- `MewFocusApp`: app entry point, AppKit bridge, menu bar status item, popover, dependency assembly.
- `MewFocusPresentation`: SwiftUI views and view models.
- `MewFocusDomain`: entities, repository protocols, use cases, domain rules.
- `MewFocusData`: local DB/storage implementations and repository implementations.
- `MewFocusDesign`: colors, typography, styles, reusable design primitives.
- `MewFocusDomainTests`: tests for domain state transitions and use cases.

Domain should own business concepts such as `FocusSession`, `FocusPreset`, `TimerState`, `SessionRecord`, repository protocols, and use cases. Domain must not import SwiftUI, AppKit, SwiftData, or any local database framework.

Data should implement Domain repository protocols. Start with in-memory or lightweight local storage, and move to SwiftData or another DB implementation when session history and statistics require it.

Presentation should call use cases through view models. Views should not directly own persistence or database details.

## Product Direction

Mew Focus should prioritize fast access and low friction. Users should be able to check the current session state from the menu bar, open the timer popover quickly, choose a preset or custom duration, and control the session without navigating through unnecessary screens.

The cat animation should support the timer state:

- Idle: calm resting state
- Running: subtle active animation
- Paused: visibly paused or sleepy state
- Completed: celebratory or attention-catching state

Avoid heavy UI, complex onboarding, or large window-first flows unless explicitly requested. The menu bar experience is the primary product surface.

## Design Reference

Use the provided app mockup as the primary visual reference for Mew Focus.

Overall direction:

- Soft, bright macOS popover with a warm white card over a lightly blurred desktop background.
- Friendly cat identity, while still feeling like a focused productivity utility.
- Rounded, airy, minimal, tactile, and calm.
- Primary accent color is coral-orange for active timer progress, selected preset, primary action, and active status dots.
- Secondary accent color may be soft blue for break/rest states.
- Text should be near-black for primary content, medium gray for labels, and light gray for dividers or inactive markings.

Main popover layout:

- Top header with cat icon, product title `Mew Focus`, subtitle `집중에 몰입하는 시간`, and a settings gear icon on the right.
- Large circular timer is the visual center of the app.
- Timer center contains a label, a small status pill, and a large remaining-time readout such as `22:14`.
- Cat illustration peeks from the lower area of the timer circle.
- Main action button sits below the circular timer and uses a wide coral-orange rounded pill style.
- Secondary controls sit below the main action as smaller rounded pills: reset, short break, end session.
- Preset row sits below secondary controls: `10분`, `25분`, `50분`, `90분`, and custom setting.
- Selected preset uses filled coral-orange styling. Unselected presets use white background with light border.
- Bottom summary area has two compact panels: today's focus total and recent sessions.

Component style:

- Popover/card radius should be generous, around 24 to 32 points.
- Buttons should be pill-shaped where appropriate.
- The circular timer should use a thin light-gray base ring, subtle tick marks, and a thick coral-orange progress arc with a round knob.
- Main time typography should be large, bold, and highly legible.
- Use SF Symbols where suitable for settings, reset, pause/play, stop, edit, and menu bar controls.
- Use simple custom cat drawings or asset images for the cat face and timer cat illustration.
- Avoid heavy shadows. Use soft, shallow shadows only to lift controls from the background.

Menu bar behavior:

- The menu bar icon should be a compact cat face.
- The icon can animate subtly by timer state, but should remain calm and readable at menu bar size.
- If remaining time is shown in the menu bar, keep it short and stable.

Do not drift into unrelated themes such as dark dashboards, neon gamification, complex analytics, or marketing-style hero layouts. The app should keep the mockup's calm white/coral cat-timer identity.

## Development Notes for Codex

When working in this repository:

- Read existing Tuist and Swift project files before changing structure.
- Follow the established module boundaries.
- Keep AppKit integration narrow and purposeful.
- Keep timer logic testable outside SwiftUI views.
- Add focused tests for session state changes when modifying timer behavior.
- Do not introduce third-party dependencies unless they solve a clear problem.
- Prefer small, incremental changes that keep the app runnable.
- Split work into small, easy-to-review commits whenever commits are requested.
- Keep each commit focused on one understandable concern so the user can review changes step by step.

## Commit Convention

Use this format:

```text
[Type] #n - Summary
```

Example:

```text
[Feat] #1 - 타이머 시작 기능 구현
```

Types:

- `Feat`: 새로운 기능 추가. 이전에 존재하지 않았던 기능이나 기존 기능의 확장을 포함한다.
- `Fix`: 버그 수정. 기존 기능이나 동작이 의도대로 작동하지 않을 때 사용한다.
- `Docs`: 문서 추가 또는 변경. README, 사용 설명서, 주석 등의 변경에 사용한다.
- `Build`: 빌드 세팅 관련 작업. Tuist 설정, 빌드 스크립트, 외부 종속성, 폴더 구조 등 빌드 프로세스 변경에 사용한다.
- `Refactor`: 전면 수정이나 구조 개선에 사용한다.
- `Chore`: 그 외 잡일. 버전 코드 수정, 패키지 구조 변경, 파일 이동, 파일 이름 변경 등에 사용한다.
