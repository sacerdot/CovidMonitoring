-module(luoghi).
-export([start/0]).

%link al server
%server ! {new_place, self()}
%può ricevere begin_vist / end_visit
%invia con 25% di prob quando riceve begin_visit il messaggio concat agli utenti presenti
%10% di probabilità chiude  

start() -> vedereComeFare.

luogo()->
	Server = global:whereis_name(server),
	%link al server,
	Server ! {new_place,self()},
	visita([]).

visita(Users)->
	receive
		{begin_visit,User,Ref} -> io:format("inizio visita",[]),
					contatto(User,Users);			
		% invia agli utenti in Users contact con il 25% di probabilità
		% inserire user nella lista. 
		% 10% probabilità di chiudere
		{end_visit, User, Ref} -> io:format("fine visita",[])
		% vedere se in Users è presente la REF e toglierlo se presente
	end,
	visita(Users).

contatto(_, []) -> fine;
contatto(U1, [U2|U] ) -> %non considero che la users abbia Pid,Ref come coppia,  considero che ci sia solo pid. 
		case rand:uniform(4) of
			1 -> U1 ! {contact, U2}
		end,
		contatto(U1,U).

chiudo() -> 
	case ran:uniform(10) of
		1->io:format("chiudo",[]) 
		%penso si debba usare la  exit 
	end.
		
