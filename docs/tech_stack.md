<div align="center">

# ⚙️ Tech Stack & Requirements
*Hybrid tech stack details and hardware specifications.*

[⬅️ Back to README](../README.md)

</div>

---

🔍-
100%
🔍+
⚊
◧
🔄
🔍
✕
⚙️
📋 Document Outline
1. Recommended hybrid architecture
2. Open-source desktop agent architecture pattern
3. Final tech stack
4. Model plan and loading strategy
5. System requirements based on your laptop
6. DSA requirements
7. Security and safety requirements
8. Build order
9. Official source basis reviewed
A.R.I.S.E. 2.0

Hybrid Tech Stack and System Requirements

Private voice-first Windows AI assistant for local automation, coding, browsing, memory, and screen-aware assistance

Prepared for

Windows laptop with i5 11th Gen, 16 GB RAM, RTX 2050 4 GB

Edition

Version 2 - Hybrid architecture

Date

09 April 2026

Design intent: keep the assistant local, private, fast, and modular. Spring Boot and Spring AI handle orchestration and tool calling, while Python services handle voice, media, and specialized automation.

1. Recommended hybrid architecture
The best fit for A.R.I.S.E. is a hybrid stack:

Flutter Windows app for the user interface.
Spring Boot + Spring AI for orchestration, prompts, tool calling, policies, and enterprise-style API structure.
Python worker services for voice, media generation, screen analysis, and OS automation helpers.
Ollama for local LLM inference and local model management.
SQLite, Redis, and Chroma for structured storage, caching, and semantic memory.
User voice / screen / text
|
Flutter UI
|
Spring Boot + Spring AI orchestrator
|
Tool router + policy engine
|
Agents: system, browser, file, coding, media, screen
|
Python workers + Playwright + Windows automation
|
Memory: Redis + SQLite + Chroma
|
Ollama + Whisper + XTTS

2. Open-source desktop agent architecture pattern
Research desktop agents generally use a layered pattern:

Interface layer - app UI, voice input, text input, hotkeys.
Perception layer - browser DOM, screen events, terminal output, filesystem changes, speech transcripts.
Planner layer - one model decides the next step and tool sequence.
Tool layer - browser, file, terminal, OS, media, and memory tools.
Execution environment - local OS, sandbox, browser, and project workspace.
Memory and feedback loop - store task history, preferences, outcomes, and workflow patterns.
3. Final tech stack
The following stack is optimized for your current laptop and for local execution.

Layer

Recommended technology

Why it is used

Notes

UI

Flutter stable channel

Native Windows desktop UI with fast rendering and polished controls.

Recommended for the front end.

Orchestration

Spring Boot 3.5.13 + Spring AI 1.1.4

Strong structure for prompts, tools, vector stores, and service orchestration.

Latest stable Spring Boot release reviewed; Spring AI supports tool calling and vector stores.

Local model runtime

Ollama

Simple local model hosting with tool support and local data privacy.

Use as the model runtime for Qwen and helper models.

Main LLM

Qwen2.5 7B Instruct (GGUF Q4_K_M)

Conversation, planning, coding assistance, and tool selection.

Best single general model for your hardware.

Speech-to-text

Whisper Small

Fast offline transcription for voice commands.

Run via faster-whisper or whisper.cpp.

Text-to-speech

XTTS-v2

Natural human-like assistant speech.

Use streaming when possible.

Embeddings

Nomic Embed Text

Semantic memory, document search, and code search.

Pairs with Chroma.

Vector database

Chroma

Local semantic memory and retrieval.

Best fit for file and memory search.

Cache

Redis

Short-term memory, task queue, and response cache.

Use as a fast in-memory layer.

System DB

SQLite

Settings, logs, workflows, app index, and metadata.

Single-file local database.

Browser automation

Playwright

Reliable browser control for websites and forms.

Use Java or Python bindings.

Desktop automation

Windows UI Automation + system APIs

Open apps, control windows, and read UI state.

Use for non-browser apps.

Media workers

Python services

Voice, image, and screen-related tasks.

