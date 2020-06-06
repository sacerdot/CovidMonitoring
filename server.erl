-module(server).
-export([start/0]).



start() ->
    io:format("CIAO SONO IL SERVER~n"),
    process_flag(trap_exit, true),
    global:register_name(server, self()),
    io:format("Pid Server ~p~n", [self()]),
    server_loop([]).


server_loop(Places) ->
    receive

        %% messaggi dei protocolli

        {new_place, Pid_Place} ->
            monitor(process,Pid_Place),
            server_loop([Pid_Place|Places]);

        {get_places, Pid_User} ->
            Pid_User ! {places, Places},
            server_loop(Places);

        %% gestione morti attori
        {'DOWN', _ , process, Pid, _ } ->
            server_loop(Places -- [Pid]);

        {'EXIT', _ , Reason} when Reason =:= 'positive'; Reason =:= 'normal';  Reason =:= 'quarantena' ->
            server_loop(Places);

        %% catturiamo una exit sconosciuta
        {'EXIT', _ , Reason} ->
            io:format("Il server sta per morire per ragione ~p~n", [Reason]),
            exit(Reason);

        %% messaggi di ping dei vari attori
        {ciao, da, luogo, Pid} -> io:format("Ciao da luogo ~p~n", [Pid]), server_loop(Places);
        {ciao, da, utente, Pid} -> io:format("Ciao da utente ~p~n", [Pid]), server_loop(Places);
        {ciao, da, ospedale} -> io:format("Ciao da ospedale ~n"), server_loop(Places)



    end.
