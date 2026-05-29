# SwiftCall Test Scripts

## Add Tokens to User

### Method 1: Python Script (Recommended)

**Prerequisites:**
```bash
pip install firebase-admin
```

**Setup:**
1. Download service account key from Firebase Console:
   - Go to Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json`

2. Update script:
   ```python
   cred = credentials.Certificate('path/to/serviceAccountKey.json')
   ```

**Usage:**
```bash
python scripts/add_tokens.py USER_UID AMOUNT

# Example: Add 500 tokens to user abc123
python scripts/add_tokens.py abc123xyz 500
```

---

### Method 2: Firebase CLI (Firestore Rules must allow)

**Prerequisites:**
```bash
npm install -g firebase-tools
firebase login
```

**Direct Firestore Write:**
```bash
# Get your user UID first (from Firebase Console or app)
export UID="YOUR_USER_UID_HERE"

# Add 500 tokens
firebase firestore:set \
  --project swiftcall-eec90 \
  token_wallets/$UID \
  '{"uid":"'$UID'","balance":500,"totalEarned":500,"totalSpent":0}' \
  --merge

# Add transaction record
firebase firestore:add \
  --project swiftcall-eec90 \
  token_wallets/$UID/transactions \
  '{"amount":500,"type":"admin_credit","description":"Test tokens","createdAt":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

**Windows PowerShell:**
```powershell
$UID = "YOUR_USER_UID_HERE"

# Add tokens
firebase firestore:set `
  --project swiftcall-eec90 `
  token_wallets/$UID `
  "{`"uid`":`"$UID`",`"balance`":500,`"totalEarned`":500,`"totalSpent`":0}" `
  --merge
```

---

### Method 3: Admin Panel (In-App)

1. Add your UID to `admins` collection in Firestore:
   ```bash
   firebase firestore:set \
     --project swiftcall-eec90 \
     admins/YOUR_UID \
     '{"role":"admin","createdAt":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
   ```

2. Open app → Settings → Admin Panel (icon appears if you're admin)

3. Use "Credit Tokens" feature to add tokens to any user

---

## Testing Group Calls

### Requirements
- At least 2 users (you + 1 friend)
- Both users must be **friends** (accepted friend request)
- Minimum 15 tokens per minute (GroupCallPerMinute cost)

### How to Start Group Call:
1. Home Screen → Contacts tab
2. Select 1+ friends (checkboxes appear)
3. Tap floating action button (FAB) at bottom
4. Toggle Video/Audio at top-right
5. Tap "بدء المكالمة" (Start Call)

### What Happens:
```
1. GroupCallBloc.GroupCallCreate dispatched
2. Creates Firestore document: group_calls/{id}
   - participants: [creator, invitee1, invitee2, ...]
   - status: "active"
   - isVideo: true/false

3. Generates LiveKit room token via backend
4. Connects to LiveKit room
5. Sends FCM notification to all invitees

6. On call end:
   - Calculates duration (elapsed)
   - Charges tokens: duration_minutes * 15 tokens
   - Updates Firestore: status = "ended", duration = X
```

### Token Charging Formula:
```dart
// group_call_bloc.dart
final minutes = (elapsed.inSeconds / 60).ceil();
final cost = minutes * TokenCosts.groupCallPerMinute;  // 15/min
await TokenService.instance.spendTokens(uid, cost, 'مكالمة جماعية');
```

---

## Token Costs Reference

| Action | Cost (tokens) |
|--------|---------------|
| Text message | 1 |
| Location share | 2 |
| Image upload | 3 |
| Audio upload | 3 |
| File upload | 5 |
| Video upload | 8 |
| Voice call | 5/minute |
| Video call | 10/minute |
| **Group call** | **15/minute** |

**Rewards:**
- Welcome bonus: 500 tokens
- Watch ad: 50 tokens
- Share app: 30 tokens

---

## How Token Spending Works

### 1. Message Sending (chat_bloc.dart)
```dart
// Before sending message
await TokenService.instance.spendTokens(uid, cost, description);

// If balance < cost → returns false → ChatError emitted
```

### 2. Call Charging (call_bloc.dart)
```dart
// After call ends
final elapsed = _elapsed;  // Duration tracked during call
final minutes = (elapsed.inSeconds / 60).ceil();
final cost = minutes * (isVideo ? 10 : 5);

await TokenService.instance.spendTokens(uid, cost, 'مكالمة');
```

### 3. Group Call Charging (group_call_bloc.dart)
```dart
// Only CREATOR pays
if (_isCreator) {
  final minutes = (elapsed.inSeconds / 60).ceil();
  final cost = minutes * 15;
  await TokenService.instance.spendTokens(uid, cost, 'مكالمة جماعية');
}
```

### spendTokens Implementation:
```dart
// token_service.dart
Future<bool> spendTokens(String uid, int amount, String description) {
  return _db.runTransaction((tx) async {
    final snap = await tx.get(walletRef);
    if (!snap.exists) return false;
    
    final wallet = TokenWallet.fromMap(snap.data());
    if (wallet.balance < amount) return false;  // Insufficient
    
    // Deduct balance
    tx.set(walletRef, {
      'balance': FieldValue.increment(-amount),
      'totalSpent': FieldValue.increment(amount),
    }, SetOptions(merge: true));
    
    // Record transaction
    tx.set(transactionRef, {
      'amount': -amount,
      'type': 'spend',
      'description': description,
      'createdAt': DateTime.now(),
    });
    
    return true;
  });
}
```

**Transaction ensures:**
- Balance check + deduction happen atomically
- No race condition (2 calls can't both succeed if balance = 10 and each costs 10)
- Transaction history is always recorded

---

## Quick Commands

**Check user's current balance:**
```bash
firebase firestore:get token_wallets/YOUR_UID --project swiftcall-eec90
```

**List all transactions:**
```bash
firebase firestore:get token_wallets/YOUR_UID/transactions --project swiftcall-eec90
```

**Reset wallet (testing):**
```bash
firebase firestore:set token_wallets/YOUR_UID '{"uid":"YOUR_UID","balance":1000,"totalEarned":1000,"totalSpent":0}' --project swiftcall-eec90
```
