---
name: eda-econometrics-numpy
description: Run exploratory data analysis and classical-regression assumption testing grounded in Kennedy's "A Guide to Econometrics" (6th ed.), then run the feature-selection stage that gates both unsupervised (PCA, clustering) and supervised (regression, classification) modeling. Build models with numpy primitives; avoid scipy and scikit-learn wherever possible. Use whenever starting a data-science pipeline, fitting a regression, doing feature selection, running PCA, scoring feature importance, validating a model's assumptions, or writing any code that touches training data. Triggers: "EDA", "explore the data", "feature selection", "fit a model", "PCA", "check assumptions", "VIF", "homoskedasticity", "Durbin-Watson", "Jarque-Bera", "Breusch-Pagan", numpy-only modeling, "avoid sklearn".
---

# EDA, Econometric Assumption Testing, and numpy-Only Modeling

The pipeline has four stages that run in order, every time, with hard handoffs between them: **EDA → PCA → Eigen-decomposition retention → Supervised model**. Each stage consumes the previous stage's artifact and produces one of its own. A stage cannot begin until the previous stage's artifact is on disk.

The textbook spine is Kennedy, *A Guide to Econometrics* (6th ed.). The six classical linear-regression assumptions (linearity, independence of errors, homoskedasticity, no multicollinearity, normality of errors, exogeneity) are the gate: if any of them is materially violated and the pipeline cannot fix it, the fitted model is reported with that caveat, not hidden.

The implementation rule is: **build it with numpy primitives**. scipy and scikit-learn are last resorts and their use is justified in code comments. The reasons are reproducibility, transparency, and keeping hot paths dependency-free.

## The pipeline, end to end

1. **Intake.** Load raw data once. Record the data version (hash + source path). Never load the same file twice in the same run.
2. **EDA.** Eliminate features that do not earn their place: near-zero variance, near-duplicates, by missingness, outliers, heavy tails, multicollinearity. Each item in the EDA checklist resolves to a drop / keep / transform decision, and the resolved decisions are written to the session file. Output: an EDA-filtered feature matrix at a versioned path, plus an audit log of every column dropped, kept, or transformed and why.
3. **Assumption testing.** Run the six tests below on the EDA-filtered matrix and record pass/fail with a one-line interpretation. Failures inform whether the supervised stage can use OLS standard errors or needs robust ones.
4. **PCA.** Operate **only** on the EDA-filtered matrix. Standardize, then SVD. Output: a fitted PCA artifact (`mean`, `components`, `explained_variance_ratio`, `singular_values`, `feature_version`, `data_version`).
5. **Eigen-decomposition retention.** Pick `k` components from the explained-variance curve; rank original features by absolute loading on each retained PC; record which original features survive to the supervised stage and why. Output: a retention manifest — the set of original features (or PC scores, per project choice) that go into the model, plus the audit.
6. **Supervised model.** Fit on training folds only, evaluate on a held-out fold that has not seen any transform fit. Input is the retention manifest's matrix, never the raw data.
7. **Validate.** Repeat the six tests on the fitted residuals. Report findings; do not silently retrain until tests pass.

The four stages are sequential, not parallel. PCA cannot fix what EDA should have caught. Eigen-decomposition retention cannot fix what PCA mis-sized. The supervised model cannot fix any of the above.

## EDA — Kennedy-style elimination checklist

EDA is not a chart dump. It is the elimination stage: every column either earns its place in the matrix that PCA will see, or it is dropped, transformed, or marked for special handling. Each item below resolves to a binary decision (drop / keep / transform) and a one-line reason. The full set of decisions is the audit log — write it to the session file with a one-line consequence for each downstream stage.

The stage runs once on intake, before assumption tests and before PCA. Nothing reaches PCA that EDA did not clear.

