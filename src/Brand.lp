import Events
set_option synthInstance.maxSize 4096
/-!
# `Site.Brand` — Isolated Lakeport Brand Lockup, Waterline Mark & Evidence Vocabulary

Single source of truth for Lakeport vector marks and the four-state verification
evidence vocabulary (`Proved`, `Trusted`, `Unknown`, `Failed`).

Logo isolation note: `<LogoLockup />`, `<LogoMark />`, and `<HeroWaterlineMark />`
live exclusively in this module so updating the refined `Lake / Port` lockup
requires editing only `src/Brand.lp` and `assets/brand/*`.
-/
namespace Site.Brand
open LakeportStyle Site

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

/-- Standing `L` above the waterline (`y = 4..31` in the `64`-unit grid). -/
def markUpperPath : String :=
  "M18.5 9.0C18.5 6.24 20.74 4 23.5 4C26.26 4 28.5 6.24 28.5 9.0V22H41.0C43.49 22 45.5 24.01 45.5 26.5C45.5 28.99 43.49 31 41 31H18.5Z"

/-- Reflected `L` and four tapering horizontal ripple bars below `y = 32` (`y = 33..60`). -/
def markReflectionPath : String :=
  "M18.5 33H41.0C43.49 33 45.5 35.01 45.5 37.5C45.5 39.99 43.49 42 41 42H18.5ZM20.8 44H26.2C27.47 44 28.5 45.03 28.5 46.3C28.5 47.57 27.47 48.6 26.2 48.6H20.8C19.53 48.6 18.5 47.57 18.5 46.3C18.5 45.03 19.53 44 20.8 44ZM20 50.6H27C27.83 50.6 28.5 51.27 28.5 52.1C28.5 52.93 27.83 53.6 27 53.6H20C19.17 53.6 18.5 52.93 18.5 52.1C18.5 51.27 19.17 50.6 20 50.6ZM19.5 55.6H27.5C28.05 55.6 28.5 56.05 28.5 56.6C28.5 57.15 28.05 57.6 27.5 57.6H19.5C18.95 57.6 18.5 57.15 18.5 56.6C18.5 56.05 18.95 55.6 19.5 55.6ZM19 59H28C28.28 59 28.5 59.22 28.5 59.5C28.5 59.78 28.28 60 28 60H19C18.72 60 18.5 59.78 18.5 59.5C18.5 59.22 18.72 59 19 59Z"

/-- Outlined Geist 600 wordmark (`Lakeport`) aligned to the standing `L` baseline (`y = 31`). -/
def wordmarkPath : String :=
  "M57.28 31Q55.72 31 54.8 30.2Q53.87 29.4 53.87 27.64V12.1H57.28V27.29Q57.28 27.84 57.56 28.1Q57.83 28.36 58.34 28.36H59.38V31ZM65.22 31.32Q63 31.32 61.64 30.3Q60.28 29.28 60.28 27.44Q60.28 25.59 61.43 24.56Q62.57 23.53 64.9 23.07L69.63 22.15Q69.63 20.63 68.93 19.87Q68.24 19.11 66.89 19.11Q65.65 19.11 64.94 19.67Q64.23 20.24 63.99 21.32L60.52 21.14Q60.93 18.9 62.59 17.68Q64.24 16.47 66.89 16.47Q69.93 16.47 71.48 17.99Q73.03 19.52 73.03 22.36V27.54Q73.03 28.11 73.23 28.31Q73.42 28.52 73.82 28.52H74.28V31Q74.12 31.05 73.76 31.08Q73.4 31.12 73.04 31.12Q72.16 31.12 71.47 30.83Q70.78 30.54 70.39 29.84Q70.01 29.15 70.01 27.92L70.32 28.13Q70.09 29.06 69.39 29.79Q68.7 30.52 67.63 30.92Q66.56 31.32 65.22 31.32ZM65.92 28.84Q67.06 28.84 67.88 28.39Q68.71 27.95 69.17 27.14Q69.63 26.34 69.63 25.26V24.46L65.94 25.21Q64.81 25.43 64.31 25.9Q63.81 26.37 63.81 27.12Q63.81 27.94 64.36 28.39Q64.91 28.84 65.92 28.84ZM75.73 31V12.1H79.14V23.21L84.96 16.79H89.16L83.6 22.7L89.34 31H85.52L81.37 24.72L79.14 27.09V31ZM96.26 31.32Q94.13 31.32 92.57 30.4Q91.01 29.49 90.15 27.81Q89.3 26.14 89.3 23.89Q89.3 21.65 90.15 19.98Q91.01 18.32 92.56 17.39Q94.1 16.47 96.19 16.47Q98.22 16.47 99.75 17.37Q101.27 18.28 102.1 19.98Q102.93 21.69 102.93 24.08V24.84H92.83Q92.94 26.72 93.85 27.66Q94.77 28.59 96.3 28.59Q97.44 28.59 98.19 28.09Q98.95 27.58 99.25 26.64L102.73 26.86Q102.16 28.92 100.44 30.12Q98.72 31.32 96.26 31.32ZM92.83 22.55H99.4Q99.29 20.82 98.42 19.98Q97.55 19.15 96.19 19.15Q94.83 19.15 93.93 20.02Q93.04 20.9 92.83 22.55ZM104.98 34.99V16.79H108.24L108.32 19.81L107.99 19.66Q108.52 18.1 109.73 17.28Q110.94 16.47 112.55 16.47Q114.58 16.47 115.92 17.47Q117.26 18.48 117.93 20.16Q118.6 21.84 118.6 23.89Q118.6 25.93 117.92 27.62Q117.25 29.31 115.91 30.31Q114.56 31.32 112.53 31.32Q111.47 31.32 110.56 30.94Q109.64 30.56 108.98 29.88Q108.33 29.19 108.06 28.25L108.39 27.99V34.99ZM111.73 28.56Q113.28 28.56 114.18 27.32Q115.07 26.08 115.07 23.89Q115.07 21.7 114.18 20.46Q113.28 19.22 111.73 19.22Q110.7 19.22 109.95 19.75Q109.21 20.27 108.8 21.31Q108.39 22.35 108.39 23.89Q108.39 25.43 108.79 26.47Q109.19 27.52 109.95 28.04Q110.7 28.56 111.73 28.56ZM126.8 31.32Q124.69 31.32 123.12 30.4Q121.54 29.49 120.67 27.81Q119.81 26.14 119.81 23.89Q119.81 21.63 120.67 19.97Q121.54 18.31 123.12 17.39Q124.69 16.47 126.8 16.47Q128.9 16.47 130.47 17.39Q132.03 18.31 132.9 19.97Q133.77 21.63 133.77 23.89Q133.77 26.14 132.9 27.81Q132.03 29.49 130.47 30.4Q128.9 31.32 126.8 31.32ZM126.8 28.56Q128.44 28.56 129.34 27.33Q130.25 26.1 130.25 23.89Q130.25 21.7 129.34 20.46Q128.44 19.22 126.8 19.22Q125.15 19.22 124.24 20.46Q123.33 21.7 123.33 23.89Q123.33 26.1 124.24 27.33Q125.15 28.56 126.8 28.56ZM135.81 31V16.79H138.99L139.12 20.74L138.84 20.67Q139.16 18.62 140.05 17.7Q140.94 16.79 142.47 16.79H143.79V19.7H142.46Q141.37 19.7 140.65 20.02Q139.94 20.35 139.58 21.03Q139.22 21.7 139.22 22.81V31ZM150.75 31Q148.63 31 147.63 30.02Q146.63 29.04 146.63 26.93V13.45H150.04V26.6Q150.04 27.6 150.47 27.98Q150.9 28.36 151.79 28.36H153.79V31ZM144.41 19.43V16.79H153.79V19.43Z"

