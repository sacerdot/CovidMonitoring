-module(test).
-export([test/0]).


test() ->

    spawn(server, start, []),
    util:sleep(1000),
    spawn(hospital, start, []),
    spawn(places, start, []),
    spawn(users, start, []).
