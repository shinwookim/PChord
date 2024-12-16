
# PChord: Towards A Error-Free Distributed Hash Table using P
> [Chord](https://pdos.csail.mit.edu/papers/chord:sigcomm01/chord_sigcomm.pdf) is a simple protocol for creating distributed hash tables in a peer-to-peer computing environment. This is an implementation of that protocol using the [P programming language](https://p-org.github.io/P/) that aims to provide guarantees for various correctness, using model-checking to validate correctness specifications.


## Setup

Install the P language toolchain (compiler and model-checker).
+ P is built to be cross-platform and can be used on MacOS, Linux, and Windows. Instructions on installing P can be found [here](https://p-org.github.io/P/getstarted/install/).
+ Note that P requires .NET Core SDK and a Java run-time to be installed.

You can verify that P is installed by running `p -v`.
```shell-session
$ p --version
P version 2.3.1.0
~~ [PTool]: Thanks for using P! ~~
```
## Compiling a P Program
A program can be compiled by passsing all the P files (`*.p`) to the P compiler. For convenience, we provide a *P project file* (`PChord.pproj`) which already pre-specifies the required inputs.

To compile, you can run `p compile`.
```shell-session
$ p compile
.. Searching for a P project file *.pproj locally in the current folder
.. Found P project file: ./PChord/PChord.pproj
----------------------------------------
==== Loading project file: ./PChord/PChord.pproj
....... includes p file: ./PChord/PSrc/Chord.p
....... includes p file: ./PChord/PSrc/Client.p
....... includes p file: ./PChord/PSrc/Node.p
==== Loading project file: ./PChord/Common/FailureInjector/FailureInjector.pproj
....... includes p file: ./PChord/Common/FailureInjector/PSrc/FailureInjector.p
....... includes p file: ./PChord/Common/FailureInjector/PSrc/NetworkFunctions.p
----------------------------------------
Parsing ...
Type checking ...
----------------------------------------
Code generation for CSharp...
Generated PChord.cs.
Compiling generated code...

Build succeeded.

Time Elapsed 00:00:04.42

----------------------------------------
Compilation succeeded.
~~ [PTool]: Thanks for using P! ~~
```

## Running Tests

Compiling a P program generates a `dll` file which is a C# representation of the P program. The P checker uses this `dll` file as its input and systematically explores behaviors of the program for the specified test case.

You can get the list of test cases defined in the P program by running the P Checker:
```sh
  p check
```
Then, you can run the model checker on a specific case by running:
```sh
p check -tc <testcase>
```


## Authors
This project was developed as part of the CS 3551 (Advanced Topics in Distributed Information Systems) course at the University of Pittsburgh. The main contributors are: **Shinwoo Kim** and **Derrick Hicks**.