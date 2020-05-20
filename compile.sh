#!/bin/bash

files_list=(test hospital server usersnew util places)

for file in ${files_list[@]}
do
  echo Removing $file
  rm $file.beam
done

for file in ${files_list[@]}
do
  echo Compiling $file
  erl -compile $file
done