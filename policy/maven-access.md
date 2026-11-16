# Maven access

Load when a build fails with 401 or 403 from `maven.sneakyrp.com`, when you add a dependency on a team artifact or look up its versions, or when you add a CI workflow that builds with Gradle.

## How builds authenticate

- The team's own artifacts (`io.github.team-sneakymouse:*`) are in `https://maven.sneakyrp.com/sneakymouse`. Reading it requires a read token.
- Builds get the token from outside the repository. A Gradle init script in the Gradle user home (`init.d/sneakyrp-maven.init.gradle`) gives every dependency repository on that host the Gradle properties `sneakyrpReadUsername` / `sneakyrpReadPassword`. The script and its setup are in the [ci repository](https://github.com/Team-Sneakymouse/ci#maven-read-access).
- Build files therefore declare the repository by URL only. Never add read credentials to a build file, a settings file, a `gradle.properties` inside a repository, or a workflow.
- The publishing repository (`sneakyrp`) keeps its own credentials block and is unrelated to reading.

## A build fails with 401 or 403

A 401 means the request carried no valid token: this machine is not set up, or its token was revoked. A 403 means the token is valid but does not cover that repository.

1. Check the setup without printing a secret: does `init.d/sneakyrp-maven.init.gradle` exist in the Gradle user home (`$GRADLE_USER_HOME`, otherwise `~/.gradle`), and are the two properties defined, in its `gradle.properties` (look at key names only) or as `ORG_GRADLE_PROJECT_sneakyrpReadUsername` / `ORG_GRADLE_PROJECT_sneakyrpReadPassword` in the environment?
2. **Developer machine, something missing:** stop and ask the developer to run the setup from the ci repository (`java maven/SneakyrpMavenSetup.java`). It asks for the token in its own window. Do not ask for the token in the conversation.
3. **Cloud session with both environment variables but no script:** copy `maven/sneakyrp-maven.init.gradle` from the ci repository into `init.d/` of the Gradle user home yourself, then rerun. If the variables are missing, stop and report it.
4. **Setup complete and still refused:** stop and report the exact URL and status. Do not retry in a loop: repeated failed logins lock the address out for a while.

Do not work around a refusal. That rules out copying jars into the repository, switching to `mavenLocal()` or `files(...)`, removing the dependency, and reading someone else's token from another place.

## Handling the token

- The token is a secret. Do not print, copy or search the `gradle.properties` in the Gradle user home, and keep the token out of commits, logs, command output and reports.
- To read `maven-metadata.xml` yourself (for example to find the latest published version), pass the read pair to the request without echoing it, or take the version from a peer plugin's build file.

## CI

- The shared runner already has the init script and a read token, so workflows that call the shared `ci` workflows need nothing.
- A workflow on a GitHub-hosted runner has neither and cannot resolve team artifacts. Use the shared workflow, not a second way of passing credentials.
