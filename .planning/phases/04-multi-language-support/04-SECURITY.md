---
phase: 04
slug: multi-language-support
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-13
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Resource files to runtime | String resources loaded at runtime from compiled XML | No user input — compiled into PRG binary at build time |
| Phone app settings to device | Mosque slug entered on phone, stored via Properties API | Already validated in Phase 1 |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-04-01 | Tampering | resources-fre/strings/strings.xml | accept | Compiled into PRG binary at build time. No runtime file access. Tampering requires modifying built binary on watch — not a realistic attack vector. | closed |
| T-04-02 | Info Disclosure | String content in resources | accept | All strings are UI labels with zero sensitive data ("dans", "maintenant", setting labels). No PII, no secrets. | closed |
| T-04-03 | Denial of Service | loadResource() in Glance 28KB budget | mitigate | Original plan: ~400 bytes overhead acceptable. Actual: loadResource() exceeded budget. Fixed by replacing with hardcoded language conditionals using System.LANGUAGE_FRE. No loadResource() calls remain in Glance. | closed |
| T-04-04 | Tampering | Widget string resources | accept | Same rationale as T-04-01 — compiled into PRG binary at build time, no runtime attack surface. | closed |
| T-04-05 | Info Disclosure | Widget display strings | accept | All strings are UI labels ("dans", "maintenant", prayer schedule header). Zero sensitive data. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-04-01, T-04-04 | String resources compiled into binary — no runtime tampering vector | GSD workflow | 2026-04-13 |
| AR-02 | T-04-02, T-04-05 | All localized strings are non-sensitive UI labels | GSD workflow | 2026-04-13 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-13 | 5 | 5 | 0 | gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-13
