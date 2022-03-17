#!/bin/bash

set -eu -o pipefail

# Will force failure if not provided
echo "Building ${CONTAINER}…"
echo "Using repository ${REPOSITORY}"

# Ensure this variable exists (but may be empty).
# If empty, tags will not be pushed to ECR or Git (to allow for testing).
PUSH_TAGS=${PUSH_TAGS:=''}

# Get the latest build tag pointing at the current commit.
# Need to use \K for lookbehind (discards the match up to that point for the -o capture).
# || true to unconditionally succeed; this way we can check and log a message next.
CONTAINER_TAG=$(git tag --points-at | grep -Po "^$CONTAINER/\Kbuild-\d+.+$" | sort -Vr | head -n 1 || true)

[[ -z "$CONTAINER_TAG" ]] && { echo 'Did not find any build tag pointing at HEAD'; exit 1; }
echo "Got CONTAINER_TAG=$CONTAINER_TAG"

# Now compute the version tags
VERSION=$1

MAJVER=$(grep -Po '^.+?(?=\..+)' <<< "$VERSION") \
  || (echo "Could not parse major version from $VERSION" && exit 1)
MINVER=$(grep -Po '^.+?\..+?(?=\..+)' <<< "$VERSION") \
  || (echo "Could not parse minor version from $VERSION" && exit 1)

# Tag both the image and the commit with the semantic version.
# We apply the Git tag _first_ to fail fast if it already exists.
echo "Tagging $REPOSITORY/$CONTAINER:$CONTAINER_TAG as $CONTAINER:$TAG"

([[ -z "$PUSH_TAGS" ]] && echo 'Skipping (no $PUSH_TAGS)') \
  || ( \
    git tag "$CONTAINER/$VERSION" \
    && git push --tags \
    && docker tag "$REPOSITORY/$CONTAINER:$CONTAINER_TAG" "$REPOSITORY/$CONTAINER:$VERSION" \
    && docker push "$REPOSITORY/$CONTAINER:$VERSION"
  )

# Tag only the image with minor/major versions (they are not stable and thus unsuitable for Git).
for TAG in \
  "$MINVER" \
  "$MAJVER" ;
do
  echo "Tagging $REPOSITORY/$CONTAINER:$CONTAINER_TAG as $CONTAINER:$TAG"

  ([[ -z "$PUSH_TAGS" ]] && echo 'Skipping (no $PUSH_TAGS)') \
    || ( \
      docker tag "$REPOSITORY/$CONTAINER:$CONTAINER_TAG" "$REPOSITORY/$CONTAINER:$TAG" \
      && docker push "$REPOSITORY/$CONTAINER:$TAG"
    )
done

# If a second argument was given, treat it as a single string of space-separated additional tags.
# Tag only the image with these (we assume they are not stable and thus unsuitable for Git).
for TAG in $(echo "${2:-}") ; do
  echo "Tagging $REPOSITORY/$CONTAINER:$CONTAINER_TAG as $CONTAINER:$TAG"

  ([[ -z "$PUSH_TAGS" ]] && echo 'Skipping (no $PUSH_TAGS)') \
    || ( \
      docker tag "$REPOSITORY/$CONTAINER:$CONTAINER_TAG" "$REPOSITORY/$CONTAINER:$TAG" \
      && docker push "$REPOSITORY/$CONTAINER:$TAG"
    )
done