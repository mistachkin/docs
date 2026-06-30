# Commands: Data, Encoding & Networking

`sql` · `uri` · `xml` · `base64` · `hash` · `guid`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
None of these six commands exist in standard Tcl — they wrap the .NET BCL
(`System.Convert`, `System.Security.Cryptography`, `System.Guid`, `System.Uri`,
`System.Xml`, ADO.NET). Deep dives: [`../../../../uri.md`](../../../../uri.md) (HTTP client,
callbacks, async transfers) and [`../../../../sql.md`](../../../../sql.md) (ADO.NET,
script-bundle databases).

> **Boolean-result trap (verified, and it is *not* uniform).** Predicate
> sub-commands split two ways. `uri isvalid`, `uri scheme`, `uri offline`,
> `sql isopen`, and `sql hasbegun` return **`True`/`False`**. But `guid isvalid`
> and `guid isnull` return **`1`/`0`**. The `*compare` sub-commands
> (`guid compare`, `uri compare`) return **`-1`/`0`/`1`** like `[string
> compare]`. Treat every result as a boolean/number — never compare it to the
> literal string `"1"`. See gotcha #1.

---

## `base64`

`base64 encode ?-encoding enc? string` · `base64 decode ?-encoding enc? string`

Two sub-commands. Wraps `System.Convert.ToBase64String` /
`FromBase64String`. `-encoding` selects the text encoding used to turn the
string into bytes before encoding (and back after decoding); it defaults to the
interpreter's encoding.

```tcl
base64 encode "Hello, Eagle!"                 ;# => SGVsbG8sIEVhZ2xlIQ==
base64 decode SGVsbG8sIEVhZ2xlIQ==            ;# => Hello, Eagle!
base64 decode [base64 encode "abc"]           ;# => abc   (round-trip)
```

With an explicit encoding the round-trip preserves non-ASCII text:

```tcl
base64 encode -encoding utf-8 "café"                              ;# => Y2Fmw6k=
base64 decode -encoding utf-8 [base64 encode -encoding utf-8 café] ;# => café
```

## `hash`

`hash list ?type?` · `hash normal ?options? algorithm string` ·
`hash mac ?options? algorithm string ?key?` · `hash keyed ?options? ...`

Four sub-commands: `list`, `normal` (plain digest), `mac` (keyed HMAC), and
`keyed` (keyed-hash algorithms; **empty in this build** — `hash list keyed`
returns nothing). Options for `normal`/`mac`/`keyed`: `-object`, `-raw`,
`-filename`, `-encoding`. `-filename` hashes a file instead of a string; `-raw`
returns the digest as raw bytes instead of hex.

> **Digests are returned as UPPERCASE hex** (a 32-byte SHA-256 is 64 hex
> chars). They match lowercase tools like `openssl` case-insensitively.

```tcl
hash list normal     ;# => {normal MD5} {normal SHA1} {normal SHA256} {normal SHA384} {normal SHA512}
hash list mac        ;# => {mac HMACMD5} {mac HMACSHA1} {mac HMACSHA256} {mac HMACSHA384} {mac HMACSHA512}
```

`hash normal` — verified against the canonical `"abc"` test vectors:

```tcl
hash normal sha256 "abc"  ;# => BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD
hash normal sha1   "abc"  ;# => A9993E364706816ABA3E25717850C26C9CD0D89D
hash normal md5    "abc"  ;# => 900150983CD24FB0D6963F7D28E17F72
string length [hash normal sha256 "abc"]   ;# => 64
```

> **`hash mac` argument order: `algorithm string ?key?` — the key is the
> THIRD (optional) argument, the data is second.** It is easy to swap them.
> Verified against `openssl dgst -sha256 -hmac key` (HMAC of message `"message"`
> with key `"key"`):

```tcl
hash mac HMACSHA256 "message" "key"
;# => 6E9EF29B75FFFC5B7ABAE527D58FDADB2FE42E7219011976917343065F58ED4A
```

