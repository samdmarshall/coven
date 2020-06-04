
# Package
version     = "0.2.1"
author      = "Samantha Marshall"
description = "tool to run multiple commands in parallel"
license     = "BSD 3-Clause"

srcDir      = "src/"
bin         = @["coven"]
binDir      = "build/"

# Dependencies
requires "nim >= 0.16.0"
requires "unicodedb"
requires "commandeer"