Keep specialized ML code here.

Packaging

Inno Setup or NSIS

Build the Windows installer and .exe workflow.

Use signed releases if possible.

4. Model plan and loading strategy
To keep the RTX 2050 stable, only one heavy model should be active at a time.

Component

Model

Expected active load

Policy

Main brain

Qwen2.5 7B Instruct Q4

6-7 GB RAM, 2-3 GB VRAM

Load for chat, planning, and coding.

Speech input

Whisper Small

1-2 GB VRAM while active

Load only when listening or transcribing.

Speech output

XTTS-v2

About 2 GB VRAM while active

Use streaming and unload after use.

Embeddings

Nomic Embed Text

Lightweight

Can stay available or on-demand.

Vision / screen analysis

Optional small vision model

Only when needed

Fallback for screen understanding.

Image generation

Stable Diffusion 1.5 if enabled

3-4 GB VRAM

Run separately from other heavy models.

5. System requirements based on your laptop
Your current machine can run the stack if you keep the heavy models serialized and avoid loading all media models together.

Area

Requirement

Why it matters

Operating system

Windows 11 64-bit

Needed for the desktop app, UI automation, and packaging.

CPU

11th Gen Intel i5 or better

Enough for orchestration, UI, and lightweight background tasks.

RAM

16 GB minimum, 32 GB preferred

16 GB works if models are loaded one at a time.

GPU

NVIDIA RTX 2050 4 GB

Good for small local models and occasional image generation.

Storage

At least 100 GB free SSD

Models, caches, logs, and project files need space.

Java

JDK 21 LTS baseline; JDK 25 optional after validation

Spring Boot runs safely on an LTS JDK; use the newer one only after testing.

Spring stack

Spring Boot 3.5.13 + Spring AI 1.1.4

Stable backend and AI orchestration layer.

Flutter

Stable channel

Windows UI build and desktop packaging.

Python

3.12.x

Voice, media, and automation workers.

Database services

SQLite + Redis + Chroma

Persistent data, cache, and semantic memory.

Browser automation

Playwright

Reliable website control and form workflows.

Installer

Inno Setup or NSIS

Create the .exe and installer experience.

6. DSA requirements
High-level data structures are part of the core architecture, not an afterthought.

Structure

Used for

Benefit

Hash map

app lookup, plugin registry, command map

Instant O(1) lookup

Trie

autocomplete, command suggestions, wake phrases

Fast prefix search

Priority queue

task scheduling, retries, urgency

Orders work by priority

DAG / graph

multi-step workflows, dependency chains

Correct execution order

LRU cache

recent responses, repeated searches, hot data

Avoids unnecessary recomputation

Inverted index

document and log keyword search

Fast keyword retrieval

Vector index

semantic memory and retrieval

Meaning-based search

Queue / ring buffer

voice chunks, event streams, tokens

Stable streaming

Stack

undo, rollback, navigation history

LIFO control

Set

dedupe, visited items, processed files

Prevents duplicates

7. Security and safety requirements
Require confirmation before deleting files, sending messages, posting publicly, making purchases, or changing system settings.
Keep tool execution behind a policy engine; the LLM may propose, but tools decide whether an action can run.
Restrict file access to approved folders and block dangerous system paths by default.
Log all automation, browser, and file actions locally for audit and debugging.
Treat prompt injection and malicious web content as first-class threats.
8. Build order
1. Flutter UI shell

2. Voice input and voice output

3. Spring Boot + Spring AI orchestrator

4. Intent router and planner

5. System control tools

6. Browser automation tools

7. File and document tools

8. Redis, SQLite, and Chroma memory layers

9. Coding agent and workflow engine

10. Screen awareness and proactive suggestions

11. Security policy engine

12. Installer and packaging

9. Official source basis reviewed
Spring Boot project and release announcements
Spring AI project and vector store reference docs
Flutter desktop support and Windows setup docs
Ollama project and tool support announcement
Playwright official docs
Redis official documentation
Chroma official documentation
OpenAI Whisper repository
Coqui TTS repository
