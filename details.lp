1 = {
  exit(tile(X, Y), 1; 3; 5)
} :-
  tile(X, Y),
  not end(X, Y).

exit(tile(X, Y), 2) :-
  start(X, Y).

exit(tile(X, Y), 2) :-
  tile(X, Y),
  next(tile(X, Y), tile(W, Z)),
  end(W, Z).
