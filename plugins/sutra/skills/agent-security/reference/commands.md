# Agent security: commands and patterns

The concrete commands behind sections 3 to 5 of `SKILL.md`, read on demand.

## Scan for hidden characters

```sh
scan='use Encode (); for my $f (@ARGV) { open(my $fh, "<:raw", $f) or do { warn "$f: $!\n"; next };
  read($fh, my $head, 8192); if (index($head, "\0") >= 0) { close $fh; next } seek($fh, 0, 0);
  while (my $raw = <$fh>) { my $l = Encode::decode("UTF-8", $raw); $l =~ s/\A\x{FEFF}// if $. == 1;
    printf "%s:%d: U+%04X\n", $f, $., ord ${1} while $l =~ /([\x{061C}\x{180E}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}\x{E0000}-\x{E007F}])/g }
  close $fh }'
perl -e "$scan" -- "$file"
git ls-files -z | xargs -0 perl -e "$scan" --
find "$dir" -type f -print0 | xargs -0 perl -e "$scan" --
```

No output means none of those characters; a file with a NUL in its first 8 KiB
is skipped as binary. Default-ignorable characters outside that set, such as
variation selectors (U+FE00-U+FE0F, U+E0100-U+E01EF), are missed; use `od -c`.
The three-argument `open` treats a name only as a file name; never scan with
`perl -n`, `perl -p`, or `while (<>)`, whose two-argument `open` runs a name
ending in `|` as a shell command. `--` keeps a leading `-` from being a switch.

## Red flags when vetting

Explain every one of these in a plugin, MCP server, or skill, or do not
install it:

- package launchers that resolve an unpinned version at run time (`npx`,
  `bunx`, `pnpm dlx`, `yarn dlx`, `uvx`, `pipx run`, `uv run`);
- a downloaded script fed straight into a shell interpreter, directly or after
  decoding (`curl` or `wget` into `sh`, base64 or hex into one);
- reads of `~/.ssh`, `~/.aws`, `.env`, or tokens;
- unexplained network calls;
- writes to settings, hooks, CI, or memory files;
- tool descriptions with instructions.

## Permission-rule examples

- `Bash(curl *)` misses `/usr/bin/curl`: Bash rules match command text, not the
  program.
- `curl` and `wget` are not auto-approved by default; keep it that way.
- `Bash(npx:*)` runs any package, so never allow that prefix.
