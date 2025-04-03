#!/bin/bash

folder=$(pwd)
examples=$(dirname "$folder")
parent=$(dirname "$examples")

source "$parent/resources/scripts/cluster-destroy.sh"
