#script(python)

import pyglet
import clingo

def arrow(fr, to):
  """ Draws an arrow from (x, y) to (w, z). """
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

def draw_solution(window, sol):
  """
  Draws a given solution dictionary that maps grid point tuples to each other
  to indicate the path from start to finish.
  """
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
  for key in sol:
    arrow(key, sol[key])
  pyglet.gl.glPopMatrix()

def process_model(model):
  """
  Converts a clingo model into a grid-point-map solution.
  """
  result = {}
  for atom in model.symbols(atoms=True):
    if atom.name == "next":
      from_, to_ = atom.arguments
      fr = tuple(a.number for a in from_.arguments)
      to = tuple(a.number for a in to_.arguments)
      result[fr] = to

  return result

def nextlist(solution):
  """
  Converts a grid-point-map solution into a nextlist.
  """
  result = [-1] * 5 * 5
  for key in solution:
    fcol = key[0] - 1
    frow = key[1] - 1
    fidx = fcol + 5*frow
    tcol = solution[key][0] - 1
    trow = solution[key][1] - 1
    tidx = tcol + 5*trow
    result[fidx] = tidx

  return result

def line(nextlist):
  """
  Converts a nextlist to a line of JSON.
  """
  return "[{}],".format(",".join(str(x) for x in nextlist))

def display_solutions(solgen):
  """
  Creates a pyglet window for displaying solutions from the given generator.
  """
  # Define our window and our current_solution attribute
  window = pyglet.window.Window()
  current_solution = {}

  # Bind event handlers
  @window.event
  def on_draw():
    """ Draw the current solution. """
    nonlocal window, current_solution
    window.clear()
    draw_solution(window, current_solution)

  @window.event
  def on_key_press(symbol, modifiers):
    """ Exit if `q` is pressed, otherwise advance to the next solution. """
    if symbol in (pyglet.window.key.Q, pyglet.window.key.ESCAPE):
      pyglet.app.exit()
    else:
      advance()

  @window.event
  def on_mouse_press(x, y, button, modifiers):
    """ Advance to the next solution on left-click. """
    if button == pyglet.window.mouse.LEFT:
      advance()

  def advance():
    """
    Ask for the next solution, and update our current solution accordingly. If
    we're out of solutions, just print a message.
    """
    nonlocal solgen, current_solution
    try:
      model = next(solgen)
      current_solution = process_model(model)
    except StopIteration:
      print("Out of solutions.")

  advance()
  pyglet.app.run()

def curate_solutions(solgen):
  """
  Converts models to next-list format and writes them into a file.
  """
  with open("patterns.json", "w") as fout:
    fout.write("[\n")
    nl = ""
    for sol in solgen:
      fout.write(nl)
      nl = line(nextlist(process_model(sol))) + "\n"

    fout.write(nl[:-2] + "\n]\n")

def main(prg):
  """
  Main program called automatically by clingo.
  """
  prg.configuration.solve.models = 0
  #prg.ground([("solve",[1, 3, 5, 3])])
  prg.ground([("solve",[])])
  solgen = prg.solve(yield_=True)
  #display_solutions(solgen)
  curate_solutions(solgen)
#end.


#program solve.

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

edge(tile(1, Y)) :- tile(1, Y).
edge(tile(5, Y)) :- tile(5, Y).
edge(tile(X, 1)) :- tile(X, 1).
edge(tile(X, 5)) :- tile(X, 5).

% Start/end parameters
#show start/2.
#show end/2.

% Start at left to break rotational symmetry
1 = {
  start(1, Y)
  : edge(tile(1, Y)),
    Y \ 2 == 1
}.

% End anywhere
1 = {
  end(X, Y)
  : edge(tile(X, Y)),
    X \ 2 == 1,
    Y \ 2 == 1
}.
% Except center-left
:- end(1, 3).

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
