#!/bin/bash

files_list=(hospital server users util places test)

function rm_file(){
  if [ -f "$1" ]; then
    rm $1
  fi
}

for file in ${files_list[@]}
do
  echo Removing $file
  rm_file $file.beam
done

for file in ${files_list[@]}
do
  echo Compiling $file
  erl -compile $file
done
