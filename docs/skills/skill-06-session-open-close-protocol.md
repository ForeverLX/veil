# Azrael Security Skill — Session Open / Close Protocol
**Version:** 1.4
**Date:** 2026-03-26
**Purpose:** Define exactly what happens at the start and end of every Claude session to ensure context is loaded correctly, work is captured, and the handoff document stays current. Also governs session scope discipline and the Claude Code session workflow.
**Use when:** Every session — automatically. This skill governs session structure regardless of what the session is about.

---

## Session Open Protocol

Every session starts with this sequence before any technical work begins.

**Step 1 — Confirm the handoff document is loaded**
The handoff document (`azrael-handoff-YYYY-MM-DD.md`) is attached to the Azrael Security Claude project and should be present in context. Claude reads it fully before responding to any technical request. If it is not present or appears outdated, flag it immediately: "The handoff document in this project is dated [date] — is there a more recent version to upload before we start?"

**Step 1b — Read applicable skill files**
After confirming the handoff is loaded, call `view` on this file (skill-06) via the view tool. This is the only unconditional read — it happens every session without exception. Running skill-06 from memory is not equivalent and is the failure mode this step exists to prevent.

Then assess the session focus. If the focus is already clear from the opening message, read the applicable skill files before work in that domain begins. If the focus is not yet clear, complete Steps 2 and 3 first, then read applicable skill files before work starts.

Domain-triggered reads — call `view` on each applicable file before entering that domain:

| Domain | Skill file |
|---|---|
| Infrastructure work (any Veil node) | skill-02 |
| Research session | skill-08 + skill-01 |
| Learning session | skill-04 |
| Job application / career | skill-03 |
| Public-facing content | skill-05 |
| Quarterly review | skill-07 |

If no skill file maps to the session focus, confirm that explicitly before proceeding: "This doesn't map to an existing skill file — proceeding without one." Do not silently skip the check.

**Step 2 — Review the backlog and surface the session priority**
Check Section 5 of the handoff. Identify:
1. What is scheduled as the next session (Next Session block)
2. Whether there are any unresolved items from the last session log (Section 7)
3. Whether there is documentation debt from a learning session (Section 6)

State these explicitly in one or two lines, then ask: "What do you want to focus on today?" If the answer matches the scheduled next session, proceed. If it diverges, confirm whether this is a priority shift or an addition — and whether the scheduled session gets deferred or dropped.

Do not assume the scheduled next session is the priority. Do not assume a divergence is scope creep. Ask first, then decide together.

Also cross-check backlog items against the session logs. If a backlog item says a decision or milestone is "not yet done" but the session logs mention it being completed or finalized, treat that as a handoff capture failure and surface it immediately: "The backlog says [item] is pending but Session [N] log mentions it was completed — confirming state before proceeding."

**Step 3 — Check for documentation debt**
If the last session involved a learning track, ask: "Is the artifact from last session committed?" If not, that gets handled before new material starts. This enforces the no-documentation-debt rule from Skill 4 without requiring Darrius to remember it.

Steps 2 through 3 should take under two minutes. The goal is a clean starting state, not a lengthy review.

---

## One Conversation = One Session

Every new Claude conversation is a new session. Never continue work from a prior conversation without starting with the session open protocol. The handoff document is the bridge between sessions — it is the only persistent memory across conversations.

**When starting a new conversation:**
- State the session number in the opening message
- Reference "session open" to trigger the protocol
- Upload the most recent handoff document if it has been updated since the last upload

**When ending a session:**
- Always close with the session close protocol before starting a new conversation
- Never carry unresolved infrastructure changes, unverified commits, or undocumented decisions into a new conversation
- The handoff document must be updated before the conversation ends

This pattern applies to Claude Code sessions as well. See Claude Code section below.

---

## During the Session

**Skill file reference throughout the session:**
When work enters a domain covered by a skill file, that file governs how Claude executes in that domain for the remainder of the session. If a session shifts domains — for example, infrastructure work that transitions into a research discussion — read the applicable skill file at the transition point before proceeding. Do not rely on memory of a skill file read earlier in a prior session.

**Scope management:**
If a request would significantly expand the session beyond the stated focus — for example, starting a new research track when the session goal was infrastructure work — flag it: "That's outside today's focus — add it to the backlog for next session or shift focus now?" Do not silently expand scope.

**Decision capture:**
Any technical decision made during the session that affects infrastructure, research direction, or career strategy gets noted explicitly. At session close these become Section 0 updates in the handoff.

**Operator rules enforcement:**
The operator rules in Section 0 of the handoff apply throughout. Never ask for credentials, tokens, or private keys. Use `rg` on NightForge, `grep` on Cerberus. Tairn changes go in `configuration.nix`. These are not repeated every session — they are enforced silently.

---

## Session Close Triggers

**Hard triggers — always respond immediately:**
- Darrius says "session close" or "wrap up"

**Soft triggers — suggest with a single line:**
"Natural stopping point — session close?"

Suggest a soft close when:
- A major infrastructure change is complete and verified
- A significant research or career milestone is reached
- A NixOS rebuild completes successfully with verified service state
- The current task is done and the next task is a meaningfully different domain
- The session has run long and output quality is declining

Do not suggest session close:
- Mid-task
- When a change is unverified
- When documentation debt from this session hasn't been addressed

---

## Session Close Protocol

When session close is triggered — hard or soft — run this sequence in order.

**Step 0 — Re-read skill-06 before running close protocol**
Call `view` on skill-06 before asking the five questions. Do not run the close protocol from memory. This is the step that was missing when session naming was skipped — the protocol is only reliable when read, not recalled.

**Step 1 — Ask the five questions**

Ask all five before generating anything. Wait for Darrius to answer each one.