## `guid`

`guid new` · `guid null` · `guid isvalid string` · `guid isnull guid` ·
`guid compare guid1 guid2`

Five sub-commands. `new` mints a v4 GUID; `null` is the all-zero GUID.

> `guid isvalid` and `guid isnull` return **`1`/`0`** (not `True`/`False`);
> `guid compare` returns **`-1`/`0`/`1`**.

```tcl
guid new              ;# => 71efe19d-976c-4ca4-8333-9c9b1882251d  (random each call)
guid null             ;# => 00000000-0000-0000-0000-000000000000

guid isvalid [guid new]      ;# => 1
guid isvalid "not-a-guid"    ;# => 0
guid isvalid {}              ;# => 0

guid isnull [guid null]      ;# => 1
guid isnull [guid new]       ;# => 0

guid compare [guid null] [guid null]                                  ;# => 0
guid compare 00000000-0000-0000-0000-000000000000 \
             11111111-1111-1111-1111-111111111111                     ;# => -1
guid compare ffffffff-ffff-ffff-ffff-ffffffffffff \
             00000000-0000-0000-0000-000000000000                     ;# => 1
```

## `uri`

18 sub-commands. URI utility ops are always available; the **network** ops
require Eagle built with the `NETWORK` flag.

- **Parse/construct:** `parse`, `create`, `join`, `host`, `scheme`
- **Validate/compare:** `isvalid`, `compare`
- **Encode:** `escape`, `unescape`
- **Network (require `NETWORK`):** `download`, `get`, `upload`, `post`,
  `ping`, `time`, `offline`, `security`, `softwareupdates`

Full HTTP-client semantics (inline vs file mode, `-callback` async transfers,
retry/offline infrastructure, the four per-interpreter web callbacks) are in
[`../../../../uri.md`](../../../../uri.md).

### Parse / construct (verified)

```tcl
uri parse {https://user:pass@example.com:8443/a/b?x=1&y=2#frag}
;# => -scheme https -host example.com -port 8443 -username user -password pass \
;#    -path /a/b -query ?x=1&y=2 -fragment #frag

uri create https api.example.com -port 8443 -path /v2/users \
    -query "role=admin" -fragment top
;# => https://api.example.com:8443/v2/users?role=admin#top

uri join a b c              ;# => a/b/c
```

> `uri parse` keeps the leading `?` on `-query` and the leading `#` on
> `-fragment`.

`uri host` validates a host string and returns its **`UriHostNameType`** (not a
boolean); `uri scheme` validates a scheme name and returns a **boolean**:

```tcl
uri host example.com       ;# => Dns
uri host 192.168.0.1       ;# => IPv4
uri host ::1               ;# => IPv6
uri host "bad host!"       ;# => Unknown
uri scheme https           ;# => True
```

### Validate / compare (verified)

```tcl
uri isvalid https://example.com/             ;# => True
uri isvalid https://example.com/ Absolute    ;# => True
uri isvalid "not a uri" Absolute             ;# => False

uri compare https://example.com/ https://example.com/   ;# => 0
uri compare https://a.com/ https://b.com/               ;# => -1
```

`isvalid`'s optional kind is `Absolute`, `Relative`, or `RelativeOrAbsolute`.
`compare` takes `-kind`/`-components`/`-format`/`-comparison`/`-nocase` options.

### Encode (verified)

`uri escape type string` where `type` is `None`, `Uri`, or `Data`. `Uri`
preserves URI delimiters (`/ ? = &`); `Data` escapes them too.

```tcl
uri escape Uri  "a b/c?d=e&f"     ;# => a%20b/c?d=e&f
uri escape Data "a b/c?d=e&f"     ;# => a%20b%2Fc%3Fd%3De%26f
uri unescape "a%20b%2Fc"          ;# => a b/c
```

### Network operations

These need a `NETWORK` build (and, obviously, connectivity). The locally
inspectable ones are verified here; live transfers are **not** run offline —
see [`../../../../uri.md`](../../../../uri.md) for `download`/`get`/`upload`/`post`/`ping`/
`time` recipes.

