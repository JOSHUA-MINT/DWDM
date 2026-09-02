# Basket Lens — Theory Behind the Project (Formulas Explained Simply)

This file is about **why** the project works the way it does — the theory behind association
rule mining, the Apriori algorithm, the statistical tests used to validate the rules, and the
business formula that turns rules into money. Every formula is explained with a small worked
example using numbers *from this actual project* wherever possible, and each section says
exactly where in the code that piece of theory gets applied (see `CODE_EXPLAINED.md` for the
full code walkthrough).

---

## 1. The Problem Type: Association Rule Mining

### What kind of question is this?
Most data mining you hear about is *prediction*: given some inputs, predict one output (will
this customer churn? what's the price of this house?). This project is **not** that. It is
**association rule mining** (also called *market basket analysis*): given a pile of "baskets"
(sets of items bought together), find **which items tend to appear together more often than
you'd expect by chance.**

There is no single "target" being predicted. Instead, the output is a *list of rules*, each one
shaped like:

> **If a basket contains {A, B}, it also tends to contain {C}.**

Written as `{A, B} ⇒ {C}`. The left side (`{A, B}`) is called the **antecedent** or **LHS**
(left-hand side); the right side (`{C}`) is the **consequent** or **RHS** (right-hand side).

### Why this framing fits a retail dataset
A retail transaction dataset is naturally a collection of "baskets" — each `InvoiceNo` groups a
set of products bought in one visit. There's no obvious "label" to predict (unlike, say,
predicting whether a loan will default), but there *is* a natural co-occurrence structure to
discover: which products are bought as a set. That's exactly what association rule mining is
built for.

---

## 2. Itemsets and the Apriori Property

### What is an "itemset"?
An **itemset** is simply any set of items, with no direction implied — e.g., `{TEACUP, SAUCER}`
is an itemset. It becomes a **frequent itemset** if it appears in at least some minimum
proportion of all baskets — that minimum proportion is called the **minimum support** threshold.

### Why not just check every possible combination?
With 3,765 distinct products in this dataset, the number of *possible* itemsets of size 2 alone
is `3,765 × 3,764 / 2 ≈ 7.1 million`, and size-3 combinations run into the billions. Checking
every single one against every basket would be far too slow.

### The Apriori property (the trick that makes it fast)
**Apriori property:** *if an itemset is frequent, every subset of it must also be frequent.*

Turned around: *if even one single item isn't frequent enough on its own, then no larger itemset
containing that item can possibly be frequent either* — because a bigger group can never appear
in *more* baskets than any one of its members appears in alone.

This lets the algorithm work **level by level**:
1. First, find all frequent *single* items (size 1).
2. Only build size-2 candidates out of *those* frequent single items (never bothering with items
   that already failed the size-1 test).
3. Only build size-3 candidates out of pairs that were *both* found frequent at size 2.
4. ...and so on, up to `maxlen` (capped at 4 in this project — `PARAMS$maxlen`).

At every level, huge numbers of impossible combinations are pruned away before they're ever
checked against the actual basket data, which is what makes Apriori practical on a
3,765-product, 18,273-basket dataset. This is implemented by the `arules` package's
`apriori()` function — the project's own code never re-implements this pruning by hand; it's
handled internally by `arules` (see `R/03_apriori.R`, the call
`arules::apriori(trans, parameter = list(support = ..., target = "frequent itemsets"))`).

---

## 3. The Three Measures: Support, Confidence, Lift

Once frequent itemsets exist, Apriori's second phase turns them into directional **rules** and
scores each one with three numbers. All three are built from basic probability.

### 3.1 Support — "how common is this pattern?"

$$
\text{support}(X) = \frac{\text{number of baskets containing } X}{\text{total number of baskets}} = P(X)
$$

For a rule `X ⇒ Y`, the support of the *rule* is the support of the combined itemset:

$$
\text{support}(X \Rightarrow Y) = P(X \cup Y) = \frac{\text{baskets containing BOTH } X \text{ and } Y}{\text{total baskets}}
$$

