-module(luoghi).
-export([start/0, luogo/0]).


% Avvio Luoghi in N attori (N = 10) 
start() -> 
    io:format('Creo un luogo~n'),
    [spawn(fun luogo/0) || _ <- lists:seq(1,10)].


% Creazione luogo e comunicazioni al Server  
luogo()->
    Server = global:whereis_name(server),
    link(Server),
    Server ! {new_place,self()},
    visita([]).


% Protocollo delle visite di un luogo 
visita(Users)->
    receive
        {begin_visit,User,Ref} -> 
            io:format("Inizio visita~n",[]),
            % Creazione attore per routine contatto
            spawn(fun() -> contatto(User,Users) end),
            % Probabilità di chiusura (cioè morte) del luogo 
            chiudo(),
            visita(Users++[{User, Ref}]);           
        {end_visit, User, Ref} -> 
            io:format("Fine visita~n",[]),
            visita(Users--[{User, Ref}])
    end.


% Protocollo di avviso dei contatti
contatto(_, []) -> fine;
% Itero ricorsivamente sulla lista degli utenti e li contatto con 25% di probabilità
contatto(U1, [{U2,_}|U] ) -> 
        case rand:uniform(4) of
            1 -> U1 ! {contact, U2},
                 % se U1 muore prima di fare il link devo comunque avvisare U2 di linkarsi e quindi morie (tanto il link e idempotente)
                 U2 ! {contact, U1};
            _ -> ok
        end,
        contatto(U1,U).


% Protocollo chiusura luoghi
% Chiusura del luogo avviene col 10% di probabilità
chiudo() ->
    case rand:uniform(10) of
        1->
            io:format("Chiudo. Sono il luogo: ~p~n",[self()]),
            exit(normal);
        _ -> ok 
    end.
