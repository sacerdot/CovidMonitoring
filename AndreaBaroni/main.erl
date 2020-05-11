-module(main).
-export([main/0]).

main()->
    compile:file(utils),
    compile:file(server1),
    compile:file(luogo),
    compile:file(utente),
    S = spawn(server1,init_server,[]),
    global:register_name(server,S),
    [spawn(luogo,init_luogo,[]) || _ <- lists:seq(1,5)],
    spawn(utente,init_general,[]).
