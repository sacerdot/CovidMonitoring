-module(main).
-export([main/0]).

main()->
    compile:file(server1),
    compile:file(luogo),
    S = spawn(server1,init_server,[]),
    global:register_name(server,S).
    %[spawn(luogo,init_luogo,[]) || _ <- lists:seq(1,5)].