`uri offline` is a reference-counted boolean switch (query / set):

```tcl
uri offline          ;# => False
uri offline true ; uri offline      ;# => True
uri offline false ; uri offline     ;# => False
```

`uri security` returns a name/value list describing offline state, network
timeout, the negotiated security protocol, and software-update status
(verified; the public-key fields are long and elided here):

```tcl
uri security
;# => offline False timeout {} probedOk {FailSafe, BrokenOnWindows10OrHigher} \
;#    getError {best security protocol unavailable} updates(trusted) False \
;#    updates(exclusive) False updates(publicKey1) {...} ... updates(useLegacy) False
```

- `uri download ?options? uri ?fileName?` — defaults to **file** mode; `-inline`
  returns the body as a string. **Requires network.**
- `uri get ?options? uri ?fileName?` — defaults to **inline** mode. **Requires
  network.**
- `uri upload` / `uri post` — file vs inline upload (form-encoded by default;
  `-raw` for raw bytes, `-method` to override `POST`). **Requires network.**
- `uri ping hostOrUri timeout`, `uri time`, `uri softwareupdates` — **require
  network.**

## `xml`

`xml serialize ?options? type object` · `xml deserialize ?options? type xml` ·
`xml foreach ?options? varName xml body` · `xml validate schemaXml documentXml`

Four sub-commands wrapping `System.Xml.Serialization.XmlSerializer`,
`XmlDocument`, and XSD validation. `serialize`/`deserialize` take a **.NET type
name** plus an object handle / XML string; `foreach` options are `-file`,
`-namespaces`, `-xpaths`.

`serialize` / `deserialize` round-trip (verified with a `string[]`):

```tcl
set a [object create -alias "System.String\[\]" 2]
$a SetValue one 0 ; $a SetValue two 1
xml serialize "System.String\[\]" $a
;# => <?xml version="1.0" encoding="utf-8"?>
;#    <ArrayOfString xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ...>
;#      <string>one</string>
;#      <string>two</string>
;#    </ArrayOfString>

set back [xml deserialize -alias "System.String\[\]" [xml serialize "System.String\[\]" $a]]
list [$back Length] [$back GetValue 0] [$back GetValue 1]   ;# => 2 one two
```

> `xml foreach` binds `varName` to an **opaque .NET node handle**, not an
> auto-aliased command — invoke members with `[object invoke $node ...]`:

```tcl
set doc {<root><item>a</item><item>b</item></root>}
xml foreach -xpaths //item node $doc {
    puts [object invoke $node InnerText]
}
;# => a
;#    b
```

`xml validate` returns the **empty string on success** and raises a
`System.Xml.Schema.XmlSchemaValidationException` on failure:

```tcl
set xsd {<?xml version="1.0"?>
  <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xs:element name="note" type="xs:string"/>
  </xs:schema>}
xml validate $xsd {<?xml version="1.0"?><note>hello</note>}    ;# => (empty: valid)

# A type mismatch (xs:integer vs text) raises:
catch {xml validate [string map {xs:string xs:integer} $xsd] \
    {<?xml version="1.0"?><note>hello</note>}} e
;# => System.Xml.Schema.XmlSchemaValidationException: The 'note' element is invalid
;#    - The value 'hello' is invalid according to its datatype '...:integer' ...
```

## `sql`

9 sub-commands over ADO.NET — works with any .NET data provider (SQLite, SQL
Server, ODBC, OLE DB, Oracle) through `IDbConnection`/`IDbCommand`/
`IDataReader`. `[sql]` is `Unsafe` (hidden in safe interpreters). The full
option surface (result formats, `-variable` auto-cleanup via DbTraceCallback,
parameter binding, profiling, signed script-bundle databases) is in
[`../../../../sql.md`](../../../../sql.md).

