"URL: \(.url)"
+ "\nDefault branch: \(.defaultBranchRef.name // "unknown")"
+ "\nLanguages: \(.languages // [] | map(.name) | join(", ") | if . == "" then "(none)" else . end)"
+ "\nDescription: \(.description // "(no description)")"
