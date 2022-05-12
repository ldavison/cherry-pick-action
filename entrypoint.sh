#!/bin/bash

set -eEu

REPO_NAME=$(jq -r ".repository.full_name" "$GITHUB_EVENT_PATH")
MAX_RETRIES=${MAX_RETRIES:-5}
RETRY_INTERVAL=${RETRY_INTERVAL:-10}

PR_NUMBER=""
MERGED="false"
MERGE_COMMIT=""
RELEASE_NUMBER=""
USER_LOGIN=""


function fail() {
    if [ -n "${1}" ]; then
        echo "${1}"
    fi
    echo "::set-output name=cherry-picked::false"
    exit 1
}

function on_error() {
    gh pr comment "${PR_NUMBER}" --body "Cherry pick action failed - https://github.com/${REPO_NAME}/actions/runs/${GITHUB_RUN_ID}"
    fail
}
trap on_error ERR

function fetch_merge_details() {
    # shellcheck disable=SC2004
    for ((i = 0 ; i < $MAX_RETRIES ; i++)); do
        # use `--jq "."` to get a non-colorized output
        pr_resp=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}" --jq ".")
        MERGED=$(echo "${pr_resp}" | jq -r ".merged")
        if [[ "${MERGED}" != "true" ]]; then
            echo "Sleeping for ${RETRY_INTERVAL} before retrying"
            sleep "${RETRY_INTERVAL}"
            continue
        else
            MERGE_COMMIT=$(echo "${pr_resp}" | jq -r ".merge_commit_sha")
            RELEASE_NUMBER=$(echo "${pr_resp}" | jq -r ".milestone.title")
            USER_LOGIN=$(echo "${pr_resp}" | jq -r ".merged_by.login")
            break
        fi
    done

    if [[ "${MERGED}" != "true" ]]; then
        gh pr comment "${PR_NUMBER}" --body "Unable to cherry pick PR because it has not been merged."
        fail "PR not merged, unable to cherry pick"
    fi
}

function setup_git() {
    git config --global --add safe.directory /github/workspace
    git config --global user.email "${USER_LOGIN}@users.noreply.github.com"
    git config --global user.name "${USER_LOGIN} - Cherry Pick Into Release"
    {
        echo "machine github.com"
        echo "  login ${GITHUB_ACTOR}"
        echo "  password ${GITHUB_TOKEN}"
    } | tee "${HOME}/.netrc"
}

function cherry_pick() {
    git fetch origin

    # check for release branch
    TARGET_BRANCH="release/${RELEASE_NUMBER}"
    if ! git rev-parse --quiet --verify "origin/${TARGET_BRANCH}" > /dev/null; then
        gh pr comment "${PR_NUMBER}" --body "Unable to cherry pick PR because ${TARGET_BRANCH} does not exist."
        fail "${TARGET_BRANCH} does not exist"
    fi

    git checkout "${TARGET_BRANCH}"
    git cherry-pick "${MERGE_COMMIT}" &> /tmp/error.log || (
        gh pr comment "${PR_NUMBER}" --body "Error cherry picking ${MERGE_COMMIT} into release.<pre><code>$(cat /tmp/error.log)</code></pre>"
        fail "Error cherry picking ${MERGE_COMMIT} into release"
    )
    git push origin "${TARGET_BRANCH}:${TARGET_BRANCH}"
    gh pr comment "${PR_NUMBER}" --body "Successfully cherry picked ${MERGE_COMMIT} into ${TARGET_BRANCH}.<br>https://github.com/${REPO_NAME}/actions/runs/${GITHUB_RUN_ID}"
    echo "::set-output name=cherry-picked::true"
}

if [ -z "${PR_NUMBER}" ]; then
    PR_NUMBER=$(jq -r ".pull_request.number" "${GITHUB_EVENT_PATH}")
    if [[ "${PR_NUMBER}" == "null" ]]; then
        fail "unable to get pull request number from: ${GITHUB_EVENT_PATH}"
    fi
fi

if [[ -z "${GITHUB_TOKEN}" ]]; then
	fail "GITHUB_TOKEN must be set as an env var"
fi

fetch_merge_details

set -x
setup_git
cherry_pick
