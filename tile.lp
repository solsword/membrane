#script(python)

import pyglet
import clingo

def arrow(fr, to):
  fx, fy = fr
  tx, ty = to
  # Vector
  vx = tx - fx
  vy = ty - fy
  # Orthogonal vector
  ovx = -vy
  ovy = vx
  # Arrow points
  ar1x = fx + 0.8 * vx + 0.1 * ovx
  ar1y = fy + 0.8 * vy + 0.1 * ovy
  ar2x = fx + 0.8 * vx - 0.1 * ovx
  ar2y = fy + 0.8 * vy - 0.1 * ovy
  scale = 50
  width = scale * 5
  offset = scale
  pyglet.gl.glPushMatrix()
  pyglet.gl.glTranslatef(
    window.width/2 - width/2 - offset/2,
    window.height/2 - width/2 - offset/2,
    0
  )
  pyglet.gl.glScalef(scale, scale, 1)
  # Draw line
  pyglet.gl.glBegin(pyglet.gl.GL_LINES)
  pyglet.gl.glVertex2f(fx, fy)
  pyglet.gl.glVertex2f(tx, ty)
  pyglet.gl.glEnd()
  # Draw arrowhead
  pyglet.gl.glBegin(pyglet.gl.GL_TRIANGLES)
  pyglet.gl.glVertex2f(ar1x, ar1y)
  pyglet.gl.glVertex2f(tx, ty)
  pyglet.gl.glVertex2f(ar2x, ar2y)
  pyglet.gl.glEnd()
  pyglet.gl.glPopMatrix()

def draw_solution(sol):
  for key in sol:
    arrow(key, sol[key])

window = pyglet.window.Window()
window.current_solution = {}

@window.event
def on_draw():
  window.clear()
  draw_solution(window.current_solution)

@window.event
def on_key_press(symbol, modifiers):
  if symbol in (pyglet.window.key.Q, pyglet.window.key.ESCAPE):
    pyglet.app.exit()
  else:
    advance()

@window.event
def on_mouse_press(x, y, button, modifiers):
  if button == pyglet.window.mouse.LEFT:
    advance()

def advance():
  try:
    model = next(window.solgen)
    process_model(model)
  except StopIteration:
    print("Out of solutions.")

def process_model(model):
  window.current_solution = {}
  for atom in model.symbols(atoms=True):
    if atom.name == "next":
      from_, to_ = atom.arguments
      fr = tuple(a.number for a in from_.arguments)
      to = tuple(a.number for a in to_.arguments)
      window.current_solution[fr] = to

def main(prg):
  global PROGRAM
  prg.configuration.solve.models = 0
  prg.ground([("solve",[1, 3, 5, 3])])
  window.solgen = prg.solve(yield_=True)
  advance()
  pyglet.app.run()
#end.


#program solve(sx, sy, ex, ey).

% Start/end parameters
#show start/2.
#show end/2.

start(sx, sy).
end(ex, ey).

% Our coordinate grid
x(1..5).
y(1..5).

% Tiles
#show tile/2.

tile(X, Y) :- x(X), y(Y).

adjacent(tile(X, Y), tile(W, Z)) :-
  tile(X, Y),
  tile(W, Z),
  |X-W| + |Y-Z| == 1.

#show next/2.

% Every tile creates a next link
1 = {
  next(tile(X, Y), tile(W, Z))
  : tile(W, Z), adjacent(tile(X, Y), tile(W, Z))
} :-
  tile(X, Y),
  not end(X, Y).

% Except the start, each tile must receive exactly one next link.
:-
  tile(X, Y),
  not start(X, Y),
  1 != { next(tile(A, B), tile(X, Y)) }.

% Path is the transitive closure of next
path(tile(X, Y), tile(W, Z)) :-
  next(tile(X, Y), tile(W, Z)).

path(tile(X, Y), tile(W, Z)) :-
  path(tile(X, Y), tile(A, B)),
  path(tile(A, B), tile(W, Z)).

% There must be a path from the start to the end
:- 
  start(X, Y),
  end(W, Z),
  not path(tile(X, Y), tile(W, Z)).

% A connected tile is reachable from the start and can reach the end
connected(tile(X, Y)) :-
  start(Sx, Sy),
  end(Ex, Ey),
  path(tile(Sx, Sy), tile(X, Y)),
  path(tile(X, Y), tile(Ex, Ey)).

% Each non-start non-end tile must be connected
:-
  tile(X, Y),
  not end(X, Y),
  not start(X, Y),
  not connected(tile(X, Y)).
