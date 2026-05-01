Title: chore(deps): mitigate CVEs — pin Jackson 2.x and exclude Flyway Jackson 3

Summary

This branch (`fix/cves-20260428`) contains a conservative, short-term mitigation for mixed Jackson major versions and other dependency CVE triage findings.

What I changed

- Added `dependencyManagement` pins for `com.fasterxml.jackson` 2.21.x in `pom.xml` to stabilise the classpath.
- Excluded `tools.jackson.core` transitive artifacts pulled by `org.flywaydb:flyway-core` so the project uses the pinned Jackson 2.x artifacts.
- Created/updated `CVE_TRIAGE.md` with findings, mappings, and recommended next steps.
- Added a focused unit test `AuthIntegrationTest` that validates `JwtTokenProvider` logic without starting Spring.

Why

The dependency tree showed both `com.fasterxml.jackson` 2.x and `tools.jackson.core` 3.x on the classpath which is a risky mixed-major state. This short-term approach forces 2.x to avoid runtime conflicts while we evaluate the longer-term option (migrate to Jackson 3 by upgrading Spring Boot and related libraries).

Verification performed

- `mvn -DskipTests package` — BUILD SUCCESS.
- `mvn -Dtest=AuthIntegrationTest test` — 1 test passed, 0 failures.
- `mvn dependency:tree` verified the exclusions reduced the Jackson 3.x transitive artifacts from Flyway.

Risk and follow-ups

- Short-term fix: exclusions may mask incompatibilities with Flyway internals that expect Jackson 3; run Flyway migrations in a staging environment before merging.
- Long-term: plan to upgrade to Jackson 3 by moving to a Spring Boot version that supports it.
- Add a CI Maven Enforcer rule to detect mixed Jackson majors automatically.

Files changed

- `pom.xml` (dependencyManagement pins + Flyway exclusions)
- `CVE_TRIAGE.md` (triage notes)
- `src/test/java/.../AuthIntegrationTest.java`

Next steps I recommend

1. Run the full test suite and Flyway migrations in a staging environment.
2. Add Maven Enforcer CI check for mixed Jackson majors.
3. Decide on long-term migration to Jackson 3 (upgrade Spring Boot) and plan that work.

Notes

See `CVE_TRIAGE.md` in this folder for detailed CVE mappings and links to advisories.

Branch: fix/cves-20260428

Reviewer suggestions: backend leads, security engineer, and DB/staging owner.
