# Repo Index

This directory contains a machine-readable index of the codebase for fast orientation and planning. It helps agents understand file purposes, symbols, and relationships without reading everything.

## Structure

- `toc.md` - Master table of contents with one-line descriptions for every indexed file
- `files/` - Per-file detailed entries (mirrors source tree structure with encoded paths)
- `symbols.md` - Symbol → definition location cross-reference
- `modules.md` - High-level module overview grouped by top-level directories
- `graph.json` - Machine-readable dependency graph (imports/exports)

## Path encoding

Source file paths are encoded for filesystem safety: path separators `/` become `__`. For example:
- `src/auth/actions/login.action.ts` → `files/src__auth__actions__login.action.ts.md`
- `packages/core/utils.ts` → `files/packages__core__utils.ts.md`

## Maintenance

This index is maintained by the `repo-index` skill. It should be updated:
- When files are created, renamed, moved, or deleted
- After significant refactors that change imports/exports
- When planning cross-file changes (ensure index is fresh)
- At the end of sessions where code structure changed

## Quick start for agents

1. Read `toc.md` for overview
2. Read `modules.md` to understand top-level layout
3. For focused tasks: grep `toc.md`, `symbols.md` for relevant terms
4. Drill into specific `files/*.md` entries as needed
5. Only read actual source files when editing them

## Notes

- Excludes: node_modules, dist, build, out, .next, coverage, __pycache__, .git, .ai/index, vendor, target
- Describes structure and intent, never contains secrets/PII
- Committed to git like other .ai/ artifacts
