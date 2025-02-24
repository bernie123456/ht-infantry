name: Build

on:
  push:
    branches: [ master ]
    tags:
    - '*'
  pull_request:
    branches: [ master ]
  release:
    types: [published, created, edited]

env:
  VERSION: @VERSION@
  CTEST_EXT_COLOR_OUTPUT: TRUE
  CTEST_OUTPUT_ON_FAILURE: 1
  CTEST_BUILD_FLAGS: -j4
  SDL_AUDIODRIVER: dummy
  SDL_VIDEODRIVER: dummy

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            cc: gcc
            cc_version: latest
          - os: ubuntu-latest
            cc: gcc
            cc_version: 11
          - os: ubuntu-latest
            cc: clang
            cc_version: latest
          - os: ubuntu-latest
            cc: clang
            cc_version: 12
          - os: macos-latest
            cc: /usr/bin/clang

    steps:
    - name: Checkout
      uses: actions/checkout@v2

    - name: Install Protoc
      uses: arduino/setup-protoc@v1.1.2
      with:
        version: '3.12.3'
        repo-token: ${{ secrets.GITHUB_TOKEN }}

    - name: Check protoc
      run: |
        protoc --version

    - name: Install packages Linux
      if: matrix.os == 'ubuntu-latest'
      run: |
        sudo apt-get update
        sudo apt install libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev gcc-10 g++-10 libgtk-3-dev python3-pip
        python3 -m pip install protobuf
        pip3 install --upgrade protobuf

    - name: Set up GCC
      if: matrix.os == 'ubuntu-latest' && matrix.cc == 'gcc'
      uses: egor-tensin/setup-gcc@v1
      with:
        version: ${{ matrix.cc_version }}

    - name: Set up Clang
      if: matrix.os == 'ubuntu-latest' && matrix.cc == 'clang'
      uses: egor-tensin/setup-clang@v1
      with:
        version: ${{ matrix.cc_version }}

    - name: Install packages macOS
      if: matrix.os == 'macos-latest'
      run: |
        python3 -m pip install protobuf
        pip3 install --upgrade protobuf
        build/macosx/install-sdl2.sh

    - name: Configure CMake
      env:
        CC: ${{ matrix.cc }}
      # Configure CMake in a 'build' subdirectory. `CMAKE_BUILD_TYPE` is only required if you are using a single-configuration generator such as make.
      # See https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html?highlight=cmake_build_type
      run: cmake -DCMAKE_BUILD_TYPE=${{env.BUILD_TYPE}} -DCMAKE_INSTALL_PREFIX=. -DDATA_INSTALL_DIR=. -Wno-dev .

    - name: Build
      # Build your program with the given configuration
      run: make

    - name: Test
      working-directory: ${{github.workspace}}
      # Execute tests defined by the CMake configuration.  
      # See https://cmake.org/cmake/help/latest/manual/ctest.1.html for more detail
      run: ctest -VV -S

    - name: Make package on tags
      if: startsWith(github.ref, 'refs/tags/')
      run: |
        make package

    - name: Upload a Build Artifact
      uses: softprops/action-gh-release@v1
      if: startsWith(github.ref, 'refs/tags/')
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        files: ${{ github.workspace }}/C-Dogs*SDL-*-*.*
        fail_on_unmatched_files: true

    - name: Publish to itch.io (Linux)
      if: startsWith(github.ref, 'refs/tags/') && matrix.os == 'ubuntu-latest' && matrix.cc == 'gcc' && matrix.cc_version == 'latest' && !github.event.release.prerelease
      env:
        BUTLER_API_KEY: ${{ secrets.BUTLER_API_KEY }}
      run: |
        curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
        unzip butler.zip
        chmod +x butler
        ./butler -V
        ./butler push C-Dogs*SDL-*-Linux.tar.gz congusbongus/cdogs-sdl:linux --userversion $VERSION

    - name: Publish to itch.io (macos)
      if: startsWith(github.ref, 'refs/tags/') && matrix.os == 'macos-latest' && !github.event.release.prerelease
      env:
        BUTLER_API_KEY: ${{ secrets.BUTLER_API_KEY }}
      run: |
        curl -L -o butler.zip https://broth.itch.ovh/butler/darwin-amd64/LATEST/archive/default
        unzip butler.zip
        chmod +x butler
        ./butler -V
        ./butler push C-Dogs*SDL-*-OSX.dmg congusbongus/cdogs-sdl:mac --userversion $VERSION
