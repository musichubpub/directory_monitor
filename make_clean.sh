#/bin/sh
if [ ! -d "libs" ]; then
    mkdir libs
fi
# rm -rf libs/*
rm -rf CMakeFiles
rm -rf cmake_install.cmake
rm -rf CMakeCache.txt
rm -rf Makefile