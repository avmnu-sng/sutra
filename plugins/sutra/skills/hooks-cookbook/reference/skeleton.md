# Hooks cookbook: the fail-open skeleton

Every hook starts the same way. Copy this shape; replace steps 2-5. Section 2
of `SKILL.md` says why each guard exists.

```bash
#!/usr/bin/env bash
set -u   # not -e: an ordinary nonzero must not abort the hook mid-run

# 0. No stdin (run by hand) or an empty payload: nothing to check.
[ -t 0 ] && exit 0
payload="$(cat 2>/dev/null)" || exit 0
[ -n "$payload" ] || exit 0

# 1. Pick a JSON tool: jq, else perl's core JSON::PP, else a silent no-op.
if command -v jq >/dev/null 2>&1; then json=jq
elif perl -MJSON::PP -e 1 >/dev/null 2>&1; then json=perl
else exit 0
fi

# json_get a.b prints that payload field as text; nothing when absent.
json_get() {
  if [ "$json" = jq ]; then
    printf '%s' "$payload" |
      jq -r --arg p "${1}" 'getpath($p | split("."))? | scalars | values' 2>/dev/null
  else
    printf '%s' "$payload" | perl -MJSON::PP -e '
      my $v = eval { JSON::PP->new->utf8->decode(do { local $/; <STDIN> }) };
      $v = ref $v eq "HASH" ? $v->{$_} : undef for split /\./, $ARGV[0];
      $v = $v ? "true" : "false" if JSON::PP::is_bool($v);
      if (defined $v && !ref $v) { utf8::encode($v); print $v }' -- "${1}" 2>/dev/null
  fi
}

# reply KEY VALUE... prints one JSON object; a dotted KEY nests.
reply() {
  if [ "$json" = jq ]; then
    jq -nc '$ARGS.positional as $a | reduce range(0; $a | length; 2) as $i
      ({}; setpath($a[$i] | split("."); $a[$i + 1]))' --args -- "$@"
  else
    perl -MJSON::PP -e '
      my %o;
      while (my ($k, $v) = splice @ARGV, 0, 2) {
        my @path = split /\./, $k;
        my $leaf = pop @path;
        my $h = \%o;
        $h = $h->{$_} //= {} for @path;
        utf8::decode($v);
        $h->{$leaf} = $v;
      }
      print JSON::PP->new->ascii->canonical->encode(\%o), "\n";' -- "$@"
  fi
}

# 2. Early-return unless THIS event is relevant. Cheapest test first.
file="$(json_get tool_input.file_path)"
case "$file" in *.rb|*.go|*.ts) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

# 3. The checker is absent? No-op: never block on a tooling gap.
command -v mychecker >/dev/null 2>&1 || exit 0

# 4. Run the checker. Clean result: succeed silently.
report="$(mychecker "$file" 2>&1)" && exit 0

# 5. Translate the failure into a reply (an advisory to the user here).
reply systemMessage "mychecker flagged $file:
$(printf '%s\n' "$report" | tail -n 3)"
exit 0
```
