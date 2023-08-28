# GitHub Files

The [`.github`](./../.github) directory contains files that are used by GitHub.
They are useful for configuring GitHub Actions, GitHub Pages, and other GitHub features.

Note that this file cannot be named `README.md` because GitHub will render it over the main repository `README.md` file.

## GitHub Actions

GitHub Actions are a way to automate tasks within GitHub.
They are configured using YAML files in the [`.github/workflows`](./workflows) directory.
The tasks are run on GitHub's servers and can be triggered by events such as a push to a branch or a pull request.
We run actions on pull requests to check that the code is formatted correctly and that the tests pass.

The list of actions is

- [`code-linting.yml`](./workflows/code-linting.yml): Checks that code is formatted correctly using the Super Linter action.
- [`language-linting.yml`](./workflows/language-linting.yml): Checks for the English language the Alex Action, action.

## GitHub Issues

GitHub Issues are a way to track bugs and feature requests.
They are configured using the [`.github/ISSUE_TEMPLATE`](./ISSUE_TEMPLATE) directory.
The templates are used to create new issues.
We have templates for

- [Bug reports](./ISSUE_TEMPLATE/bug_report.md)
- [Feature requests](./ISSUE_TEMPLATE/feature_request.md)
