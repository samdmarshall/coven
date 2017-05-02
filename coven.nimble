# Package
version = "0.1"
author = "Samantha Marshall"
description = "tool to run multiple commands in parallel"
license = "BSD 3-Clause"

srcDir = "src"

bin = @["coven"]

skipExt = @["nim"]

# Dependencies
requires "nim >= 0.16.0"
