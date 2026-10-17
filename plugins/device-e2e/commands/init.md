---
description: Create .claude/device-e2e/project.md (the project facts device-tester reads) from the plugin template, without overwriting an existing one.
---

Set up `.claude/device-e2e/project.md` in the current project.

1. If `.claude/device-e2e/project.md` already exists (a symlink counts), **do not write to it**. List its unfilled
   slots (step 3) and stop. It is the project's file, even if it still looks like the template.
2. Otherwise copy `${CLAUDE_PLUGIN_ROOT}/skills/playbook/project.template.md` to `.claude/device-e2e/project.md`
   (create the folder). Fill only what you can read from the project: the bundle id / application id from the iOS
   and Android project files, and the build or install scripts that exist in the repo. Never fill device UDIDs,
   serials, passcodes or the build approver from a guess; leave those slots as they are.
3. List every slot still in the form `` `<…>` `` as a `<VERIFY>` item, with the table row or heading it is under.
   Mark the *Optional environment* slots as optional; the *App* and *Devices* tables are the ones
   `/dev-pipeline:task-decompose` checks.
   The `device-tester` agent reads this file before touching a device, so a slot left unfilled is a fact it will
   not have.
4. Report whether the file was created or left alone, and the `<VERIFY>` list.