- **Provenance.** Drop / keep / transform decision: *drop* the column if its source is stale, broken, or has no version hash; *keep* only when the data version is recorded (hash + source path). Record the decision with the version metadata; the rest of the pipeline cannot run on unversioned data.
- **Missingness.** For each column: `n_missing`, `pct_missing`, and whether missingness is random or patterned (compare distributions of other columns across missing vs. present). Decision: *drop* if `pct_missing > 40%` and the column is not a primary key or target; *transform* by adding an `is_missing` indicator and median-imputing when `pct_missing < 5%` and missingness is plausibly random; *keep with flag* and revisit when between 5% and 40%. Never impute the mean on heavy-tailed columns.
- **Distributions.** For numeric columns: mean, median, std, min, max, skew, kurtosis. Decision: *transform* (`log1p` or signed-log) when `|skew| > 2` or `kurtosis > 10`; *keep* otherwise. Document the transform so the serving path applies the same one.
- **Outliers.** IQR rule (`> Q3 + 1.5·IQR` or `< Q1 − 1.5·IQR`) and the z-score rule (`|z| > 3`). Decision: *transform* via winsorization at the 1st/99th percentile by default (5/95 only when the project requires it); *drop* the row only with explicit user approval and a recorded reason. Deleting rows is a last resort.
- **Class balance.** For classification targets: per-class count and minority ratio. Decision: *keep* with the original target and choose a metric matched to imbalance (precision/recall/F1/AUC) when minority `≥ 10%`; *transform* via a documented resampling or class-weight scheme when minority `< 10%`. Severe imbalance changes the metric, not the features.
- **Correlations.** Pearson for linear, Spearman for monotone-nonlinear. Decision: for any pair with `|ρ| > 0.98`, *drop* the column with the lower correlation to `y` (supervised) or the higher mean absolute correlation to the rest (unsupervised), keeping one; for `|ρ| > 0.8`, *flag* as multicollinearity candidates and feed the VIF stage.
- **Near-zero variance.** `std / |mean|` (coefficient of variation) below a project threshold (commonly `< 0.01`) or `std` below a numerical floor. Decision: *drop*. A constant column contributes nothing and destabilizes PCA.
- **Multicollinearity (VIF).** Computed once after the above decisions. Decision: *drop* the column with the highest VIF, recompute, repeat until every VIF `< 10` (or `< 5` in stricter projects), or until further dropping costs more than it saves. Record the drop order.
- **Stationarity (time series).** Rolling mean and rolling std; an Augmented Dickey-Fuller-style check is fine to do with numpy on lags if the project requires it. Decision: *transform* via differencing when non-stationary; *keep* when stationary. Non-stationary features break PCA's assumption of a stable covariance structure.

The output of EDA is two artifacts: (a) the EDA-filtered feature matrix at a versioned path (`eda_filter/<data_version>/features.parquet` or equivalent), and (b) the audit log — one line per column with the decision and reason — written to the session file. PCA consumes only (a); the audit log is consulted whenever a downstream stage is questioned.

## The six classical assumptions

For a linear model `y = X β + ε`, the Gauss-Markov assumptions Kennedy centers the discussion around are:

These tests run **after EDA elimination and before PCA**, on the EDA-filtered matrix. Failures here inform whether the supervised stage can use OLS standard errors or needs robust ones (HC0/HC1) — they do not push the pipeline back to redo EDA. If a failure cannot be fixed without reintroducing features EDA eliminated, the model is reported with the caveat, not silently retrained.

1. **Linearity in parameters.** The conditional expectation of `y` given `X` is linear in `β`. Tested by residual-vs-fitted scatter and the Ramsey RESET test.
2. **Independence of errors.** `Cov(ε_i, ε_j) = 0` for `i ≠ j`. Tested by Durbin-Watson on residuals; for panel/time-series, also by autocorrelation of residuals at multiple lags.
3. **Homoskedasticity.** `Var(ε_i | X_i) = σ²` constant. Tested by Breusch-Pagan and White.
4. **No perfect multicollinearity.** `X` has full column rank; in practice no `|ρ|` near 1 and no VIF above the threshold (commonly 10). Tested by the correlation matrix and VIF.
5. **Normality of errors.** `ε ~ N(0, σ²)`. Tested by Jarque-Bera (uses skewness and kurtosis) and a quantile-quantile plot of residuals.
6. **Exogeneity.** `E[ε | X] = 0`. Tested indirectly: mean of residuals ~ 0, residual-vs-regressor scatter shows no pattern, and where an instrumental variable is available, a Hausman-style check.

These are the tests the pipeline runs, in numpy. Each is small enough to read in one screen.

### Building blocks (numpy primitives)

Keep these as helpers in a single `assumptions.py` (or equivalent) so every test reuses the same fit:

```python
import numpy as np

def add_intercept(X):
    X = np.asarray(X, dtype=np.float64)
    return np.hstack([np.ones((X.shape[0], 1)), X])

def ols_fit(X, y):
    X = add_intercept(X)
    y = np.asarray(y, dtype=np.float64)
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    fitted = X @ beta
    resid = y - fitted
    return beta, fitted, resid

def r2(y, fitted):
    y = np.asarray(y, dtype=np.float64)
    ss_res = ((y - fitted) ** 2).sum()
    ss_tot = ((y - y.mean()) ** 2).sum()
    return 1.0 - ss_res / ss_tot if ss_tot > 0 else 0.0
```

### 1. Linearity — Ramsey RESET

Fit the model, then refit with `fitted`, `fitted**2`, `fitted**3` added as extra regressors. If the extras are jointly significant, the linear specification is wrong. Without `scipy.stats`, the joint F is hand-rolled:

```python
def ramsey_reset(X, y, n_terms=3):
    _, fitted, resid_base = ols_fit(X, y)
    extra = np.column_stack([fitted ** k for k in range(2, n_terms + 1)])
    X_aug = np.hstack([add_intercept(X), extra])
    beta_aug, fitted_aug, resid_aug = ols_fit(X_aug, y)
    rss_base = (resid_base ** 2).sum()
    rss_aug = (resid_aug ** 2).sum()
    n, k_aug = X_aug.shape
    df_num = n_terms
    df_den = n - k_aug
    f_stat = ((rss_base - rss_aug) / df_num) / (rss_aug / df_den)
    return {"F": f_stat, "df_num": df_num, "df_den": df_den}
```

Compare the F to `F_{df_num, df_den, 0.95}` from an F-table stored as a constant; a high F is a linearity failure. The residual-vs-fitted scatter is the qualitative companion.

### 2. Independence of errors — Durbin-Watson

DW ≈ 2 means no first-order autocorrelation; values near 0 indicate positive autocorrelation, near 4 negative. Use the residual series in time order — if the data are not time-ordered, skip and note it.

```python
def durbin_watson(resid):
    e = np.asarray(resid, dtype=np.float64)
    num = np.sum(np.diff(e) ** 2)
    den = np.sum(e ** 2)
    return float(num / den) if den > 0 else float("nan")
```

DW ~ 2 is the gate; values far from 2 call for lagged terms or a time-aware model. The exact decision rule depends on `n`, `k`, and the d_L/d_U tables — keep a small lookup for the project's typical sample size rather than reaching for scipy.

### 3. Homoskedasticity — Breusch-Pagan and White

**Breusch-Pagan.** Regress the squared residuals on the original regressors. The LM statistic is `n · R²` of that auxiliary regression. Under `H0` (homoskedastic), `n·R² ~ χ²_k` with `k` regressors. Compare to a `χ²_k` critical value stored as a constant.

```python
def breusch_pagan(X, resid):
    X = add_intercept(X)
    e2 = np.asarray(resid, dtype=np.float64) ** 2
    beta, fitted, _ = ols_fit(X, e2)
    n = X.shape[0]
    lm = n * r2(e2, fitted)
    return {"LM": lm, "df": X.shape[1] - 1}
```

**White.** Same idea, but the auxiliary regressors are the originals, their squares, and their cross-products. It catches heteroskedasticity of forms Breusch-Pagan misses (e.g. quadratic in `X`). Same `n·R²` statistic, larger df.

Failures mean: use heteroskedasticity-robust standard errors (HC0/HC1 from numpy is just `sqrt(diag((X'X)^{-1} X' diag(e²) X (X'X)^{-1}))`), or move to a model that allows heteroskedasticity (weighted least squares, or a different link).

### 4. No multicollinearity — VIF from the correlation matrix

For each regressor `x_j`, regress it on the others; VIF = `1 / (1 − R²_j)`. Computed without sklearn:

```python
def vif_table(X):
    X = np.asarray(X, dtype=np.float64)
    Xc = X - X.mean(axis=0)
    corr = np.corrcoef(Xc, rowvar=False)
    inv = np.linalg.pinv(corr)
    return np.diag(inv)  # VIF for each column
```

A common rule of thumb: VIF > 10 (or > 5 in stricter projects) means drop, combine, or regularize. The correlation matrix itself flags which columns are the problem.

### 5. Normality of errors — Jarque-Bera

JB = `(n/6) · (S² + (K − 3)² / 24)` where `S` is skewness and `K` is kurtosis. Under normality, `JB ~ χ²_2`.