**Worked example:** There are 18,273 baskets total. If `{HERB MARKER MINT, HERB MARKER PARSLEY}`
together appear in 183 of them, their support is `183 / 18,273 ≈ 0.01` (1%) — which is exactly
the project's minimum support cutoff (`PARAMS$support = 0.01`). Any itemset appearing in fewer
than ~183 baskets is discarded before rules are even generated from it.

**In plain terms:** support answers *"is this pattern even worth talking about, or is it so
rare it doesn't matter?"* Low support = rare pattern, possibly just noise or a one-off
coincidence, even if it looks striking when you spot it.

### 3.2 Confidence — "how reliable is this rule?"

$$
\text{confidence}(X \Rightarrow Y) = P(Y \mid X) = \frac{\text{support}(X \cup Y)}{\text{support}(X)}
$$

This is just **conditional probability**: *of the baskets that already contain X, what fraction
of them also contain Y?*

**Worked example:** If `{HERB MARKER MINT, HERB MARKER PARSLEY}` appears in 200 baskets, and
`{HERB MARKER MINT, HERB MARKER PARSLEY, HERB MARKER CHIVES}` (all three together) appears in
172 of those same baskets, then:

$$
\text{confidence} = \frac{172}{200} = 0.86 = 86\%
$$

**In plain terms:** confidence answers *"if I know a customer has X, how sure can I be they'll
also get Y?"* This is the number a business person intuitively wants — "how often does this
actually work?"

**The trap with confidence alone:** confidence only looks at baskets that *already* have X. It
says nothing about how common Y is *in general*. A rule pointing at a hugely popular product
(like the dataset's top-seller, which is in about 12% of *all* baskets regardless of what else
is in them) will automatically get a decent confidence score for almost any X, purely because Y
shows up everywhere anyway — not because X and Y have any real relationship. This is exactly why
a third measure is needed.

### 3.3 Lift — "is this better than coincidence?"

$$
\text{lift}(X \Rightarrow Y) = \frac{\text{confidence}(X \Rightarrow Y)}{\text{support}(Y)} = \frac{P(X \cup Y)}{P(X) \cdot P(Y)}
$$

This compares the *actual* joint probability of X and Y occurring together against the
probability you'd expect **if X and Y were completely unrelated** (statistically independent).
If X and Y were independent, `P(X ∪ Y)` would simply equal `P(X) × P(Y)` — lift is the ratio of
"what we actually saw" to "what independence would predict."

