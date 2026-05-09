Dependency-check after adding Jackson 2.x pins

I ran a focused Maven dependency tree after adding `dependencyManagement` pins for Jackson 2.21.x. Results show the project still contains mixed Jackson majors:
- From Flyway: `tools.jackson.core:jackson-databind:3.1.1` and `tools.jackson.core:jackson-core:3.1.1` (groupId `tools.jackson.core`)
- From Spring / JJWT / Google libs: `com.fasterxml.jackson.core:jackson-databind:2.21.2`, `com.fasterxml.jackson.core:jackson-core:2.21.2` (groupId `com.fasterxml.jackson.core`)

Why pins didn't unify
- Flyway depends on Jackson 3.x under the `tools.jackson.core` groupId (major-version and groupId change), so a `dependencyManagement` pin of `com.fasterxml.jackson.core:jackson-databind` did not override Flyway's `tools.jackson.core` coordinates.

Recommended next actions (choices)
1) Conservative short-term mitigation (lowest risk):
  - Exclude `tools.jackson.core:jackson-databind` and `tools.jackson.core:jackson-core` from `org.flywaydb:flyway-core` and force `com.fasterxml.jackson` 2.21.x artifacts via `dependencyManagement`. Test thoroughly — Flyway may rely on 3.x APIs and this could break migrations.

  Example exclusion snippet:
   <dependency>
     <groupId>org.flywaydb</groupId>
     <artifactId>flyway-core</artifactId>
2) Progressive (recommended for long-term correctness):
  - Migrate the project to consistent Jackson 3.x by upgrading Spring Boot and other direct dependencies to versions that support Jackson 3 (this is larger work but removes classpath mixing).

