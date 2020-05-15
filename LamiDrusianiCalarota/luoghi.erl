-module(luoghi).
-export([start/0]).


start() -> vedereComeFare.

luogo()->
	Server = global:whereis_name(server),
	%link al server,
	Server ! {new_place,self()},
	visita([]).

visita(Users)->
	receive
		{begin_visit,User,Ref} -> 
			io:format("inizio visita",[]),		
			contatto(User,Users),
		        chiudo(),	
			visita(Users++{User, Ref});			
		{end_visit, User, Ref} -> 
			io:format("fine visita",[]),
			visita(lists:delete({User, Ref}, Users))
	end.

contatto(_, []) -> fine;
contatto(U1, [{U2,_}|U] ) -> 
		case rand:uniform(4) of
			1 -> U1 ! {contact, U2}
		end,
		contatto(U1,U).

chiudo() -> 
	case rand:uniform(10) of
		1->io:format("chiudo",[]),
		exit(ho_chiuso) %chiedere al prof per quanto riguarda il tag di Reason per la chiusura del luogo 
		%penso si debba usare la  exit 
	end.
		
