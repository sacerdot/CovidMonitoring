#!/bin/bash

LUOGHI=./luoghi
SERVER=./server
UTENTI=./utenti
OSPEDALE=./ospedale
UTILS=./utils

function rm_file(){
  echo "$1"
  if [ -f "$1" ]; then
    rm $1
  fi
}

for FILE in $LUOGHI $SERVER $UTENTI $OSPEDALE $UTILS; do
    rm_file "${FILE}.beam"
done

erlc $LUOGHI.erl $SERVER.erl $UTENTI.erl $OSPEDALE.erl $UTILS.erl
