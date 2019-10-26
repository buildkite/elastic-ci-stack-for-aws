#!/usr/bin/env bash

# Converts human-readable units like 1.43K and 120.3M to bytes
dehumanize() {
  awk '/[0-9][bB]?$/ {printf "%u\n", $1*1}
       /[tT][bB]?$/  {printf "%u\n", $1*(1024*1024*1024*1024)}
       /[gG][bB]?$/  {printf "%u\n", $1*(1024*1024*1024)}
       /[mM][bB]?$/  {printf "%u\n", $1*(1024*1024)}
       /[kK][bB]?$/  {printf "%u\n", $1*1024}' <<< "$1"
}