```python
def jarque_bera(resid):
    e = np.asarray(resid, dtype=np.float64)
    n = e.size
    s = ((e - e.mean()) ** 3).mean() / e.std(ddof=0) ** 3
    k = ((e - e.mean()) ** 4).mean() / e.std(ddof=0) ** 4
    jb = (n / 6.0) * (s ** 2 + ((k - 3.0) ** 2) / 24.0)
    return {"JB": jb, "df": 2, "skew": s, "kurtosis": k}
```

Pair the JB number with a Q-Q plot of standardized residuals. JB is sensitive in large `n`; small deviations from normality can reject even when the model is fine for inference on the mean. Use judgement, do not mechanically refit.

### 6. Exogeneity

There is no single test. The practical checks:

- Mean of residuals ≈ 0 (always true by OLS construction; report it anyway as a sanity line).
- Residual-vs-each-regressor scatter shows no pattern. A pattern is a signal of an omitted variable.
- Where instruments are available, run a 2SLS: project `X` onto instruments `Z`, then regress `y` on the projection. Compare the IV coefficient to the OLS coefficient (Hausman). With numpy:

  ```python
  def tsls(X, y, Z):
      X, y, Z = map(lambda a: np.asarray(a, dtype=np.float64), (X, y, Z))
      Z1 = add_intercept(Z)
      X_hat = Z1 @ np.linalg.lstsq(Z1, X, rcond=None)[0]
      beta, fitted, resid = ols_fit(X_hat, y)
      return beta, fitted, resid
  ```

A material gap between OLS and IV coefficients is an endogeneity signal. Record it and decide with the user before changing the model.

## Pre-PCA encoding and standardization

The EDA stage eliminates columns and decides transforms (log1p, winsorize, etc.) on a per-column basis. What remains still needs two mechanical operations before PCA sees the matrix: categorical encoding, and per-feature standardization. These are not elimination decisions — they are format conversions on the EDA-filtered matrix. Both fit on the training fold only and are persisted as versioned artifacts.

1. **Encode categoricals.** One-hot for low cardinality (rule of thumb: ≤ 16 levels), target/mean encoding for high cardinality with leakage control (fit on the training fold, apply to val/test/prod). Record the encoding map.
2. **Standardize.** Fit `(μ, σ)` per column on the training fold. Apply the same `(x − μ) / σ` to val/test/prod. PCA on raw, unscaled features lets the largest-magnitude feature dominate the eigen-decomposition — standardization is mandatory here. For tree-based models it is unnecessary, but if the same matrix feeds both PCA and a tree baseline, standardize once and reuse.

Every transform records (a) what it does, (b) the parameters fit on the training fold, and (c) the artifact path. The serving path loads the artifact and applies the same transform; train/serve skew is a bug, and only a versioned transform file prevents it.

## PCA from numpy (preferred)

Principal component analysis is the variance-based feature-selection stage. It operates **only on the EDA-filtered, encoded, and standardized matrix** — never on raw input. PCA consumes the artifact from the EDA stage, applies SVD to surface the directions of greatest variance, and produces components that the next stage (eigen-decomposition retention) will choose between. Use numpy SVD — numerically stable, sklearn-free, fast on float32:

```python
import numpy as np

def fit_pca(X, n_components=None, target_variance=0.95):
    X = np.asarray(X, dtype=np.float32)
    Xc = X - X.mean(axis=0)
    u, s, vt = np.linalg.svd(Xc, full_matrices=False)
    evr = (s ** 2) / (s ** 2).sum()
    if n_components is None:
        cum = np.cumsum(evr)
        k = int(np.argmax(cum >= target_variance)) + 1
    else:
        k = n_components
    return {
        "mean": X.mean(axis=0),
        "components": vt[:k],
        "explained_variance_ratio": evr[:k],
        "singular_values": s[:k],
    }

def apply_pca(fit, X):
    X = np.asarray(X, dtype=np.float32)
    return (X - fit["mean"]) @ fit["components"].T

def reconstruct_pca(fit, Z):
    return Z @ fit["components"] + fit["mean"]
```

Rules:

- **Fit on training data only.** PCA fit on the full dataset is leakage.
- **Standardize first** when feature scales differ. PCA on raw, unscaled features lets the largest-magnitude feature dominate.
- **Pick `k` from the explained-variance curve**, not from a magic number. The default `target_variance=0.95` is a starting point; report the curve and pick with the user.
- **Persist as an artifact.** `mean`, `components`, `explained_variance_ratio`, plus a `feature_version` and `data_version`. Load at service startup; never refit per request.
- **Pair with reconstruction error.** Reconstruction MSE on a held-out fold is a feature-health signal worth tracking in monitoring.
- **`sklearn.decomposition.PCA`** is acceptable for offline exploration only. Production code uses the numpy version.

