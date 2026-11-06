#!/usr/bin/env python3
"""One-shot taskdog → aven migration (2026-10-19).

Reads a taskdog JSON export (non-archived; `taskdog export --format json
-f id,name,priority,status,created_at,deadline,estimated_duration,
depends_on,tags -o <file>`) and replays OPEN tasks (PENDING/IN_PROGRESS)
into aven via the CLI, so the sync changelog is built by aven itself.

Mapping (GTD semantics preserved):
  proj/<slug> tag        → aven project (key = slug)
  untagged/no-proj tasks → aven project "personal" (aven requires a project)
  'project' tag (anchor) → aven epic in its project; steps epic-linked to it
  other tags (contexts,
  area/*, uriel-*)       → aven labels, verbatim
  PENDING/IN_PROGRESS    → todo / active
  priority 1-10          → >=8 high, >=5 medium, else low; None → none
  estimated_duration (h) → metadata estimate=<h>
  deadline               → --due (date part)
  depends_on edges       → aven deps, EXCEPT anchor←step edges within a
                           project (epic membership replaces that wiring);
                           edges whose blocker is not migrated are skipped
                           (completed taskdog tasks stay in taskdog history)

COMPLETED/CANCELED tasks are not migrated — taskdog keeps them, and its
DB rides restic + hourly snapshots.

Idempotency: NOT idempotent — run once against an empty aven database
(aven import-style replacement would lose the changelog; CLI replay is
the blessed path). Re-runs duplicate tasks; restore from
`aven backup` instead.

Usage: taskdog-to-aven.py <export.json> [--dry-run]
Runs as the target user (HOME must point at the real aven state).
"""

import json
import re
import subprocess
import sys

CATCHALL_PROJECT = "personal"
STATUS_MAP = {"PENDING": "todo", "IN_PROGRESS": "active"}


def priority_map(p):
    if p is None:
        return "none"
    p = int(p)
    if p >= 8:
        return "high"
    if p >= 5:
        return "medium"
    return "low"


def run(args, capture=True):
    r = subprocess.run(args, capture_output=capture, text=True)
    if r.returncode != 0:
        raise RuntimeError(
            f"cmd failed ({r.returncode}): {' '.join(args)}\n{r.stdout}{r.stderr}"
        )
    return r.stdout.strip()


def main():
    export_path = sys.argv[1]
    dry_run = "--dry-run" in sys.argv
    tasks = json.load(open(export_path))
    open_tasks = [t for t in tasks if t["status"] in STATUS_MAP]

    projects = sorted(
        {
            t.split("/", 1)[1]
            for t in open_tasks
            for t in (t.get("tags") or [])
            if t.startswith("proj/")
        }
    )
    projects.append(CATCHALL_PROJECT)
    labels = sorted(
        {
            tag
            for t in open_tasks
            for tag in (t.get("tags") or [])
            if not tag.startswith("proj/") and tag != "project"
        }
    )

    print(f"open tasks: {len(open_tasks)}  projects: {projects}  labels: {labels}")
    if dry_run:
        for t in open_tasks:
            print(
                f"  [{t['id']:>3}] {STATUS_MAP[t['status']]:<6} "
                f"{', '.join(t.get('tags') or []) or '-'} | {t['name'][:70]}"
            )
        return

    for p in projects:
        print("project:", run(["aven", "project", "create", p]))
    for l in labels:
        print("label:  ", run(["aven", "label", "create", l]))

    refs = {}  # taskdog id -> aven short ref
    anchors = {}  # proj slug -> aven ref of its 'project'-tagged anchor (epic)
    for t in open_tasks:
        tags = t.get("tags") or []
        proj = next(
            (x.split("/", 1)[1] for x in tags if x.startswith("proj/")),
            CATCHALL_PROJECT,
        )
        args = [
            "aven",
            "add",
            t["name"],
            "--project",
            proj,
            "--status",
            STATUS_MAP[t["status"]],
            "--priority",
            priority_map(t.get("priority")),
        ]
        if "project" in tags:
            args.append("--epic")
        for tag in tags:
            if not tag.startswith("proj/") and tag != "project":
                args += ["--label", tag]
        if t.get("estimated_duration"):
            args += ["--metadata", f"estimate={t['estimated_duration']}"]
        if t.get("deadline"):
            args += ["--due", str(t["deadline"])[:10]]
        out = run(args)
        m = re.search(r"ref=([A-Z0-9]+)", out)
        if not m:
            raise RuntimeError(f"no ref parsed from: {out}")
        refs[t["id"]] = m.group(1)
        if "project" in tags:
            anchors[proj] = m.group(1)
        print(f"added [{t['id']:>3}] {m.group(1)} → {proj}: {t['name'][:60]}")

    # Epic membership: steps of each project link to its anchor.
    epic_links = dep_links = skipped = 0
    for t in open_tasks:
        tags = t.get("tags") or []
        proj = next((x.split("/", 1)[1] for x in tags if x.startswith("proj/")), None)
        if proj and proj in anchors and anchors[proj] != refs[t["id"]]:
            run(["aven", "epic", "add", refs[t["id"]], anchors[proj]])
            epic_links += 1

    # Dependencies: skip anchor←step (replaced by epic link) and edges
    # whose blocker was not migrated.
    for t in open_tasks:
        tags = t.get("tags") or []
        proj = next((x.split("/", 1)[1] for x in tags if x.startswith("proj/")), None)
        for dep_id in t.get("depends_on") or []:
            if dep_id not in refs:
                print(f"  dep skipped [{t['id']} → {dep_id}] blocker not migrated")
                skipped += 1
                continue
            if (
                proj
                and anchors.get(proj) == refs[t["id"]]
                and _same_proj(open_tasks, dep_id, proj)
            ):
                # anchor depending on its own step — epic membership covers it
                print(f"  dep skipped (epic covers) [{t['id']} → {dep_id}]")
                skipped += 1
                continue
            run(["aven", "dep", "add", refs[t["id"]], refs[dep_id]])
            dep_links += 1

    print(
        f"\ndone: {len(refs)} tasks, {epic_links} epic links, "
        f"{dep_links} deps, {skipped} skipped edges"
    )


def _same_proj(tasks, task_id, proj):
    for t in tasks:
        if t["id"] == task_id:
            return f"proj/{proj}" in (t.get("tags") or [])
    return False


if __name__ == "__main__":
    main()
