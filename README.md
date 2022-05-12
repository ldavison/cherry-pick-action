# cherry-pick-action

This action attempts to cherry pick a squashed pull request merge into a release branch using a milestone assigned to the pull request.

A milestone with a title of "42" will match to a branch of "release/42". If no branch is found, the operation will fail.

## Permissions

This action relies on `contents` and `pull-requests` permissions being granted `write` access. In order to push the cherry picked commit back to the remote, `contents` is used. This action will post it's results of the operation to the pull request as a comment, which relies on the `pull-requests` permission.

## Environment

### `GITHUB_TOKEN`

**Required** The GitHub token, where `contents` and `pull-requests` both have `write` permission.

## Outputs

### `cherry-picked`

Whether or not the commit was successfully cherry picked into a release branch. Set to true or false.

## Example usage

```yaml
name: Cherry Pick Into Release
on:
  pull_request:
    types: [closed]

permissions:
  contents: write
  pull-requests: write

jobs:
  cherry-pick:
    if: github.event.pull_request.merged == true
    name: Cherry Pick
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0 # must be 0
      - name: Cherry Pick
        uses: actions/cherry-pick-action@v1
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
```

The example workflow is set up to run when a pull request is closed. This is true regardless of it being merged or not. A conditional is used to only run the job if the pull request was merged. This action is designed to work with `actions/checkout` with a `fetch-depth: 0`. If this is not set correctly, the cherry pick will likely fail to merge. The `GITHUB_TOKEN` is added to the `env` instead of as an input to more easily work with [GitHub CLI](https://cli.github.com).