## Eigen-decomposition retention

PCA produces a full set of components, ordered by explained variance. This stage decides which components survive to the supervised model and which original features those components actually represent. It is the bridge between PCA's unsupervised output and a model that has to be auditable.

### Picking `k`

Two acceptable heuristics, in order of preference:

1. **Knee / elbow on the explained-variance curve.** Plot `cumsum(evr)` against component index. The `k` is the index just before the curve flattens. Report the curve; do not pick blind.
2. **Target cumulative variance.** Default `0.95`. A starting point, not a rule — confirm with the user. For high-noise or wide matrices, `0.99` is often justified; for low-dimensional problems, `0.90` may already over-include noise.

A `k` chosen to satisfy a metric on the val set (e.g. "PCA-7 gave the best AUC") is p-hacking. Pick `k` from the curve, then evaluate the model.

### Identifying top contributors per retained PC

The loadings matrix is the `k × p` slice `components` returned by `fit_pca`. Each row is one PC; each column is one original (EDA-filtered, encoded, standardized) feature. For each retained PC, rank the original features by absolute loading. The top contributors are the original features that most strongly express that direction of variance.

```python
def top_contributors(pca_fit, k_idx, top_n=5):
    loadings = pca_fit["components"][k_idx]
    idx = np.argsort(np.abs(loadings))[::-1][:top_n]
    return [(int(i), float(loadings[i])) for i in idx]
```

Run this for every retained PC. The union of the top contributors across PCs is the set of original features that "carry" the retained variance. This is the audit artifact — it tells a reviewer which features the model is implicitly relying on, even when the model itself sees only PC scores.

### The two legitimate outputs

Pick one per project and record the choice in the retention manifest:

- **Option A: feed PC scores to the model.** Use `apply_pca(pca_fit, X_eda)[:, :k]` as the model input. The supervised stage never sees the original features. Faster, less leakage risk, less interpretable. Right when the goal is prediction accuracy on held-out data.
- **Option B: feed back-projected top-loading features.** For each retained PC, take the top-N original features by absolute loading; union across PCs; reconstruct a smaller feature matrix from those original columns (still from the EDA-filtered matrix, not raw input). The supervised stage sees a small, named, auditable feature set. Slower, more interpretable, slightly more leakage risk. Right when the goal is inference or the user wants to read off which features matter.

In either option, the retention manifest records: `k` chosen, the rationale (knee or target variance), the top contributors per retained PC with absolute loadings, and which option (A or B) was selected for the supervised stage.

### Persistence

Save the manifest alongside the PCA artifact at `pca/<data_version>/retention_manifest.json` (or equivalent). It is versioned with the PCA fit. The serving path loads both, in order, before the model sees a request.

## Models from numpy

The supervised stage consumes **only** what the eigen-decomposition retention stage produced — never raw input, never the EDA-filtered matrix in full unless the retention manifest says so. Per the manifest's option (A or B) the model sees either the first `k` PC scores or the smaller back-projected feature matrix. The model has no business knowing anything else.

Linear, ridge, logistic, and k-means are small enough to write in numpy. The discipline: write the model once, with a `fit` returning an artifact and a `predict` that takes the same shape it was fit on. A model fit on PC scores gets PC scores at predict time; a model fit on back-projected features gets back-projected features. Mixing the two shapes is a bug.

**Linear / Ridge (closed form):**

```python
def fit_ridge(X, y, alpha=1.0):
    X1 = add_intercept(X); y = np.asarray(y, dtype=np.float64)
    n, p = X1.shape
    I = np.eye(p); I[0, 0] = 0.0  # do not regularize the intercept
    beta = np.linalg.solve(X1.T @ X1 + alpha * I, X1.T @ y)
    return {"beta": beta, "intercept_in_regularization": False}

def predict(model, X):
    return add_intercept(X) @ model["beta"]
```

Elastic-net is `ridge` + soft-threshold; logistic is gradient descent on the log-loss with numpy; k-means is Lloyd's algorithm in a `while` loop. Keep the implementations in a single `models.py` and write a unit test per model on a tiny synthetic dataset (n=200) where the answer is known.

