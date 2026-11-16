# With your next change

Small migrations that every repository needs once. Nobody sweeps the repositories for them: each one is made together with the next change to a repository that still needs it.

- Before you finish an implementation task, check the repository against every entry below and apply those that still apply. This is in scope for any implementation task, as an exception to "keep unrelated cleanup out of scope" in [core policy](./core.md).
- Put the migration in its own commit in the same branch or PR, so the diff of the actual change stays readable.
- Skip an entry when the task's scope limit excludes it ("one line only") or when the change is docs-only, and say so in the report.
- An entry is deleted from this page once its "Done when" condition holds for every repository.

## Maven repository URL: `/releases` becomes `/sneakymouse`

Added 2026-11-16. The team's Maven repository for our own artifacts was renamed from `releases` to `sneakymouse`. The old URL is an alias that still works for reading and publishing, and it will be removed.

**Change:** replace `https://maven.sneakyrp.com/releases` with `https://maven.sneakyrp.com/sneakymouse` everywhere in the repository: dependency repositories, the publishing repository, and README or docs snippets.

```diff
-maven("https://maven.sneakyrp.com/releases")
+maven("https://maven.sneakyrp.com/sneakymouse")
```

- Change only the URL. Keep the publishing repository's name (`sneakyrp`) and its credentials block as they are.
- Do not add read credentials to the build file. Credentials for reading the Maven server come from outside the repository: a Gradle init script on the developer machine and on the CI runners applies the Gradle properties `sneakyrpReadUsername` / `sneakyrpReadPassword` to every repository on `maven.sneakyrp.com` (see [Maven access](./maven-access.md)).

**Check:** `git grep -n "maven.sneakyrp.com/releases"` prints nothing, and `./gradlew build` still resolves the team's artifacts.

**Done when:** no repository references `maven.sneakyrp.com/releases` and the alias has been removed from the Maven server.