/-- Primary horizontal lockup (`viewBox="18.5 4 135.29 56"`).
    Isolated here so swapping the final `Lake / Port` lockup touches only `src/Brand.lp`. -/
def logoLockup (variant : String := "header") : V :=
  <span class="brand-lockup-svg" data-variant={variant} data-lp-svg="18.5 4 135.29 56">
    <span class="mark-upper" data-lp-svg-shape="path" data-lp-d={markUpperPath} />
    <span class="mark-reflection" data-lp-svg-shape="path" data-lp-d={markReflectionPath} />
    <span class="mark-word" data-lp-svg-shape="path" data-lp-d={wordmarkPath} />
  </span>

/-- Architectural `64×64` mark anchored across the homepage waterline (`y = 32` = `50%`).
    Its upper half (`y = 4..31`) stands in `--air` while its reflected half (`y = 33..60`)
    extends into `Abyss` water (`#54D5CA` Shallows). -/
def heroWaterlineMark : V :=
  <div class="hero-waterline-mark">
    <span class="hero-mark-svg" data-lp-svg="0 0 64 64">
      <span class="hero-mark-upper" data-lp-svg-shape="path" data-lp-d={markUpperPath} />
      <span class="hero-mark-reflection" data-lp-svg-shape="path" data-lp-d={markReflectionPath} />
    </span>
  </div>

/-! ## Four-State Verification Evidence Vocabulary -/

inductive EvState where
  | proved
  | trusted
  | unknown
  | failed
  deriving DecidableEq, Repr

namespace EvState

def tag : EvState → String
  | .proved => "proved"
  | .trusted => "trusted"
  | .unknown => "unknown"
  | .failed => "failed"

def glyph : EvState → String
  | .proved => "●"
  | .trusted => "◐"
  | .unknown => "○"
  | .failed => "✕"

def word : EvState → String
  | .proved => "Proved"
  | .trusted => "Trusted"
  | .unknown => "Unknown"
  | .failed => "Failed"

end EvState

/-- Semantic verification evidence item: always renders glyph + English word + statement. -/
def evidenceItem (st : EvState) (statement : String) (mono : Bool := true) : V :=
  <div class="ev-item" data-ev={st.tag}>
    <span class="ev-badge">
      <span class="ev-glyph">{st.glyph}</span>
      <span class="ev-word">{st.word}</span>
    </span>
    <span class="ev-detail" data-mono={mono}>{statement}</span>
  </div>

end Site.Brand
