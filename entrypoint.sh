#!/bin/bash

WPENGINE_HOST="git.wpengine.com"
WPENGINE_ENVIRONMENT_DEFAULT="production"
SSH_KEY_TYPE_DEFAULT="rsa"
WPENGINE_ENV=${WPENGINE_ENVIRONMENT:-$WPENGINE_ENVIRONMENT_DEFAULT}
LOCAL_BRANCH_DEFAULT="main"
BRANCH=${LOCAL_BRANCH:-$LOCAL_BRANCH_DEFAULT}

function init_checks() {
	# Check required env variables
	if [[ -z "$WPENGINE_SSH_PRIVATE_KEY" ]] || [[ -z "$WPENGINE_SSH_PUBLIC_KEY" ]] || [[ -z "$WPENGINE_ENVIRONMENT_NAME" ]]; then
		missing_secret="WPENGINE_SSH_PRIVATE_KEY and/or WPENGINE_SSH_PUBLIC_KEY and/or WPENGINE_ENVIRONMENT_NAME"
		printf "[\e[0;31mERROR\e[0m] Secret \`$missing_secret\` is missing. Please add it to this action for proper execution.\nRefer https://github.com/colis/action-deploy-to-wpengine for more information.\n"
		exit 1
	fi
}

function setup_ssh_access() {
	printf "[\e[0;34mNOTICE\e[0m] Setting up SSH access to server.\n"

	SSH_PATH="$HOME/.ssh"
	mkdir "$SSH_PATH"
	chmod 700 "$SSH_PATH"

	KNOWN_HOSTS_PATH="$SSH_PATH/known_hosts"
	WPENGINE_SSH_PRIVATE_KEY_PATH="$SSH_PATH/wpengine_key"
	WPENGINE_SSH_PUBLIC_KEY_PATH="$SSH_PATH/wpengine_key.pub"

	setup_private_key
}

function setup_private_key() {
	echo "$WPENGINE_SSH_PRIVATE_KEY" > "$WPENGINE_SSH_PRIVATE_KEY_PATH"
	echo "$WPENGINE_SSH_PUBLIC_KEY" > "$WPENGINE_SSH_PUBLIC_KEY_PATH"

	ssh-keyscan -t "${SSH_KEY_TYPE:-$SSH_KEY_TYPE_DEFAULT}" "$WPENGINE_HOST" >> "$KNOWN_HOSTS_PATH"

	chmod 644 "$KNOWN_HOSTS_PATH"
	chmod 600 "$WPENGINE_SSH_PRIVATE_KEY_PATH"
	chmod 644 "$WPENGINE_SSH_PUBLIC_KEY_PATH"

	git config --global core.sshCommand "ssh -i $WPENGINE_SSH_PRIVATE_KEY_PATH -o UserKnownHostsFile=$KNOWN_HOSTS_PATH"
}

function clone_wpengine_repo() {
	printf "[\e[0;34mNOTICE\e[0m] Cloning WPEngine's repository.\n"

  cd "$GITHUB_WORKSPACE/../.." && \
	git clone --branch main git@$WPENGINE_HOST:$WPENGINE_ENV/$WPENGINE_ENVIRONMENT_NAME.git
}

function cleanup_wpengine_repo() {
	printf "[\e[0;34mNOTICE\e[0m] Cleaning up WPEngine's repository.\n"

	cd "$GITHUB_WORKSPACE/../../$WPENGINE_ENVIRONMENT_NAME" && rm -rf *
}

function copy_local_repo_to_wpengine() {
	printf "[\e[0;34mNOTICE\e[0m] Copying Local repo to WPEngine's repository.\n"

  cp -r "$GITHUB_WORKSPACE/." "$GITHUB_WORKSPACE/../../$WPENGINE_ENVIRONMENT_NAME/"
}

function setup_remote_user() {
	printf "[\e[0;34mNOTICE\e[0m] Setting up remote repository.\n"

  cd "$GITHUB_WORKSPACE/../../$WPENGINE_ENVIRONMENT_NAME" && \
	git config user.name "Automated Deployment" && \
	git config user.email "automation@uship.com"
}

function deploy() {
	printf "[\e[0;34mNOTICE\e[0m] Deploying $BRANCH to $WPENGINE_ENV.\n"

  cd "$GITHUB_WORKSPACE/../../$WPENGINE_ENVIRONMENT_NAME" && \
	git add --all && \
	git commit -m "GitHub Actions Deployment" && \
	git status && \
	git push -u origin main
}

function main() {
	init_checks
	setup_ssh_access
	clone_wpengine_repo
	cleanup_wpengine_repo
	copy_local_repo_to_wpengine
	setup_remote_user
	deploy
}

set -x
main
