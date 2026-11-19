# Pongress

**One paddle. Twelve languages. A motion to move slightly upward.**

Play Pong against a parliament of twelve real native language workers. Each senator proposes a paddle target, Raku counts the division, Eiffel certifies the motion, and Icon writes the proceedings. The ball waits for democracy. Your paddle does not have to.

The interface, game physics, server and tests are written in **Haxe**. The browser script and Node server are compiler output. There are **no handwritten JavaScript files and no CSS stylesheet**; the court and chamber are drawn by Haxe on canvas. A small HTML document loads the application. PowerShell starts/builds the tools, a shell script calls Mercury, and a tiny Python adapter hosts genuine Tcl.

![Pongress with a real twelve-language vote](docs/pongress.jpg)

## Play

Supported and tested: **Windows x64**, Node.js 20+, Python 3 with Tcl/Tk, and the same toolchains as [WonkyCalc](https://github.com/Alfredo12111/WonkyCalc).

If WonkyCalc is already set up next to this folder:

```powershell
npm run build
npm start
```

Open **http://localhost:3211/**. After the first build, double-click **Pongress.cmd** to launch a hidden server and open the game. Stop a launcher-started server with:

```powershell
powershell -File scripts/stop.ps1
```

Stop an `npm start` server with Ctrl+C.

For a fresh machine, install Node.js, Python with Tcl/Tk and Visual Studio Build Tools with **Desktop development with C++**, then:

```powershell
npm run setup
npm start
```

Setup reuses an adjacent WonkyCalc installation, or fetches WonkyCalc's pinned toolchain installer into `.cache/toolchains`. The upstream installer verifies pinned archive checksums. First-time setup downloads several gigabytes and builds Mercury; allow substantial time. Toolchain licenses remain those of their upstream projects. Nothing is added permanently to your system PATH.

To use toolchains elsewhere, set `PONGRESS_TOOLCHAINS` to the **.runtimes directory**, or write that path into ignored `toolchains.local.txt`. `PONGRESS_TCL` selects a real tclsh; otherwise the Python/Tcl adapter is used. `PONGRESS_PYTHON` overrides the Python executable. `PORT` changes the HTTP port.

## Controls

- **Mouse / touch:** move or drag on the court to position your paddle.
- **Keyboard:** W/S or Up/Down; Space or P to pause.
- **First to seven** wins. New match resets the score and cancels the previous sitting.
- **Sound** is off initially and can be enabled.
- **Senators:** hover, tap, or focus a language to read its actual proposal and reasoning.
- **Save receipt:** download this match's real snapshots, ballots, timing and certified decisions.
- **Post-point inquiry:** a chamber miss records the actual impact height, the closest senator, and whether the approved target was wrong or the paddle simply arrived too late.

Switching away from the page pauses the match. The layout stacks the chamber below the court on narrow screens. Reduced-motion preferences disable the ball trail and score flash. Buttons, senator rows, instructions and match announcements have keyboard/screen-reader support; the moving Pong court is visual.

## The chamber

All twelve languages vote in every completed sitting. They do actual strategy work and exchange files in an isolated request directory.

| Senator | Strategy / additional responsibility |
| --- | --- |
| [Prolog](workers/prolog.pl) | Rule-based interception with reflected-wall geometry. |
| [Raku](workers/raku.raku) | A damped forecast; majority tally, tie-breaking and the winning target. |
| [Tcl](workers/tcl.tcl) | A rebound estimate negotiated toward center. |
| [Red](workers/red.red) | An offset interception that tries to produce an angled return. |
| [J](workers/j.ijs) | Closed-form triangular-wave reflection. |
| [Rebol](workers/rebol.reb) | Tracks current ball position and short-term vertical motion. |
| [Mercury](workers/mercury.m) | Typed approach/retreat cases and integer reflection. |
| [Eiffel](workers/eiffel/senator.e) | Bounded interception plus executable quorum and target contracts. |
| [BQN](workers/bqn.bqn) | Five perturbed trajectories and a median forecast. |
| [Factor](workers/factor.factor) | Composes interception with a conservative movement bias. |
| [Rexx](workers/rexx.rexx) | Independently predicts the rebound at 50 decimal digits. |
| [Icon](workers/icon.icn) | A defensive forecast and a report generated from the actual election. |
| [Haxe](src/Main.hx) | The thirteenth source language: rendering, controls, physics and process/HTTP transport. |

Each proposal is classified as UP, HOLD or DOWN relative to the paddle at the start of the sitting. Targets within 24 units of its center vote HOLD. The largest bloc wins. Ties are broken by total confidence, then by the stable preference HOLD, UP, DOWN. Confidence is a fixed strategic weight, not a measured probability.

The upper median target from the winning bloc becomes the motion. HOLD leaves the paddle at its original position. Eiffel checks that exactly twelve ballots were counted and that the target remains on the court. Icon then publishes the record. Fifteen real worker invocations are involved: twelve votes, a Raku tally, an Eiffel certificate and an Icon report.

The ball pauses before an AI-bound serve and after each human return until this process finishes. Ballots stream into the sidebar as they arrive. A failed worker puts the match into recess with a retry action; there is no fake ballot or JavaScript strategy fallback. Once certified, the paddle moves toward its target at a limited speed. It can still lose.

The three compiled workers are built during setup/build, **not every frame or sitting**. This keeps the voting breaks playable. A representative complete sitting took about one second on the development machine; hardware and cold-start timing vary.

## Development

```powershell
npm run build   # Haxe client/server plus native Mercury, Eiffel and Icon
npm test        # Haxe gameplay tests and real native integration checks
```

Tests cover wall/paddle collisions, bounded paddle speed, waiting/pausing, scoring and restart; malformed snapshots; three-way ties and confidence tie-breaks; incomplete quorums; Eiffel rejection of illegal targets; reflected intercepts from multiple native workers; simultaneous isolated sittings; and cancellation.

Native programs accept only a bounded numeric snapshot. The Haxe host launches fixed commands without a shell, limits request size, permits two concurrent sittings, caps each worker at 15 seconds, cancels owned process trees on disconnect, and removes per-request files. The server listens only on loopback and rejects foreign Host/Origin values.

**This is a local application, not a deployed public sandbox.** Running the launcher or npm start runs the native workers on the machine where you start it. Public hosting would need a separate supported cloud environment and additional service controls; GitHub Pages cannot execute these workers.

Generated browser JavaScript is marked generated in .gitattributes. Haxe and the recognized worker extensions are explicitly classified. Icon is not currently supported by GitHub Linguist. Language percentages measure bytes of source, not votes or runtime importance.
