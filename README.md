# shlib
portable functions for posix shell environments

I've sadly written a lot of shell scripts.   Mostly for installers on
completely alien environments.

Really shell code should only be used for boot-strapping to something sane.  Until then you might need some truly portable functions.  I hope you never need to use them, but if you do they are [public domain](http://unlicense.org).  Do whatever you'd like with them.

However acknowledgement (and pull requests) are appreciated.  You can optionally include [license.sh](license.sh) so the next person knows where to find them.

## Usage

Here's an example of how create and compress a custom set of functions.  Using `grep -v '^#' | grep -v ' #' | tr -s '\n'` strips away comments and blank lines.

```bash
cat \
  license.sh \
  is_command.sh \
  uname.sh \
  untar.sh \
  mktmpdir.sh \
  http_download.sh \
  hash_sha256.sh \
  license_end.sh | \
  grep -v '^#' | grep -v ' #' | tr -s '\n'
```

## WIP

Some of these are new, some are these are pulled from old code I wrote.   All can definitely be
improved.  Pull requests very welcome:

* Simplfy
* Clean up local variable use
* Remove any "exit 1" I may have left behind

## Testing

I'm unlikely to work on this in the short term, but.. someone, someday could:

* Probably write the test harness in go, not shell.
* Using travis.ci we can definite test ubuntu, centos and alpine/busybox using docker
* Can we test macOS on travis?  They support something here but unclear how it works.

## Documentation

I've start to write doco in Markdown as shell comments.  The plan would be to extract it to standalone markdown so it would display on GitHub.