**When to use a real library:** When the model is not in the small numpy set (gradient boosting, neural networks, anything with hundreds of hyperparameters), reach for a project-approved library. The skill does not forbid libraries; it forbids defaulting to them when numpy will do.

**Seeds.** Every stochastic step gets a seed (`np.random.default_rng(seed)`). Reproducibility is part of the deliverable.

## The eval contract

- **Split.** Train/val/test split with no leakage of any transform's fit. A common shape: 70/15/15, time-ordered when the data is temporal.
- **Metric.** Matched to the business goal. For imbalanced classification: precision/recall/F1/AUC, not accuracy. For skewed regression targets: RMSLE or MAE rather than RMSE.
- **Baseline first.** Fit a one-feature or constant baseline before any real model. Beats a beautiful model that loses to mean-by-segment.
- **Reporting.** Every model run writes to the session file: data version, feature version, model version, hyperparameters, metric on val, metric on test, and which assumption tests failed with what interpretation.

## When scipy / scikit-learn are acceptable

The default is no. Acceptable uses:

- **scipy.stats** for distributions whose closed form is genuinely needed (e.g. `scipy.stats.chi2.ppf` for critical values). Prefer precomputed constants for the project's typical degrees of freedom; fall back to scipy only when out of table.
- **scikit-learn** for things that have no honest numpy equivalent (e.g. DBSCAN with a spatial index, t-SNE/UMAP for visualization, gradient boosting). For these, isolate the sklearn call behind a function so the rest of the pipeline stays numpy.
- Every non-numpy import is justified in a code comment with one sentence on why.

## Senior-level gotchas

- **Leakage.** Fitting any transform (PCA, scaling, imputation, encoding, target encoding) on the full dataset before the train/val/test split is the most common silent bug. Always fit on the training fold.
- **P-hacking via test retraining.** If the model is re-fit because assumptions failed, the test set was seen; roll forward to the next time period or accept the prior fit's metrics.
- **Heavy tails.** Running OLS on raw income or raw counts inflates residual variance and breaks homoskedasticity. Transform before testing.
- **Small `n`, large `p`.** VIF is unstable; regularization (ridge/elastic-net) is the honest answer, not dropping features by hand.
- **Class imbalance.** A 99.9% accuracy on a 0.1% positive class is useless. Pick the metric first; refit second.
- **Drift.** A model that wins on val can rot in prod. Track input distributions and reconstruction error; alert before accuracy complaints arrive.
- **"Works once" is not done.** Add monitoring, a rollback, and a versioned artifact before deploying.
- **Never invent numbers.** If a baseline, a metric, or a data fact is not in code or in memory, ask the user.

## Handoff to modeling

When all four stages are done, the next session fits the model. The handoff is the artifact set, in order:

- **EDA audit log** — one line per column with the drop / keep / transform decision and reason. Stored at `eda/<data_version>/audit.json` (or equivalent). The model's reviewer reads this to understand which features never made it past elimination.
- **EDA-filtered feature matrix** at the chosen train/val/test split, with train-fold-only transforms applied. Stored at `eda/<data_version>/features.{parquet,npz}`.
- **PCA artifact** — `mean`, `components`, `explained_variance_ratio`, `singular_values`, `feature_version`, `data_version`. Stored at `pca/<data_version>/fit.json` (or equivalent).
- **Eigen-decomposition retention manifest** — `k` chosen, rationale (knee or target variance), top contributors per retained PC with absolute loadings, and the chosen output option (A: PC scores, or B: back-projected top-loading features). Stored at `pca/<data_version>/retention_manifest.json`.
- **Model input matrix** — the actual data the supervised stage will fit on (PC scores or back-projected features, per the manifest), at the same train/val/test split.
- **EDA findings and assumption-test results** from this skill's pipeline, recorded in the session file — including which assumptions failed and what was done about them.
- **Confirmed baseline and target metric.**

If any of the above is missing, the next session stops and asks. There is no fallback to "use whatever is in memory."

Record confirmed modeling decisions in `.ai/decisions/` per `repo-memory` the moment the user confirms them.

## Scope

Applies to every data-science pipeline in the repo, on the Python side. Sits on top of `repo-memory` (which owns session/decision discipline) and the engineering standards in `AGENTS.md` (soft delete, structured logging, contract-first API, multi-tenant keys). Pairs with `docker-testing` for running pipelines inside Docker and `pii-redaction` for keeping customer data out of memory.
