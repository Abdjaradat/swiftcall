#!/bin/bash
# Migration script using Firebase CLI
# This adds contacts/incomingRequests/outgoingRequests fields to all users

echo "Migrating friend request fields for all users..."

# Get all user UIDs
firebase firestore:get users --project swiftcall-eec90 --format=json | \
  jq -r '.[].name' | \
  sed 's|users/||' | \
  while read -r uid; do
    echo "Updating user: $uid"
    firebase firestore:update users/$uid \
      --project swiftcall-eec90 \
      '{"contacts":[],"incomingRequests":[],"outgoingRequests":[]}' \
      --merge || true
  done

echo "Migration complete!"