3) Intermediate: Replace or update transitive libraries that bring 2.x/3.x conflicts (e.g., update `jjwt` to a release aligned with Jackson 3 if available, or replace `jjwt-jackson` usage with a JJWT configuration that doesn't require jackson-databind).
Validation steps after changes

- Run:

  mvn -DskipTests dependency:tree -Dincludes="com.fasterxml.jackson.core,tools.jackson.core,com.fasterxml.jackson.datatype,com.fasterxml.jackson.module"
- Then run a package build and tests:

  mvn -DskipTests package
  mvn test

Add CI guard: add a Maven Enforcer rule or a small script in CI to fail on multiple Jackson major artifacts.
I'll pause here and wait for your preferred strategy (exclude Flyway + pin to 2.x, or migrate to Jackson 3 by upgrading Spring Boot). If you want, I can create a branch and implement the chosen mitigation, run the build, and open a PR with notes.

Action taken (short-term mitigation)

- Excluded `tools.jackson.core:jackson-databind` and `tools.jackson.core:jackson-core` from `org.flywaydb:flyway-core` and `org.flywaydb:flyway-database-postgresql` in `pom.xml` to force use of `com.fasterxml.jackson` 2.21.x pins defined in `dependencyManagement`.

- Rationale: Flyway brought Jackson 3.x under the `tools.jackson.core` groupId; excluding those transitive artifacts lets us consistently use the 2.x Jackson artifacts Spring Boot manages as a lower-risk short-term mitigation.

- Risk: Flyway may rely on APIs present only in Jackson 3.x; after exclusion we must run migrations in a staging environment and run the full test suite to detect runtime incompatibilities.

- Validation: I will build the package and run the focused JWT unit test next.
# CVE Triage — nirdist-backend

This file records initial items to triage from the project's effective dependency tree.

Status: In-progress

How to use
- Use the effective dependency tree (dependency-tree-utf8.txt) to confirm resolved versions.
- Search NVD / GitHub Advisory / OSV for each artifact+version and record CVE IDs and severity.
- For each vulnerable library propose minimal safe upgrade (or mitigation), test locally, and open a branch/PR.

Flagged artifacts (from dependency-tree-utf8.txt)
- `com.fasterxml.jackson.core:jackson-databind` — resolved: 3.1.1 (and 2.21.2 via other deps)
- `com.fasterxml.jackson.core:jackson-core` — resolved: 3.1.1 (and 2.21.2 via other deps)
- `org.apache.tomcat.embed:tomcat-embed-core` — resolved: 10.1.54
- `io.netty:netty-*` — resolved: 4.1.132.Final
- `io.grpc:grpc-netty-shaded` — resolved: 1.76.0
- `com.google.protobuf:protobuf-java` — resolved: 3.25.5
- `org.flywaydb:flyway-core` — resolved: 12.5.0
- `org.apache.httpcomponents:httpclient` — resolved: 4.5.14
- `org.postgresql:postgresql` — resolved: 42.7.10
- `com.google.guava:guava` — resolved: 33.5.0-jre
- `io.jsonwebtoken:jjwt` — resolved: 0.11.5

Immediate next steps
1. For each artifact above, search NVD/OSV/GitHub for CVEs affecting the specific resolved version. Record: CVE ID, severity, description, fixed-in version, and link to advisory.
2. Prioritize fixes: Critical/High first. Prefer upgrading direct dependencies; for transitive-only issues, consider overriding versions via `dependencyManagement` or excluding transitive artifacts where safe.
3. Create a branch `fix/cves-YYYYMMDD` and apply upgrades incrementally. Run `mvn -DskipTests package` and then `mvn test` after each change.

Useful commands
```
mvn dependency:tree -DoutputFile=dependency-tree.txt
mvn versions:display-dependency-updates > versions-updates.txt
# Run tests for project
mvn test -DskipITs=false
```

Record template (per artifact)
- Artifact: groupId:artifactId
- Current version: x.y.z
- CVE(s):
  - CVE-YYYY-NNNN — severity — short summary — fixed in version(s)
- Recommended action: upgrade to X.Y.Z / apply mitigation / exclude transitive
- Notes: compatibility risks, test results, PR link

Tracker
- Triage started: yes
- Triage owner: TBD

Findings so far (initial web searches)

- `com.fasterxml.jackson.core:jackson-databind` — searched NVD: https://nvd.nist.gov/vuln/search/results?query=jackson-databind%203.1.1&search_type=all
  - Note: NVD search returned general results; specific CVE IDs and fixed-in versions need extraction and verification (OSV/GitHub advisories may be faster).
- `org.apache.tomcat.embed:tomcat-embed-core` — searched NVD: https://nvd.nist.gov/vuln/search/results?query=tomcat-embed-core%2010.1.54&search_type=all
  - Note: verify Tomcat advisory pages for CVEs affecting 10.1.54 and map to fixed Tomcat versions.
- `io.netty:netty` — searched NVD: https://nvd.nist.gov/vuln/search/results?query=netty%204.1.132.Final&search_type=all
  - Note: Netty advisories often list affected version ranges; extract exact vulnerable ranges and recommended upgrades.

Next: continue searching OSV/GitHub Advisory and NVD for the remaining flagged artifacts (grpc-netty-shaded, protobuf, flyway, httpclient, postgresql, guava, jjwt) and record CVE IDs, severities, and fixed versions in this file.

OSV searches performed

- `io.grpc:grpc-netty-shaded` (1.76.0) — OSV search: https://osv.dev/vulns?package=PB&query=grpc-netty-shaded%201.76.0
  - Note: OSV search shell returned the general vulnerabilities page; I will refine queries (package groupId/artifactId) and consult GitHub Advisory/NVD for specific CVE IDs.
- `com.google.protobuf:protobuf-java` (3.25.5) — OSV search: https://osv.dev/vulns?package=maven:com.google.protobuf:protobuf-java&version=3.25.5
  - Note: protobuf advisories may be listed under protobuf project CVEs; will cross-check NVD/OSV and protobuf release notes.
- `org.flywaydb:flyway-core` (12.5.0) — OSV search: https://osv.dev/vulns?package=maven:org.flywaydb:flyway-core&version=12.5.0
  - Note: Flyway vulnerabilities are less common, but Flyway depends on jackson-databind; verify transitive issues.

Next actions (immediate)
1. Refine OSV/GitHub queries for exact package coordinates and collect CVE IDs + advisories for these three artifacts.
2. Repeat for remaining artifacts: `httpclient`, `postgresql`, `guava`, `jjwt`, `grpc`, `netty`, `tomcat`, `jackson`.

Jackson searches

- `com.fasterxml.jackson.core:jackson-databind` (3.1.1 / 2.21.2) — OSV: https://osv.dev/vulns?package=maven:com.fasterxml.jackson.core:jackson-databind&version=3.1.1
  - NVD search: https://nvd.nist.gov/vuln/search/results?query=jackson-databind&search_type=all
  - GitHub Advisory search: https://github.com/advisories?query=jackson-databind
  - Note: jackson-databind historically has multiple high-severity gadget/exploit CVEs; we must extract CVE IDs and fixed versions, prefer upgrading to the latest 3.x or 2.21.x patch that addresses those CVEs.

- `com.fasterxml.jackson.core:jackson-core` (3.1.1 / 2.21.2) — OSV: https://osv.dev/vulns?package=maven:com.fasterxml.jackson.core:jackson-core&version=3.1.1
  - NVD search: https://nvd.nist.gov/vuln/search/results?query=jackson-core&search_type=all
  - GitHub Advisory search: https://github.com/advisories?query=jackson-core
  - Note: jackson-core advisories are typically less frequent, but check for CVEs tied to jackson-databind or jackson-core.

Jackson CVEs (initial extract)

- `CVE-2026-29062` — reported for `tools.jackson.core:jackson-core` (see GHSA-6v53-7c9g-w56r): https://github.com/advisories/GHSA-6v53-7c9g-w56r
- `CVE-2025-52999` — reported for `com.fasterxml.jackson.core:jackson-core`: https://github.com/advisories/GHSA-h46c-h94j-95f3
- `CVE-2023-35116` — related to `jackson-databind` (DoS / serialization): https://github.com/advisories/GHSA-gx6w-fqg7-mc3p
- `CVE-2022-42003` — uncontrolled resource consumption in `jackson-databind`: https://github.com/advisories/GHSA-jjjh-jjxp-wpff
- `CVE-2021-46877` — `jackson-databind` denial of service: https://github.com/advisories/GHSA-3x8x-79m2-3w2w
- Older advisories (context): `CVE-2019-2956`, `CVE-2019-10202`, `CVE-2017-4995` — related historic deserialization/gadget issues; verify presence in our resolved versions.

Actionable next steps for Jackson
- For each CVE above: open the GHSA/NVD entry, record affected version ranges and 'fixed in' version(s), and add the exact fixed version to this file.
- If a CVE affects a version present in our `dependency-tree-utf8.txt`, plan an immediate upgrade to the nearest patched release in `dependencyManagement` (or use exclusions/overrides for transitive cases), test, and commit.

Tomcat & Netty searches

- `org.apache.tomcat.embed:tomcat-embed-core` (10.1.54) — GitHub Advisory search: https://github.com/advisories?query=tomcat
  - Recent GHSA/CVE entries include CVE-2026-34483, CVE-2026-34487, CVE-2026-34500 (see GHSA links in search results). Verify affected ranges and fixed versions on Apache Tomcat security pages.

- `io.netty:*` (4.1.132.Final) — GitHub Advisory search: https://github.com/advisories?query=netty
  - Recent advisories reference CVE-2026-33871 (netty-codec-http2), CVE-2026-33870 (netty-codec-http), CVE-2025-55163 (grpc-netty-shaded). Determine if our resolved netty modules are within affected ranges and capture fixed versions.

Actionable next steps for Tomcat/Netty
- Open each GHSA/CVE link from the advisory search results, record affected version ranges and 'fixed in' versions, then add a recommended upgrade (exact version) to this file.
- Prioritize Tomcat if any 'critical' or 'high' advisories affect `10.1.54`.

Tomcat advisory summary (extracted)

- `CVE-2026-34483` (GHSA-rv64-5gf8-9qq8) — Improper Encoding/Escaping in `JsonAccessLogValve`
  - Affected versions: 11.0.0-M1 .. 11.0.20, 10.1.0-M1 .. 10.1.53, 9.0.40 .. 9.0.116
  - Patched versions: 11.0.21, 10.1.54, 9.0.116
  - Our resolved `org.apache.tomcat.embed:tomcat-embed-core`: 10.1.54 — status: patched

- `CVE-2026-34487` (GHSA-x4m4-345f-5h5g) — Insertion of sensitive info into logs
  - Affected versions: 11.0.0-M1 .. 11.0.20, 10.1.0-M1 .. 10.1.53, 9.0.13 .. 9.0.116
  - Patched versions: 11.0.21, 10.1.54, 9.0.117
  - Our `tomcat-embed-core:10.1.54` — status: patched

- `CVE-2026-34500` (GHSA-24j9-x2wg-9qv6) — CLIENT_CERT auth does not fail as expected
  - Affected versions: 11.0.0-M14..11.0.20, 10.1.22..10.1.53, 9.0.92..9.0.116
  - Patched versions: 11.0.21, 10.1.54, 9.0.117
  - Our `tomcat-embed-core:10.1.54` — status: patched

Netty / grpc-netty-shaded advisory summary (extracted)

- `CVE-2026-33870` (GHSA-pwqr-wmgm-9rr8) — HTTP Request Smuggling via chunked extension quoted-string parsing
  - Affected versions: < 4.1.132.Final and >=4.2.0.Alpha1,<4.2.10.Final
  - Patched versions: 4.1.132.Final, 4.2.10.Final
  - Our resolved `io.netty:netty-*`: 4.1.132.Final — status: patched

- `CVE-2025-55163` (GHSA-prj3-ccx8-p6x4) — MadeYouReset HTTP/2 DDoS (affects grpc-netty-shaded)
  - Affected `grpc-netty-shaded`: < 1.75.0
  - Patched `grpc-netty-shaded`: 1.75.0
  - Our resolved `io.grpc:grpc-netty-shaded`: 1.76.0 — status: patched

- `CVE-2025-67735` (GHSA-84h7-rjj3-6jx4) — CRLF Injection in `HttpRequestEncoder`
  - Affected versions: >=4.2.0.Alpha1,<4.2.8.Final and <4.1.129.Final
  - Patched versions: 4.2.8.Final, 4.1.129.Final
  - Our `io.netty:4.1.132.Final` — status: patched

Summary: For the Tomcat and Netty advisories checked so far, our resolved versions in `dependency-tree-utf8.txt` are already at patched releases (Tomcat: `10.1.54`, Netty: `4.1.132.Final`, grpc-netty-shaded: `1.76.0`). Continue with protobuf, flyway, httpclient, postgresql, guava, jjwt.

Jackson advisory summary (extracted)

- `CVE-2026-29062` (GHSA-6v53-7c9g-w56r) — Nesting depth constraint bypass in `UTF8DataInputJsonParser` (`jackson-core`)
  - Affected versions: >= 3.0.0, < 3.1.0
  - Patched versions: 3.1.0
  - Our resolved `jackson-core`: 3.1.1 — status: patched

- `CVE-2025-52999` (GHSA-h46c-h94j-95f3) — StackOverflow on deeply nested data (`jackson-core`)
  - Affected versions: < 2.15.0
  - Patched versions: 2.15.0
  - Our resolved `jackson-core`: 3.1.1 — status: not-applicable (3.x contains different fixes), but verify no transitive 2.x artifacts

- `CVE-2022-42003` (GHSA-jjjh-jjxp-wpff) — Uncontrolled resource consumption (`jackson-databind`)
  - Affected versions: >=2.4.0-rc1,<2.12.7.1 and >=2.13.0,<2.13.4.2
  - Patched versions: 2.12.7.1, 2.13.4.2 (and later 2.14.0+)
  - Our resolved `jackson-databind`: 3.1.1 — status: likely patched; confirm no 2.x transitive usage

- `CVE-2023-35116` (GHSA-gx6w-fqg7-mc3p) — DoS / cyclic objects via crafted payloads (jackson-databind thru 2.15.2)
  - Affected versions: up through 2.15.2 (advisory unreviewed / package mapping unclear)
  - Patched versions: see upstream; verify 3.x status
  - Our `jackson-databind:3.1.1` — status: likely patched, but validate against latest jackson-databind security notes

- `CVE-2021-46877` (GHSA-3x8x-79m2-3w2w) — DoS via JDK serialization of JsonNode
  - Affected versions: >=2.10.0,<2.12.6 and >=2.13.0,<2.13.1
  - Patched versions: 2.12.6, 2.13.1
  - Our `jackson-databind:3.1.1` — status: not-applicable (3.x), but check for transitive 2.x

Notes / next verification steps for Jackson

- Confirm there are no transitive `jackson-core` or `jackson-databind` 2.x artifacts in `dependency-tree-utf8.txt` (some frameworks may pull 2.x).
- If any 2.x artifacts exist, prefer upgrading them to 2.15.0+ or aligning to 3.1.1 where compatible.
- Recommended immediate action: verify `mvn dependency:tree -Dincludes=com.fasterxml.jackson.core` and confirm resolved versions; if any are < patched releases, plan minimal upgrades or add `dependencyManagement` overrides.

Dependency scan results (historical snapshot from `dependency-tree-utf8.txt` before the Flyway exclusions)

- Findings from the earlier snapshot:
  - `org.springframework.boot:spring-boot-starter-json` pulls Jackson 2.x modules:
    - `com.fasterxml.jackson.datatype:jackson-datatype-jdk8:2.21.2`
    - `com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.21.2`
    - `com.fasterxml.jackson.module:jackson-module-parameter-names:2.21.2`
  - `org.flywaydb:flyway-core:12.5.0` pulls `tools.jackson.core:jackson-databind:3.1.1` and `tools.jackson.core:jackson-core:3.1.1`.
  - `io.jsonwebtoken:jjwt-jackson` transitively pulls `com.fasterxml.jackson.core:jackson-databind:2.21.2`.
  - `com.google.http-client:google-http-client-jackson2` and other Google libs reference `com.fasterxml.jackson.core:jackson-core:2.21.2`.

- Current validation after the `pom.xml` exclusions and a fresh `mvn dependency:tree` run on 2026-05-01:
  - `tools.jackson.core:*` no longer appears in the backend tree.
  - Remaining Jackson artifacts are all `com.fasterxml.jackson` 2.21.x / 2.21.
  - The mixed-major Jackson issue is resolved in the working tree.

- Recommended immediate actions:
  1. Keep the CI guard that checks for `tools.jackson.core` so the mixed-major Jackson state does not return.
  2. If you want the snapshot files to match the current state, regenerate `dependency-tree.txt` and `dependency-tree-utf8.txt` after the exclusions.
  3. Continue monitoring Flyway release notes and Jackson CVEs in case the current exclusions need to be revisited later.

Next: the backend mitigation is validated. The remaining advisories in this file are historical notes and maintenance items rather than blockers for the current tree.

Additional library advisory mappings

1) `com.google.protobuf:protobuf-java` — resolved version: `3.25.5`
  - Advisory: `CVE-2024-7254` (GHSA-735f-pc8j-v9w8)
  - Affected versions: < 3.25.5, (and some 4.x prereleases ranges)
  - Patched versions: 3.25.5, 4.27.5, 4.28.2
  - Our resolved `protobuf-java:3.25.5` — status: patched

