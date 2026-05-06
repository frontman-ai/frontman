// FFI binding for canvas-confetti
// See: https://github.com/catdad/canvas-confetti

type options = {
  particleCount?: int,
  spread?: int,
  startVelocity?: int,
  decay?: float,
  scalar?: float,
  origin?: {x: float, y: float},
  colors?: array<string>,
  ticks?: int,
  gravity?: float,
  drift?: float,
  angle?: int,
  disableForReducedMotion?: bool,
}

@module("canvas-confetti") external fire: options => promise<unit> = "default"
