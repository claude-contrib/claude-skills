# Changelog

## [1.1.0](https://github.com/claude-contrib/claude-skills/compare/github-v1.0.0...github-v1.1.0) (2026-03-19)


### Features

* add /gh-issue-create slash command for GitHub issues ([e840578](https://github.com/claude-contrib/claude-skills/commit/e840578b21172dff056c15f7fb5e195d7fede642))
* add /gh-pr-create slash command for pull requests ([7c43f72](https://github.com/claude-contrib/claude-skills/commit/7c43f72b8664fbd1487fe66c0cf8f19004c3c71e))
* add duplicate detection context block to gh-issue-create ([04431a7](https://github.com/claude-contrib/claude-skills/commit/04431a7fb83849fadda9549318cd826459686667))
* add GitHub plugin with slash commands for issues and PRs ([#3](https://github.com/claude-contrib/claude-skills/issues/3)) ([94aea81](https://github.com/claude-contrib/claude-skills/commit/94aea8137fec8ab5d61196b3dd289540cc9e627f))
* **github:** move plan storage to .github/claude/plans/ and add branch detection ([78f46ed](https://github.com/claude-contrib/claude-skills/commit/78f46ed224fffe48e604f179383a8546d10fe0e2))
* **github:** targeted improvements across all command files ([282df83](https://github.com/claude-contrib/claude-skills/commit/282df837d96b5881afcf92cf0ee92cf716141ee5))
* split planning workflow into draft plan and execution promotion ([74492a5](https://github.com/claude-contrib/claude-skills/commit/74492a5f8c2b69a706e3b3b43b32219aba842cd8))


### Bug Fixes

* add --base flag to PR creation and complete error tables ([e361372](https://github.com/claude-contrib/claude-skills/commit/e361372512a3c089ca57be2280fec93dfbd9228c))
* add concrete severity criteria to PR review command ([d35140b](https://github.com/claude-contrib/claude-skills/commit/d35140bd72d5ed24ff3382deac88c288f59bb65b))
* add missing validation, session notes, and save instructions to gh-issue-develop ([e27b130](https://github.com/claude-contrib/claude-skills/commit/e27b130e87e2822568fe4923466170c5fdcba3e6))
* correct focus area extraction and document --assignee flag ([50bab98](https://github.com/claude-contrib/claude-skills/commit/50bab98adb206ca2b0419499f20bb5b9bb3a61d3))
* focus area extraction returns empty when no focus area given ([3de1cbe](https://github.com/claude-contrib/claude-skills/commit/3de1cbee952da36fe046a60f2ce3104f7abbd470))
* **github:** align error table wording with corrected step 1 warning ([cf9ad76](https://github.com/claude-contrib/claude-skills/commit/cf9ad76678c205315d208ada5cb7162607916fda))
* **github:** correct branch-from description in gh-issue-develop warning ([e178925](https://github.com/claude-contrib/claude-skills/commit/e1789257c7e1c934c03f788d3e8d2f2fbf1fa63b))
* **github:** refine context blocks for clarity and precision ([388840b](https://github.com/claude-contrib/claude-skills/commit/388840b0313667bdb07539e342a3d9bea4d895d8))
* namespace session state files and add --assignee support ([a03e172](https://github.com/claude-contrib/claude-skills/commit/a03e1722f8404c844485caab75d0b67c9ac27fac))
* replace tilde with ${HOME} in all shell paths ([a74db43](https://github.com/claude-contrib/claude-skills/commit/a74db4349ad7e62468e170a2e56b8a86175ed31f))
