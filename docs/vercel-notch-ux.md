# Vercel in the notch: quiet by default

Deployment status is ambient information, not a turn that needs you. The notch should be
glanceable from the corner of the eye and should never compete with the agent signal, move
anything the user is looking at, or take focus away from a browser tab.

## What the app already guarantees

- `NotchPanel` uses `.nonactivatingPanel` and never calls `activate(ignoringOtherApps:)`, so
  the app cannot come to the front or close a browser's focus.
- `ignoresMouseEvents` stays on except while the pointer is inside the notch shape, so the
  panel does not swallow clicks meant for whatever is behind it.
- `level = .mainMenu + 3`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary` and
  `.ignoresCycle`: the panel follows the user across Spaces without entering the window cycle.
- Notifications request permission lazily, use one identifier per deployment (so the system
  cannot stack duplicates), and fire only on a terminal transition. The first snapshot after
  launch never notifies.

## Rules for the collapsed notch

1. **No layout delta.** The notch width must not change because a deployment exists. Today
   `rightEarWidth` grows to `max(earWidth, 140)`, which shifts the notch whenever a build
   starts or finishes. Keep the width derived from agent activity only.
2. **Agents keep the primary signal.** A deployment must never replace the working/idle
   indicator of an agent. Deployment presence is a quieter layer: a tint on the accent line,
   or a small badge inside space the notch already has.
3. **Worst state wins, with a count.** With several deployments, show the most demanding state
   (`failed` > `building` > `queued` > `ready`) plus a number ("3"), never a carousel and never
   a list that grows the collapsed bar.
4. **No percentage, no invented progress.** Keep the indeterminate indicator and keep
   `reduceMotion` respected. A successful build is not a production promotion; say what
   happened, not what it implies.
5. **Details on hover only.** Project, repository, commit and author belong to the expanded
   list. The collapsed bar shows at most which project is building.

## Rules for notifications

6. **One per deployment, at the end.** Only `ready`/`failed` notify. `building` and `queued`
   never do. An unchanged deployment seen again never notifies again.
7. **Passive by default.** Set `interruptionLevel = .passive` and drop `.sound` from the
   authorization and the content. The app already has a sound preference for agent turns;
   deployments must not borrow attention for a build the user did not start.
8. **A switch the user can find.** Add "Notify when a Vercel deployment finishes" next to the
   existing sound items, off unless the user turns it on.
9. **Do not notify what the user is already watching.** Skip the banner when the notch is
   expanded on that project, or when the deployment is older than the current session.

## Open questions

- Should the deployment layer appear at all before the integration is configured? Current
  answer: no, the status-menu item stays hidden until `VercelMonitor.configured`.
- Once several agents and several deployments compete, does the accent line have enough
  room to carry both, or does deployment status belong only to the expanded view?

## Acceptance criteria

- Starting and finishing a deployment leaves the collapsed notch's size and hit area
  unchanged, and leaves agent indicators untouched.
- A browser tab keeps focus and keyboard input during a deployment, a notification banner and
  a notch hover.
- Two finished deployments produce exactly two notifications, or none when the switch is off.
- Reduce Motion shows a static indicator, and VoiceOver reads one combined label per
  deployment.