- **Connections:** `open`, `close`, `isopen`, `connection`, `types`
- **Queries:** `execute`, `foreach`
- **Transactions:** `transaction` (begin/commit/rollback), `hasbegun`

`sql types` lists the providers resolvable in this build (names only):

```tcl
lsort -unique [lmap p [sql types] {lindex $p 0}]
;# => None Oracle SQLite SQLiteEnterprise SqlCe
sql isopen nope          ;# => False
```

This build ships **System.Data.SQLite**, so the following are verified live
against an in-memory database.

```tcl
set conn [sql open -type SQLite "Data Source=:memory:"]
sql execute -execute NonQuery $conn "CREATE TABLE t(x);"
sql execute -execute NonQuery $conn "INSERT INTO t VALUES(42);"
sql execute -execute Scalar   $conn "SELECT x FROM t;"        ;# => 42
sql close $conn
```

> SQLite auto-upgrades: `-type SQLite` (with no `-type2`) tries
> `SQLiteEnterprise` first, then falls back to standard `SQLite`.

**Parameterized queries** (always prefer these over string interpolation). A
parameter is a list `{name ?DbType? ?value? ?size?}`:

```tcl
set c [sql open -type SQLite "Data Source=:memory:"]
sql execute -execute NonQuery $c "CREATE TABLE t(x);"
sql execute -execute NonQuery $c "INSERT INTO t VALUES(@v)" {@v Int32 7}
sql execute -execute Scalar   $c "SELECT x FROM t WHERE x=@v" {@v Int32 7}   ;# => 7
sql close $c
```

**Result formats** (`-execute Reader -format <fmt>`, verified):

```tcl
# Given a table t(x,y) holding rows (1,2) and (3,4):
sql execute -execute Reader -format list       $c "SELECT x,y FROM t;"   ;# => 1 2 3 4
sql execute -execute Reader -format nestedlist $c "SELECT x,y FROM t;"   ;# => {1 2} {3 4}
sql execute -execute Reader -format dictionary $c "SELECT x,y FROM t;"   ;# => x 1 y 2   (first row)

# -format array fills an array variable (default name: rows):
sql execute -execute Reader -format array -rowsvar rows $c "SELECT x,y FROM t;"
;# rows(count) => 2 ; rows(names) => x y ; rows(1) => {x 1} {y 2} ; rows(2) => {x 3} {y 4}
```

> **`sql foreach` row access is per-row-number, not per-column.** The row
> variable (default name `row`) is an **array keyed by the 1-based row number**;
> each value is shaped by `-format`. `$row(columnName)` does **not** work. Pull
> the current row out and index it by format:

```tcl
sql foreach -execute Reader -format Dictionary $conn \
        "SELECT id, name FROM users ORDER BY id;" {
    set r [lindex [array get row] 1]      ;# the {col val ...} dict for this row
    puts "[dict get $r id] = [dict get $r name]"
}
;# => 1 = Alice
;#    2 = Bob
```

**Transactions** — `begin` returns a handle; `hasbegun` reports status
(`True`/`False`):

```tcl
set conn [sql open -type SQLite "Data Source=:memory:"]
sql execute -execute NonQuery $conn "CREATE TABLE t(x);"
set tx [sql transaction begin $conn]
sql hasbegun $tx                                                  ;# => True
sql execute -execute NonQuery -transaction $tx $conn "INSERT INTO t VALUES(1);"
sql transaction commit $tx
sql hasbegun $tx                                                  ;# => False
sql execute -execute Scalar $conn "SELECT COUNT(*) FROM t;"       ;# => 1
sql close $conn
```

`sql transaction` takes `-isolation` (`Unspecified`, `ReadUncommitted`,
`ReadCommitted`, `RepeatableRead`, `Serializable`) and `-variable` (auto
commit/rollback when the variable leaves scope). For SQL Server, Oracle, ODBC,
and OLE DB the only change is the `-type` and connection string — those
providers are **not** exercised here (no server reachable); see
[`../../../../sql.md`](../../../../sql.md).