**How to read the number:**
| Lift value | Meaning |
|---|---|
| `lift = 1` | X and Y are statistically independent — knowing X tells you nothing about Y |
| `lift < 1` | *Negative* association — having X makes Y *less* likely than baseline (they're substitutes, or mutually exclusive) |
| `lift > 1` | *Positive* association — having X makes Y *more* likely than baseline |
| `lift = 75` (the project's max) | Having X makes Y about **75 times** more likely than it would be by random chance |

**Worked example, continued:** suppose `HERB MARKER CHIVES` (Y) on its own appears in only
`0.0114` (1.14%) of all baskets — most customers never buy it at all. But among baskets that
already contain mint+parsley herb markers (X), 86% contain chives too. Lift is then:

$$
\text{lift} = \frac{0.86}{0.0114} \approx 75.4
$$

This matches the project's actual highest-lift rule. **The intuition:** chives is a rare product
overall, so seeing it show up 86% of the time in a specific context is a massive, meaningful
signal — customers buying two herb markers are almost certainly completing the full 6-marker
set, not stumbling on chives by chance.

### 3.4 Why lift is the project's primary ranking measure
The project deliberately ranks and highlights rules **by lift, not by confidence**, precisely
because confidence rewards popularity while lift rewards genuine, surprising co-dependence.
`README.md` states this directly: *"any rule pointing at `WHITE HANGING HEART T-LIGHT HOLDER`
scores well simply because that product sits in over 12% of all baskets"* — a high-confidence,
low-lift rule like that is a false signal; a lower-confidence, high-lift rule (like the herb
markers) is a real one.

---

## 4. Statistical Significance: Is the Rule Real, or Just Noise?

Passing the lift/confidence/support thresholds is a *descriptive* filter — it tells you a
pattern is strong in the data you happened to collect, but not whether that pattern would hold
up if you re-sampled the population. With thousands of itemsets being tested simultaneously,
**some rules will look strong purely by chance**, the same way flipping enough coins will
eventually produce a run of 10 heads in a row even from a fair coin. Two extra statistical
steps guard against this.

### 4.1 Fisher's Exact Test
For each rule `X ⇒ Y`, imagine sorting every one of the 18,273 baskets into a 2×2 table:

| | Contains Y | Doesn't contain Y |
|---|---|---|
| **Contains X** | a | b |
| **Doesn't contain X** | c | d |

**Fisher's Exact Test** asks: *given the total number of baskets with X, without X, with Y, and
without Y (the row/column totals, which are fixed), how likely is it to see this exact
arrangement — X and Y overlapping in `a` baskets — purely by chance, if X and Y were truly
unrelated?* It computes this probability directly from the hypergeometric distribution (exact
combinatorics), rather than relying on an approximation — this makes it reliable even when some
cells in the table are small, which is common here because most individual products are rare
(low support).

A small p-value (e.g. `0.001`) means "if X and Y were really unrelated, seeing this much overlap
would be very unlikely" — so the rule is probably a real pattern, not a fluke. A large p-value
means the overlap could easily be coincidence.

In code, this p-value is computed automatically for every rule at once via
`arules::interestMeasure(rules, measure = "fishersExactTest", transactions = trans)`
(`R/03_apriori.R:104-105`).

### 4.2 The multiple-testing problem, and Benjamini-Hochberg (BH) correction
Here's the catch: this project tests **thousands of rules simultaneously** (the raw pre-filter
rule count is over 25,000). Even if every single one of those rules were pure noise, testing at
the standard "p < 0.05" cutoff would still be expected to produce hundreds of false positives
just by chance (5% of 25,000 is 1,250!). Testing many hypotheses at once inflates the overall
chance of *some* false discoveries — this is the "multiple testing problem."

**Benjamini-Hochberg (BH) correction** fixes this by controlling the **false discovery rate**
(the expected proportion of "significant" results that are actually false positives) rather than
the per-test error rate. In plain terms, it does the following:
1. Sort all p-values from smallest to largest.
2. For the `k`-th smallest p-value (out of `m` total tests), compare it against a stricter
   threshold that scales with its rank: roughly `k/m × 0.05` instead of a flat `0.05`.
3. The smallest p-values (strongest evidence) get to keep something close to the original
   threshold; p-values further down the ranked list need to be increasingly smaller to survive,
   since there are more chances for noise to produce a false positive that far into the list.
4. Everything failing this adjusted threshold is discarded.

This is exactly what `p.adjust(quality(rules)$fishersPValue, method = "BH")` does
(`R/03_apriori.R:106`) — it recalculates every p-value into an "adjusted" version, and the
project keeps only rules with `pAdjusted < 0.05` (`R/03_apriori.R:107`). This is the step that
takes the rule count from thousands down to the final **2,215** — every one of those 2,215 rules
has survived a correction specifically designed to guard against exactly the kind of
mass-testing false-positive problem this analysis is prone to.

### 4.3 Redundancy removal
Separately from statistical significance, there's a *logical* form of waste: two rules can say
almost the same thing.

> `{A, B} ⇒ {C}` with confidence 85%
> `{A} ⇒ {C}` with confidence 87%

Here, the simpler rule `{A} ⇒ {C}` is *at least as good* as the more complicated one — adding
`B` to the antecedent didn't improve confidence at all, so `{A,B} ⇒ {C}` provides no extra
predictive value over its simpler subset-rule. `arules::is.redundant()` detects exactly this
case (a more general rule with equal-or-better confidence already exists) and flags it, and the
project drops every flagged rule (`R/03_apriori.R:98`, and again inside `mine()` in
`R/05_segments_and_recommendations.R:24`). This is not a statistical test — it's a logical
simplification step, applied *before* the Fisher/BH significance test, to avoid wasting
significance-testing effort on rules that are redundant anyway.

### 4.4 The full filtering funnel
Putting §3 and §4 together, here is the complete order of operations
(`R/03_apriori.R:80-111`):

```
~25,000+ raw rules from apriori(support=0.01, confidence=0.30, minlen=2, maxlen=4)
   → filter lift > 1.0                        ~5,000+ rules remain
   → remove redundant rules (is.redundant)     ~3,500+ rules remain
   → Fisher's exact test + BH correction       2,215 rules remain (final)
```

Each stage answers a different question: lift asks *"is this better than chance?"*, redundancy
asks *"does this rule tell us anything a simpler rule didn't already?"*, and Fisher's+BH asks
*"is this pattern statistically trustworthy given how many rules we tested at once?"*

---

## 5. Threshold Sensitivity — Why Support Is the Parameter That Matters

The project doesn't just pick `support=0.01, confidence=0.30` and trust it blindly — it tests a
5×5 grid of `support ∈ {0.005, 0.0075, 0.01, 0.015, 0.02}` × `confidence ∈ {0.2, 0.3, 0.4, 0.5, 0.6}`
(25 combinations total), re-running Apriori fully at each one and recording the resulting rule
count (`R/03_apriori.R:142-152`).

**Why this matters theoretically:** support is a *combinatorial* filter — it controls how many
itemsets are even allowed to exist before rules are generated from them, and the number of
possible itemsets grows explosively as the threshold drops (more products qualify → more
combinations of those products qualify → still more combinations of *those* combinations
qualify...). Confidence, by contrast, is applied *after* itemsets are already fixed — it only
decides which already-fixed candidate rules get kept or discarded; it can't create new
candidates that support already ruled out. This is why the project's own analysis finds "rule
count drops geometrically as support rises, while confidence merely trims the already-determined
pool" — support decides the *size of the playing field*, confidence just decides who's allowed
to stay on it.

---

## 6. Turning Rules Into Money: The Cross-Sell Opportunity Formula

This is the project's own applied-business extension — not a standard "textbook" formula from
association-rule-mining theory, but a defensible way to translate a rule's statistics into a
concrete revenue estimate.

### The reasoning, step by step

**Step 1 — how many baskets are "missing" the opportunity?**
A rule `X ⇒ Y` with high confidence is only commercially useful on baskets that *have* X but
*don't yet have* Y — those are the exact customers who, statistically, "should" have bought Y
too. The count of baskets containing X is `support(X)` (also called the rule's **coverage**).
Baskets containing *both* X and Y is `support(X ∪ Y)`. So baskets with X **but not Y** is simply:

$$
\text{MissedBaskets} = \big(\text{coverage}(X) - \text{support}(X \cup Y)\big) \times N
$$

where `N` is the total basket count. This is pure arithmetic on numbers Apriori already
computed — no new scan of the raw data is needed, which is why the code comment in
`R/05_segments_and_recommendations.R:160-161` notes *"No basket scan needed."*

**Step 2 — how many of those missed baskets would we realistically expect to convert?**
Not every missed-opportunity basket would actually buy Y if prompted. The project makes a
simplifying assumption: use the rule's own confidence as the conversion rate estimate — i.e., if
86% of baskets *with* X historically also contained Y, assume that if you *actively prompted*
the missing 14%, roughly that same 86% conversion rate would apply:

$$
\text{ExpectedUplift} = \text{MissedBaskets} \times \text{Confidence}(X \Rightarrow Y)
$$

**Step 3 — price the uplift.**
Multiply the expected number of newly-converted baskets by how much revenue each one is worth,
using product Y's own historical average selling behaviour:

$$
\text{PotentialRevenue} = \text{ExpectedUplift} \times \text{AvgPrice}(Y) \times \text{AvgQty}(Y)
$$

`AvgPrice(Y)` and `AvgQty(Y)` are Y's mean `UnitPrice` and mean `Quantity` per line, computed
once across the whole cleaned dataset (`R/05_segments_and_recommendations.R:151-154`).

**Worked example (using the project's actual top opportunity):**
`ROSES REGENCY TEACUP AND SAUCER ⇒ REGENCY CAKESTAND 3 TIER` has lift only 4.6× (much lower than
the herb-marker rules' 75×) but a *high support* — it fires on hundreds of baskets — against an
*expensive* product. Even with modest confidence, `MissedBaskets × Confidence × AvgPrice ×
AvgQty` compounds into roughly **GBP 24,625** — larger than almost any high-lift, low-support,
cheap-item rule could produce. This is the theoretical reason the project's own conclusion states
*"the largest cross-sell gaps are not the highest-lift rules"* — **lift measures the strength of
a pattern; support and price decide whether that pattern is big enough, and valuable enough, to
be worth acting on.** A rule can be a very strong, very "real" pattern (high lift, passing every
significance test) while still being commercially tiny if it only fires on a handful of cheap
baskets.

### Why deduplication is necessary
Because rules overlap heavily — many different antecedents can all point at the same
consequent, and many rules fire on overlapping sets of baskets — **naively summing
`PotentialRevenue` across every rule double- and triple-counts the same missed basket** every
time a different rule also happens to predict the same product for it. The project's fix:
group all rules by their consequent product and keep only the single highest-revenue rule per
product (`slice_max(PotentialRevenue, n=1)` in `R/05_segments_and_recommendations.R:188-192`).
Summing *that* deduplicated set gives a number that treats each product's opportunity exactly
once — this is the **defensible** GBP 1.02M figure reported, as opposed to a much larger, inflated
"naive sum over all rules" number the code also computes and explicitly labels as an
upper-bound-only, double-counted figure (see the `message()` calls at
`R/05_segments_and_recommendations.R:195-204`).

---

## 7. Segment and Season Re-Mining: Why the Same Formulas Get Applied Twice More

Support, confidence, lift, and the redundancy/lift filters (theory §2-3) are not just run once
on the whole dataset — the exact same Apriori mining process (minus the Fisher/BH significance
test, for speed) is re-run independently on:
- **UK-only baskets** vs **International-only baskets**
- **Sep–Nov (pre-Christmas) baskets** vs **the rest of the year**

**Theoretical justification:** support, confidence, and lift are all defined *relative to the
transaction population you compute them over*. A pattern that's frequent among UK shoppers might
be rare (and thus filtered out) if computed over the mixed UK+International population, and vice
versa — mixing populations with different underlying buying behaviour can wash out or distort
real segment-specific patterns. Re-mining each segment on its own transaction set lets each
subgroup's own patterns surface on their own terms, at thresholds appropriate to that subgroup's
size (this is exactly why International uses a relaxed 2% support threshold instead of 1% — with
far fewer baskets, the same absolute count of co-occurring baskets is a *higher* percentage, so
holding support at 1% would have thrown away real patterns simply because International has less
data overall).

---

## 8. Why Apriori (and Not Something Else)

The project's own reasoning, restated with the theory behind each point:

- **The problem is co-occurrence, not prediction.** There's no single dependent variable to
  predict (unlike regression/classification); the goal is discovering which *sets* of items
  relate to each other, which is exactly what association rule mining formalizes and Apriori
  computes efficiently.
- **Interpretability.** Each output is a plain "if-then" statement with three human-readable
  numbers attached — no black-box weights or embeddings to explain to a business stakeholder.
- **Efficiency at this scale.** The Apriori property's pruning (§2) keeps the search tractable
  at 18,273 baskets × 3,765 products with a 1% support floor — a brute-force check of every
  possible itemset would not be.
- **Three complementary metrics in one framework.** Support (frequency), confidence
  (reliability), and lift (strength-of-relationship-vs-chance) together describe a rule from
  three angles that no single number could capture alone — a rule can be common but unreliable,
  reliable but trivial (because the consequent is trivially common anyway), or rare but
  extremely strong; the three-measure combination is what lets the project distinguish those
  cases (as in the "confidence trap" discussed in §3.2).
