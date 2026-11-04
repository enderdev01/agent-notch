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

1. **No layout delta.** The notch width comes from agent activity only, so starting or finishing
   a deployment never resizes or shifts it. The deployment badge uses the idle mascot's slot,
   which costs no extra width.
2. **Agents keep the primary signal.** A deployment never replaces a working agent's indicator.
   While everything is idle it may take the idle mascot's slot, which carries no agent status,
   and it stays otherwise absent from the collapsed notch: a small badge in space the notch
   already has.
3. **One quiet signal, no counters.** The collapsed badge says that something is running
   (`building` over `queued`). Counts, failures and every other state belong to the expanded
   list; never a carousel and never a list that grows the collapsed bar.
4. **No percentage, no invented progress.** Keep the indeterminate indicator and keep
   `reduceMotion` respected. A successful build is not a production promotion; say what
   happened, not what it implies.
5. **No deployment history in the list.** The expanded notch is for agent sessions; listing every
   production deployment there buried the sessions under metadata. Deployment detail (project,
   repository, commit, author) stays in the notification body, and the collapsed badge is the
   mascot plus a state dot. If a hover summary is ever wanted, it is one line for active
   deployments only, never the history.

## Rules for notifications

6. **One per deployment, at the end.** Only `ready`/`failed` notify. `building` and `queued`
   never do. An unchanged deployment seen again never notifies again.
7. **Passive by default.** Set `interruptionLevel = .passive` and drop `.sound` from the
   authorization and the content. The app already has a sound preference for agent turns;
   deployments must not borrow attention for a build the user did not start.
8. **A switch the user can find.** Add "Notify when a Vercel deployment finishes" next to the
   existing sound items, off unless the user turns it on.
9. **Do not notify what the user is already watching.** The monitor asks an injected policy, and
   the app only allows a banner while the notch is collapsed and the preference is on. The
   tracker starts empty on every run, so work that finished while the app was closed is never
   announced.

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
