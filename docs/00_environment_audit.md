# 00. Environment audit

Audited 2026-11-10 on the development machine. Everything below was checked by
running a command, not assumed.

## What is here

| Item | Finding |
|---|---|
| Machine | MacBook, Apple M4, 10 cores, 16 GB RAM, Metal 4, 2560x1664 built-in display |
| OS | macOS 27.0 |
| Disk | 174 GB free of 460 GB |
| Unreal Engine | **Not installed.** No Epic Games Launcher, no UnrealEditor.app |
| Xcode | **Not installed.** Command Line Tools only (clang 21, Swift 6.3) |
| C++ build tools | clang and make present. cmake, ninja, scons absent |
| Godot | **4.7.2 stable** at `/Applications/Godot.app`, also `godot` on PATH. Runs headless |
| Blender | Installed (`/opt/homebrew/bin/blender`), scriptable from the command line |
| Other runtimes | Node 26.8, Python 3.15rc2, Rust 1.97, ffmpeg, Homebrew |
| Audio tools | GarageBand only. No DAW, no middleware (FMOD/Wwise) |
| Version control | git 2.50. No git-lfs. The home folder is itself a git repo with one commit; VOWFALL has no repo of its own yet |
| Image generation | A Higgsfield connector is attached. Account is on the **free plan with 0 credits**. One image costs 0.25 credits. Nothing can be generated today |
| Existing VOWFALL files | None. This is a new project |
| Related work | `~/AG/Crownfall` (Godot 4.7, typed GDScript) has an earlier "Law" power system, a working third-person controller and licensed CC0 asset packs (Quaternius, KayKit, Kenney) |

## Blockers

1. **Unreal Engine 5 cannot be used here.** It needs full Xcode (an App Store
   install that requires the owner's password), 60 to 100 GB of disk, and is
   uncomfortable in 16 GB of RAM with the editor, a shader compile and a build
   running together. The project owner has also ruled it out on this machine
   before ("it will fry my mac", recorded in Crownfall's AGENTS.md). Beyond the
   install, an agent cannot author Blueprints, materials or levels in the
   Unreal editor from a terminal. Godot's scenes, resources and scripts are
   all text, and the engine runs headless for tests.
2. **No image generation credits.** The visual reference pack cannot be
   produced as images yet. The prompts are written and ready
   (`design/references/PROMPTS.md`).
3. **No audio pipeline.** No DAW or middleware. Sound is planned from CC0
   libraries plus Godot's built-in bus effects until that changes.

## Decision taken

Godot 4.7, typed GDScript, Forward+ on Metal. Reasons and the reversal cost are
in `DECISIONS.md` (D-001, D-002). The Law Engine is written as a pure library
with no engine nodes in it, and its behaviour is pinned by data-driven tests,
so a later port to C++ or Unreal means re-implementing about 1,100 lines against
40 scenarios that already say what correct is.

## Not a blocker, but worth doing

* `git init` inside `Vowfall/` so the project has its own history. A
  `.gitignore` is already in place. Nothing has been committed.
* Install git-lfs before binary art starts arriving.
* Credits for image generation, if the reference pack is wanted as images.
