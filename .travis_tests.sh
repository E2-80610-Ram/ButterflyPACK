#!/bin/sh
set -e

export RED="\033[31;1m"
export BLUE="\033[34;1m"
printf "${BLUE} GC; Entered tests file:\n"

export DATA_FOLDER=$TRAVIS_BUILD_DIR/EXAMPLE
export EXAMPLE_FOLDER=$TRAVIS_BUILD_DIR/build/EXAMPLE
# export TEST_FOLDER=$TRAVIS_BUILD_DIR/build/TEST

case "${TEST_NUMBER}" in
1) mpirun "-n" "2" "$EXAMPLE_FOLDER/krr" "$DATA_FOLDER/KRR_DATA/susy_10Kn" "8" "10000" "1000" "0.1" "1.0" "2" "2";;
2) mpirun "-n" "2" "$EXAMPLE_FOLDER/ie2d" "1" "10" "5000" "0.08" "1d-4" "0" "4" "16" "0" "1" "2" "200" "0.01d0" "3" "100";;
3) mpirun "-n" "1" "$EXAMPLE_FOLDER/ie2d" "1" "10" "5000" "0.08" "1d-4" "0" "4" "16" "100" "1" "2" "200" "0.01d0" "3" "100";;
4) mpirun "-n" "8" "$EXAMPLE_FOLDER/ie2d" "1" "10" "5000" "0.08" "1d-4" "0" "4" "16" "100" "1" "2" "200" "0.01d0" "3" "0";;
5) mpirun "-n" "2" "$EXAMPLE_FOLDER/ctest" "1" "$DATA_FOLDER/KRR_DATA/susy_10Kn" "8" "1" "0.1" "10.0" "200" "1e-2" "3" "0" "100";;
6) mpirun "-n" "7" "$EXAMPLE_FOLDER/ctest" "2" "1000" "8" "1" "0.1" "10.0" "100" "1e-4" "2" "0" "100";;
7) mpirun "-n" "1" "$EXAMPLE_FOLDER/ctest" "3" "5000" "20" "100" "1e-4" "2" "0" "100";;  # seems to have a bug when nmpi>1
8) mpirun "-n" "5" "$EXAMPLE_FOLDER/full";;
*) printf "${RED} ###GC: Unknown test\n" ;;
esac
