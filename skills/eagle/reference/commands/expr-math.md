# Commands: Expressions & Math

`expr` · every `[expr]` operator · every `[expr]` math function · `fpclassify`

All examples below were **executed** against Eagle 1.0 (see
[`../verification.md`](../verification.md)); `;# =>` shows the verified result.
Cross-cutting Tcl differences live in [`../tcl-gotchas.md`](../tcl-gotchas.md).
The authoritative names come from `[info operators]` / `[info functions]` and the
source dirs `Eagle/Library/Operators/` and `Eagle/Library/Functions/`.

> Reminder (gotcha #1): boolean / comparison / logical results print
> **`True`/`False`**. They behave as `1`/`0` in every numeric and boolean
> context — `expr {(1<2)+(3>4)}` => `1` — but **never** string-compare one to
> `"1"`/`"0"` (`expr {(1<2) eq "1"}` => `False`).

---

## `expr`

`expr arg ?arg ...?` — concatenates its arguments (with spaces) and evaluates the
result as an expression. **Always brace the expression** (`expr {...}`): it is
faster, and it stops Tcl's parser from substituting before `expr` sees the text.

```tcl
expr {2 + 3}                 ;# => 5
expr 2 + 3                   ;# => 5      (unbraced works but is slower/unsafe)
set x 5; expr {$x * 2}       ;# => 10
expr {1 < 2}                 ;# => True
```

Numeric model notes (all verified; see gotcha #6 and the function notes below):

* Integer math is **64-bit and wraps** — there is *no* automatic bignum
  promotion: `expr {9223372036854775807 + 1}` => `-9223372036854775808`. Use
  `entier(...)` to opt into arbitrary precision.
* Whole-valued floating results print **without a trailing `.0`**
  (`expr {double(5)}` => `5`, `expr {sqrt(4)}` => `2`), where every Tcl version
  prints `5.0` / `2.0`. The value is still floating/decimal-typed.
* `[expr]` uses a `Decimal`-based model for decimal literals, so
  `expr {10 / 3.0}` => `3.3333333333333333333333333333` (Tcl 8.5/8.6:
  `3.3333333333333335`). `expr {1.0 / 0.0}` **raises** a divide-by-zero math
  exception; force IEEE doubles with `double(...)` for `∞`/`NaN` (below).

---

## Operators

Every operator recognized by Eagle (from `[info operators]`), grouped. Eagle
extends Tcl with `**` (present since it adopted that 8.5 feature), the rotate
operators `<<<` / `>>>`, the bitwise/logical implication & equivalence operators
`->` `<->` `=>` `<=>`, logical XOR `^^`, the string ordering operators
`lt gt le ge`, and the in-expression assignment operator `:=`.

| Group | Operators |
|-------|-----------|
| Arithmetic | `+`  `-`  `*`  `/`  `%`  `**` |
| Numeric comparison | `==`  `!=`  `<`  `>`  `<=`  `>=` |
| String comparison | `eq`  `ne`  `lt`  `gt`  `le`  `ge` |
| List membership | `in`  `ni` |
| Bitwise | `~`  `&`  `\|`  `^`  `->` (imp)  `<->` (eqv) |
| Logical | `!`  `&&`  `\|\|`  `^^` (xor)  `=>` (imp)  `<=>` (eqv) |
| Shift / rotate | `<<`  `>>`  `<<<` (rotL)  `>>>` (rotR) |
| Conditional | `? :` |
| Assignment | `:=` |

> **Bitwise vs logical implication/equivalence — read carefully.** Per the
> source and `[info operators]`: `->`/`<->` are the **bitwise** imp/eqv
> (`~a|b` and `~(a^b)`), while `=>`/`<=>` are the **logical** imp/eqv. (The
> operators `~&` / `~|` do **not** exist.) See DOC ISSUES at the end of this
> skill's build notes — `core_language.md` currently swaps these.

### Arithmetic

```tcl
expr {7 + 3}                 ;# => 10
expr {7 - 3}                 ;# => 4
expr {7 * 3}                 ;# => 21
expr {7 / 3}                 ;# => 2     (integer division floors)
expr {-7 / 2}                ;# => -4    (floors toward -inf, like Tcl, not .NET)
expr {7 % 3}                 ;# => 1
expr {7 % -3}                ;# => -2    (result takes the sign of the DIVISOR)
expr {2 ** 10}               ;# => 1024
expr {2 ** 3 ** 2}           ;# => 512   (** is right-associative: 2 ** (3 ** 2))
expr {2 ** -1}               ;# => 0     (integer ** with a negative exponent)
catch {expr {5 % 0}} m; set m   ;# => caught math exception: System.DivideByZeroException...
```

### Comparison & string comparison

Numeric `==`/`!=`/`<`… coerce operands to numbers; the word operators
`eq`/`ne`/`lt`/`gt`/`le`/`ge` always compare as **strings** (no coercion).

```tcl
expr {3 < 5}                 ;# => True
expr {5 <= 5}                ;# => True
expr {3 == 3}                ;# => True
expr {3 != 4}                ;# => True
expr {10 == "10.0"}          ;# => True    (numeric: coerced, equal)
expr {"abc" eq "abc"}        ;# => True
expr {"abc" ne "abd"}        ;# => True
expr {"abc" lt "abd"}        ;# => True
expr {"b" gt "a"}            ;# => True
expr {"a" le "a"}            ;# => True
expr {"b" ge "a"}            ;# => True
expr {"10" eq "10.0"}        ;# => False   (string: "10" != "10.0", no coercion)
```

### List membership (`in` / `ni`)

String membership — element matching is by **string**, not number.

```tcl
expr {"b" in {a b c}}        ;# => True
expr {"z" ni {a b c}}        ;# => True
expr {1 in {1.0 2.0}}        ;# => False   ("1" != "1.0"; in/ni never coerce)
expr {1.0 in {1.0 2.0}}      ;# => True
```

### Logical

`&&` / `||` short-circuit. `^^` (XOR), `=>` (implication `!a||b`), and `<=>`
(equivalence) are Eagle extensions.

```tcl
expr {1 && 0}                ;# => False
expr {1 || 0}                ;# => True
expr {!0}                    ;# => True
expr {1 ^^ 1}                ;# => False   (logical XOR)
expr {1 ^^ 0}                ;# => True
expr {1 => 0}                ;# => False   (logical implication: !1 || 0)
expr {0 => 1}                ;# => True
expr {1 <=> 1}              ;# => True    (logical equivalence)
expr {1 <=> 0}              ;# => False
set hit 0; expr {0 && [incr hit]}; set hit   ;# => 0   (&& short-circuits)
```

### Bitwise

```tcl
expr {12 & 10}               ;# => 8
expr {12 | 10}               ;# => 14
expr {12 ^ 10}               ;# => 6
expr {~0}                    ;# => -1
expr {12 -> 10}              ;# => -5    (bitwise implication: ~12 | 10)
expr {12 <-> 10}             ;# => -7    (bitwise equivalence: ~(12 ^ 10))
```

### Shift & rotate

`<<` / `>>` shift; `<<<` / `>>>` **rotate** (Eagle extensions). Rotation width
follows the operand's integer type — a plain int literal rotates within **32
bits**, so the low bit of `1` rotates to bit 31:

```tcl
expr {1 << 4}                ;# => 16
expr {256 >> 2}              ;# => 64
expr {1 <<< 1}               ;# => 2
expr {1 >>> 1}               ;# => -2147483648   (32-bit right-rotate of 1)
expr {16 >>> 1}              ;# => 8
```

### Conditional, assignment, precedence

`? :` is the ternary. `:=` assigns to a variable **inside** the expression — the
target name **must be quoted** (an unquoted bareword is rejected because variable
references require a leading `$`).

```tcl
expr {5 > 3 ? "a" : "b"}     ;# => a
expr {"y" := 5}              ;# => 5    (also sets $y to 5)
catch {expr {y := 5}} m; set m   ;# => syntax error...: variable references require preceding $
expr {2 + 3 * 4}             ;# => 14   (* before +)
expr {(2 + 3) * 4}           ;# => 20
expr {1 << 2 + 1}            ;# => 8    (+ binds tighter than <<: 1 << 3)
```

Precedence, highest to lowest (verified relationships shown above): parentheses
& function calls; unary `!` `~` `+` `-`; `**` (right-assoc); `*` `/` `%`;
`+` `-`; `<<` `>>` `<<<` `>>>`; `<` `>` `<=` `>=`; `==` `!=`; `eq ne lt gt le ge`;
`in` `ni`; `&`; `^`; `|`; `&&`; `||`; the implication/equivalence/XOR extensions;
then `? :` and `:=`. **When mixing the Eagle-extension operators, parenthesize**
— their relative precedence is easy to get wrong.

---

## Math functions

Functions are called as `func(arg, ...)` **inside** `[expr]`; the parentheses are
required (`expr {pi}` is a syntax error). The full set from `[info functions]`
(54 functions) is covered below; Eagle extensions over Tcl 8.4/8.5 are marked
*(Eagle)*. Note Eagle does **not** provide Tcl 8.5+'s `isqrt` (and its `bool`,
`entier`, `min`, `max` are the 8.5 features it *does* include).

**Domain / error model (by design):** an out-of-domain floating argument yields
the IEEE value `NaN` rather than Tcl's `domain error` — `sqrt(-1)`, `log(-1)`,
`acos(2)` all give `NaN`. Use `isnan(x)` / `fpclassify` to test results.

### Constants — `pi`, `e`, `epsilon`

```tcl
expr {pi()}                  ;# => 3.141592653589793
expr {e()}                   ;# => 2.718281828459045
expr {epsilon()}             ;# => 5E-324
```

> `epsilon()` returns .NET `Double.Epsilon` — the smallest positive **subnormal**
> double (`5E-324`), *not* the conventional "machine epsilon" `2.22e-16`. (See
> DOC ISSUES.)

### Trigonometric — `sin` `cos` `tan` `asin` `acos` `atan` `atan2`, hyperbolic `sinh` `cosh` `tanh`

```tcl
expr {sin(0)}                ;# => 0
expr {cos(0)}                ;# => 1
expr {tan(0)}                ;# => 0
expr {asin(1)}               ;# => 1.5707963267948966
expr {acos(1)}               ;# => 0
expr {atan(1)}               ;# => 0.7853981633974483
expr {atan2(1, 1)}           ;# => 0.7853981633974483
expr {sinh(0)}               ;# => 0
expr {cosh(0)}               ;# => 1
expr {tanh(0)}               ;# => 0
```

### Logarithmic / exponential / power — `exp` `log` `log10` `log2` `logx` `pow` `sqrt`

`log2` *(Eagle)* and `logx(x, base)` *(Eagle)* are extensions.

```tcl
expr {exp(1)}                ;# => 2.718281828459045
expr {log(exp(1))}           ;# => 1
expr {log10(1000)}           ;# => 3
expr {log2(8)}               ;# => 3        (Eagle)
expr {logx(8, 2)}            ;# => 3        (Eagle: log base 2 of 8)
expr {pow(2, 10)}            ;# => 1024     (note: 1024, not 1024.0)
expr {sqrt(2)}               ;# => 1.4142135623730951
expr {sqrt(-1)}              ;# => NaN      (out-of-domain -> NaN, not an error)
```

### Rounding — `ceil` `floor` `round` `truncate` `round2` `round3`

`truncate` *(Eagle)*, `round2(x, digits)` *(Eagle)*, and
`round3(x, digits, mode)` *(Eagle)* are extensions. `ceil`/`floor`/`round`
return a whole value typed `decimal` that prints without `.0` (Tcl prints `3.0`).

```tcl
expr {ceil(2.1)}                       ;# => 3      (Tcl: 3.0)
expr {floor(2.9)}                      ;# => 2      (Tcl: 2.0)
expr {round(2.5)}                      ;# => 3
expr {round(-2.5)}                     ;# => -3     (half rounds away from zero)
expr {truncate(-2.9)}                  ;# => -2     (Eagle; toward zero)
expr {round2(3.14159, 2)}              ;# => 3.14   (Eagle)
expr {round3(2.5, 0, "ToEven")}        ;# => 2      (Eagle; banker's rounding)
expr {round3(2.5, 0, "AwayFromZero")}  ;# => 3      (Eagle; mode is a MidpointRounding name)
```

### Component / aggregate — `abs` `fmod` `hypot` `sign` `min` `max`

`sign(x)` *(Eagle)* returns `-1` / `0` / `1`. `abs` preserves the operand's
numeric type; `min`/`max` take two or more arguments.

```tcl
expr {abs(-5)}               ;# => 5
expr {abs(-5.5)}             ;# => 5.5
expr {fmod(10, 3)}           ;# => 1
expr {hypot(3, 4)}           ;# => 5
expr {sign(-5)}              ;# => -1    (Eagle)
expr {min(3, 1, 2)}          ;# => 1
expr {max(1, 9, 3, 7)}       ;# => 9
```

### Indicators — `isnan` `isinf` `isfinite` `isnormal` `issubnormal` `isunordered`

All return `True`/`False`. Only `isnan` is standard; the rest are *(Eagle)*.
Force a true double with `double(...)` to make `∞`/`NaN` (integer `1/0` raises):

```tcl
expr {isnan(0 / double(0))}              ;# => True
expr {isnan(1.0)}                        ;# => False
expr {isinf(1 / double(0))}              ;# => True
expr {isfinite(1.0)}                     ;# => True
expr {isunordered(1.0, 0 / double(0))}   ;# => True    (true if either is NaN)
```

`isnormal(x)` / `issubnormal(x)` test the IEEE class of a double (normal vs
denormalized), analogous to `fpclassify` returning `normal` / `subnormal`.

### Conversion — `int` `wide` `double` `entier` `decimal` `bool`

```tcl
expr {int(2.9)}              ;# => 2            (truncates toward zero)
expr {int(-2.9)}            ;# => -2
expr {int(9999999999)}      ;# => 1410065407   (int() is 32-bit and WRAPS)
expr {wide(2.9)}            ;# => 2            (64-bit truncation)
expr {double(5)}            ;# => 5            (Tcl: 5.0)
expr {entier(2.9)}          ;# => 2
expr {entier(9223372036854775807) + 1}   ;# => 9223372036854775808   (entier promotes to bignum)
expr {decimal(5)}           ;# => 5            (Eagle)
expr {bool("yes")}          ;# => True         (true/on/1/non-zero => True)
expr {bool(0)}              ;# => False
```

> `int()` is **32-bit**; `wide()` is 64-bit; `entier()` is the arbitrary-precision
> escape hatch (the only one of the three that survives 64-bit overflow). This
> matches the "no auto-promotion, be explicit" model.

### Random — `rand` `srand` `random` `randstr`

`random()` *(Eagle, crypto-strong 64-bit int)* and `randstr(length ?charset?)`
*(Eagle)* are extensions. `srand(seed)` seeds the PRNG **and** returns the first
`rand()` (deterministic for a given seed):

```tcl
expr {rand()}               ;# => a double in [0, 1)            (value varies)
expr {srand(42)}            ;# => 0.6681064659115423            (deterministic for seed 42)
expr {random()}             ;# => e.g. 6120036871740759128      (64-bit signed; varies)
string length [expr {randstr(10)}]   ;# => 10                   (content varies)
```

### Type / introspection / specialized — `typeof` `nop` `datetime` `timespan` `flags` `list`

All *(Eagle)* extensions. `typeof(x)` reports the value's underlying variant type
(literals enter expressions as `string`); `nop(x)` evaluates and discards its
argument (returns empty); `datetime` / `timespan` parse those CLR types; `flags`
operates on enum/flag values and `list` builds/operates on list values.

```tcl
expr {typeof(5)}                  ;# => string   (a bare literal is a string)
set n [expr {1 + 1}]; expr {typeof($n)}   ;# => int
expr {typeof(pi())}               ;# => double
expr {typeof(abs(-5))}            ;# => int
expr {nop(42)}                    ;# =>          (empty)
expr {datetime("2020-01-02")}     ;# => 1/2/2020 12:00:00 AM
expr {timespan("1.0:0:0")}        ;# => 1.00:00:00
```

---

## `fpclassify`

`fpclassify value` — a **command** (not an `[expr]` function; it is an Eagle
extra, absent from Tcl 8.4). It returns the IEEE-754 class of a floating value as
one of `zero`, `subnormal`, `normal`, `infinite`, or `nan`. It accepts the
literal strings `NaN` / `Inf`, plain integers (classified `normal`), and the
`∞` / `NaN` results produced via `double(...)` division.

```tcl
fpclassify 1.0                       ;# => normal
fpclassify 0.0                       ;# => zero
fpclassify 5                         ;# => normal
fpclassify NaN                       ;# => nan
fpclassify Inf                       ;# => infinite
fpclassify 4.9e-324                  ;# => subnormal
fpclassify [expr {1 / double(0)}]    ;# => infinite
fpclassify [expr {0 / double(0)}]    ;# => nan
```