1. What did we complete or change this session?
2. Any infrastructure state changes on Cerberus, NightForge, or Tairn?
3. Any new or updated decisions — technical, research, portfolio, or career?
4. What's the priority for next session?
5. Anything to add to the backlog or ideas list?

**Step 2 — Identify which sections changed**

Based on the answers, identify which of the seven handoff sections need updating:

| Answer mentions | Update section |
|---|---|
| Completed work, milestones | Section 3 (Active Operations) and/or Section 7 (Session Log) |
| Infrastructure state change | Section 2 (Infrastructure State) |
| New or updated decisions | Section 0 (Stable Reference — Locked Decisions table) |
| Research question locked or refined | Section 3 (Active Operations) AND Section 0 (Locked Decisions table) — both required, not just session log |
| Repo changes | Section 4 (Repository State) |
| New backlog items | Section 5 (Backlog) |
| Course progress | Section 6 (Courses & Certifications) |
| Next session priority | Section 5 (Backlog — Next Session) |

Section 7 always updates — every session gets a log entry regardless of what else changed.

**Step 3 — Generate the session log entry**

Format for Section 7:
```
### Session [N] — YYYY-MM-DD — [Session Name]
[Two to four sentences. What was worked on, what was completed or decided, what was left open.
No bullet points — prose only. Dense enough that reading it cold gives full context.
Thin enough that it doesn't require reading the whole session to understand.]
```

The session name is required — generate it at close based on what the session actually covered. Format: two to four words, noun phrase, specific enough to distinguish from adjacent sessions. Examples: "Cerberus Hardening + NOC Foundation", "Research Question Lock", "E-Shape Specialization Lock". Do not omit the session name.

Rules for the session log:
- State what actually happened, not what was planned
- Name specific artifacts, decisions, or infrastructure changes — not vague summaries
- If something was left unresolved, name it explicitly so Step 2 of the next session open catches it
- Drop the oldest entry when the log exceeds three entries — full history lives in git
- A locked research question must never appear only in the session log narrative — if it is not in Section 3 and Section 0, the handoff is incomplete regardless of what the log says

**Step 4 — Output changed sections only**

Output only the sections identified in Step 2, plus Section 7. Label each section clearly so Darrius can hand them to Claude Code. Do not output the full document — Claude Code applies the edits mechanically.

**Step 5 — Provide Claude Code prompt**

Output a complete Claude Code prompt containing:
1. Instruction to copy azrael-handoff-q1-sNNN.md to azrael-handoff-q1-s(NNN+1).md
2. The exact surgical edits for each changed section — quoted text to find, replacement text
3. The commit command:
   git add azrael-handoff-q1-s(NNN+1).md && git commit -m "docs: session handoff YYYY-MM-DD S(NNN+1)"
4. git push

Claude Code handles the mechanical file operations. Claude AI handles the content decisions. Do not regenerate the full document in this interface.

**Step 6 — Remind about skill file uploads if applicable**

If any new or updated skill files were produced this session, end with: "Upload [skill file names] to the Azrael Security Claude project before the next session."

---

## Claude Code Session Workflow

Claude Code sessions follow the same open/close discipline as claude.ai sessions, with these additions:

**At Claude Code session start:**
- Run `cat ~/Github/veil/docs/skills/skill-06-session-open-close-protocol.md` or reference the CLAUDE.md in the relevant repo to load session context
- State the session goal in the first message — Claude Code has no persistent memory between invocations
- If the work involves infrastructure changes, confirm the handoff doc is current before starting

**At Claude Code session end:**
- Any decisions or infrastructure changes made during the Claude Code session must be captured in the handoff document before the conversation closes
- Claude Code is a tool within a session, not a separate session system — the handoff doc governs both

**CLAUDE.md files:**
- Each active repo (`veil`, `nightforge`, `security-research`) should have a `CLAUDE.md` at the root
- CLAUDE.md contains: repo purpose, key file paths, coding conventions, what Claude should and should not do in this repo
- CLAUDE.md is not a substitute for the handoff document — it is repo-specific context only

---

## Handoff Document Schema Reference

The handoff follows a locked 7-section schema. Claude never reorders, renames, or restructures sections. Changes go inside sections only.

| Section | Name | Changes when |
|---|---|---|
| 0 | Stable Reference | A decision is locked, node registry changes, operator rules update |
| 1 | Who Darrius Is | Identity, brand philosophy, north star role, or active capability gaps change |
| 2 | Infrastructure State | Any node's service state, config, or status changes |
| 3 | Active Operations | C2 state, research status, or ongoing work progresses |
| 4 | Repository State | Repos created, archived, restructured, or updated |
| 5 | Backlog | Items completed, added, or reprioritized |
| 6 | Courses & Certifications | Course progress or new certifications |
| 7 | Session Log | Every session — always |

---

## What Claude Never Does at Session Close

- Reads skill-06 from memory instead of calling `view` on it
- Generates the full handoff before the five questions are answered
- Omits the session name from the Section 7 log entry
- Summarizes what Darrius said without confirming accuracy
- Marks infrastructure changes as complete without a verification step having occurred
- Lets a session close with unverified infrastructure changes still in flight
- Forgets to include the commit command
- Starts a new workstream at the end of a session instead of adding it to the backlog
- Captures a locked research question only in the session log narrative — it must go into Section 3 AND Section 0 or the handoff is incomplete
- Closes a session where backlog items conflict with session log entries without surfacing the discrepancy

---

## What Claude Never Does at Session Open

- Reads skill-06 from memory instead of calling `view` on it
- Skips the skill file check because the session focus seems obvious
- Proceeds into a domain without reading the applicable skill file
- Assumes the scheduled next session is what Darrius wants to work on without asking
- Silently skips the "no applicable skill file" confirmation for one-off sessions