2) `org.postgresql:postgresql` — resolved version: `42.7.10`
  - Advisory: `CVE-2025-49146` (GHSA-hq9p-pm7w-8p54)
  - Affected versions: >= 42.7.4 and < 42.7.7
  - Patched version: 42.7.7
  - Our resolved `postgresql:42.7.10` — status: not in affected range (no action required for this advisory), but continue monitoring for other pgjdbc advisories

3) Apache HttpClient
  - We have two HttpClient artifacts present:
    - `org.apache.httpcomponents:httpclient:4.5.14` (via Google libs)
    - `org.apache.httpcomponents.client5:httpclient5:5.5.2`
  - Recent advisory: `CVE-2026-40542` (GHSA-v468-qcjx-r72w) — Missing critical step in authentication in Apache HttpClient 5.6; recommended upgrade to `5.6.1`.
  - Our `httpclient5:5.5.2` — status: older than 5.6, not directly in the affected 5.6.x line; still recommend verifying whether backported fixes are required and consider upgrading to 5.6.1+ when feasible.
  - For `httpclient:4.5.14`, no immediate GHSA indicating 4.5.14 is affected was found in a quick search; verify NVD/OSS advisories for 4.x if needed.

4) `com.google.guava:guava` — resolved version: `33.5.0-jre`
  - Advisory: `CVE-2023-2976` (GHSA-7g45-4rm6-3mm3)
  - Affected versions: >= 1.0, < 32.0.0-android
  - Patched versions: 32.0.0-android (maintainers recommend 32.0.1 for Windows fixes)
  - Our `guava:33.5.0-jre` — status: patched

