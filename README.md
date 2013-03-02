Homebrew Linux Port
===================
This is the Linux port of Homebrew.

The regular Homebrew software can be found at:

http://wiki.github.com/mxcl/homebrew/

This was originally started by Sergio Rubio (http://github.com/rubiojr)
This is my fork of the project, which seems abandoned.

Goals
-----
I expect this to wind up being quite different from Homebrew, 
because of the difference in targets if nothing else, but Homebrew 
is an amazingly functional system and the community that supports it
is every bit as impressive.

Differences
-----------
Homebrew wants to live in /usr/local, which is far safer on OS X.
We're going to use /boom or ~/boom, and see how that works out but
may have to fall back to /opt/boom or an alternative.

Experiments with LD_PRELOAD and LD_LIBRARY_PATH have been promising,
but to start, we're going to be trading off disk space for isolation
and building everything in /boom.  Filesystem links will reduce pure
redundancy, but if the same version of a specific library is built 
with different options, the two products will be treated as distinct
objects.

*nix variants can be esoteric and strange.  The Formula syntax will
have to be extended to support different architectures (arm, mips, etc)
but it doesn't seem like that will stretch the framework excessively.

Installation
------------

http://blog.frameos.org/2010/11/10/mac-homebrew-ported-to-linux/
