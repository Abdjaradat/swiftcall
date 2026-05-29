#!/usr/bin/env python3
"""
Test script to add tokens to a user in Firestore
Usage: python add_tokens.py <user_uid> <amount>
"""

import sys
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

def add_tokens(uid: str, amount: int):
    """Add tokens to a user's wallet in Firestore"""

    # Initialize Firebase Admin SDK
    # Replace with your service account key path
    cred = credentials.Certificate('path/to/serviceAccountKey.json')

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    # Reference to wallet document
    wallet_ref = db.collection('token_wallets').document(uid)
    transaction_ref = wallet_ref.collection('transactions').document()

    # Run transaction to ensure atomicity
    @firestore.transactional
    def update_in_transaction(transaction):
        # Get current wallet
        wallet_snap = wallet_ref.get(transaction=transaction)

        if not wallet_snap.exists:
            # Create new wallet
            transaction.set(wallet_ref, {
                'uid': uid,
                'balance': amount,
                'totalEarned': amount,
                'totalSpent': 0,
            })
            print(f'Created new wallet with {amount} tokens')
        else:
            # Update existing wallet
            transaction.update(wallet_ref, {
                'balance': firestore.Increment(amount),
                'totalEarned': firestore.Increment(amount),
            })
            current = wallet_snap.get('balance')
            print(f'Updated wallet: {current} → {current + amount} tokens')

        # Add transaction record
        transaction.set(transaction_ref, {
            'amount': amount,
            'type': 'admin_credit',
            'description': f'Test credit: {amount} tokens',
            'createdAt': datetime.now(),
        })

    # Execute transaction
    transaction = db.transaction()
    update_in_transaction(transaction)

    print(f'✓ Added {amount} tokens to user {uid}')
    return True


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python add_tokens.py <user_uid> <amount>')
        print('Example: python add_tokens.py abc123xyz 500')
        sys.exit(1)

    user_uid = sys.argv[1]
    token_amount = int(sys.argv[2])

    add_tokens(user_uid, token_amount)