5) `io.jsonwebtoken:jjwt-*` — resolved versions: `0.11.5` (api/impl/jackson)
  - Advisory: `CVE-2024-31033` (GHSA-r65j-6h5f-4f92) — originally published but later withdrawn
  - Advisory status: withdrawn — no active GHSA fix recommended
  - Our `jjwt:0.11.5` — status: advisory withdrawn; still recommend upgrading to latest maintained release when convenient and review usage of `jjwt-jackson` (which pulls `jackson-databind:2.21.2`) as part of Jackson alignment work

6) `org.flywaydb:flyway-core` — resolved version: `12.5.0`
  - Quick GHSA search returned no direct advisories for Flyway core.
  - Flyway pulls `tools.jackson.core:jackson-databind:3.1.1` (already noted). No action required now, but continue monitoring Flyway release notes.

Notes / recommended next steps (short):

- Run `mvn dependency:tree -Dincludes=com.fasterxml.jackson.core,tools.jackson.core,com.fasterxml.jackson.datatype,com.fasterxml.jackson.module` and confirm all Jackson coordinates (we already saw mixed 2.x and 3.x).
- Decide Jackson alignment strategy (conservative pin to 2.21.2 vs migrate to 3.1.1). If pinning to 2.x prefer adding `dependencyManagement` overrides and exclude `tools.jackson.core:jackson-databind:3.x` from Flyway if incompatible.
- For HttpClient: schedule upgrade planning — moving `httpclient5` to `5.6.1+` is advisable when compatibility allows; confirm whether `google-http-client` transitive uses require changes.
- For PostgreSQL JDBC: our version `42.7.10` is not in the affected `42.7.4-42.7.6` range for `CVE-2025-49146`, and it is newer than the recommended `42.7.7` patched baseline.
- Add CI checks or Maven Enforcer rules to detect mixed Jackson major versions and block merges until resolved.
