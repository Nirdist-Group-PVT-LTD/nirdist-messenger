# How to Verify the People Tab Feature Works

## Prerequisites
- Flutter app installed and running (or accessible in emulator)
- Backend running on Render (https://nirdist-backend-uctd.onrender.com)
- Original account already created and logged in

## Verification Steps

### Phase 1: Verify Backend Endpoint is Live
**Command to run in terminal:**
```powershell
$r = Invoke-WebRequest 'https://nirdist-backend-uctd.onrender.com/api/social/profiles?excludeUserId=1' -UseBasicParsing
$r.StatusCode
$r.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

**Expected Result:**
- Status Code: `200`
- Response: `[]` (empty array, because only 1 user exists) or `[{user1}, {user2}, ...]` if multiple users exist

**If you get 404:** Render deployment is still in progress. Wait 5-10 minutes and try again.

---

### Phase 2: Create Test User (Second Account)

1. **Open Flutter app** (ensure backend is live first)
2. **Log out** of current account (or use different emulator/device)
3. **Select "Don't have an account? Register"**
4. **Enter new phone number:** `+1-555-0002` (different from your first account)
5. **Complete the registration and verification flow**
6. **Note the phone number you used**

---

### Phase 3: Verify People Tab Now Shows Users

1. **Log out** of the test account
2. **Log back in** with your **original account** (first phone number)
3. **Navigate to People tab** (or Discover tab, depending on naming)
4. **Expected result:**
   - Should see the second user you just created
   - User profile shows: name, avatar, status
   - Button shows "Request" (if not friends yet) or "Chat" (if already friends)

---

### Phase 4: Test Search Functionality

1. **In the People tab**, type the second user's name in the search box
2. **Expected result:**
   - Matching user appears in search results
   - Live filtering as you type
   - Can see matching criteria (name, email, phone, username)

---

### Phase 5: Test Friend Request

1. **Click "Request" button** on the second user's profile
2. **Expected result:**
   - Friend request sent successfully
   - Button changes to "Pending" or similar status
   - No errors in console

---

## Troubleshooting

### "Still showing empty People tab after creating second user"

**Check 1: Verify backend endpoint returns users**
```powershell
$r = Invoke-WebRequest 'https://nirdist-backend-uctd.onrender.com/api/social/profiles?excludeUserId=1' -UseBasicParsing
$r.Content
# Should show JSON array with multiple user objects, not empty array
```

**Check 2: Restart the app**
- Close app completely
- Reopen and log in again
- Navigate to People tab

**Check 3: Verify logged-in user ID**
- Check app settings/profile page to confirm your user ID
- If not ID=1, adjust the excludeUserId parameter in the test command above

**Check 4: Check app logs for errors**
- In VS Code, look at Flutter debug console
- Search for "profiles" or "error" in logs
- Look for network request errors

---

## Testing Search Endpoint Directly

If you want to test the search endpoint:

```powershell
# Search for users with "0002" in any field
$r = Invoke-WebRequest 'https://nirdist-backend-uctd.onrender.com/api/social/profiles/search?q=0002&excludeUserId=1' -UseBasicParsing
$r.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

**Expected:** Returns profiles matching the search query

---

## Success Criteria

Feature is working correctly when:
- ✅ Backend endpoint `/api/social/profiles` returns 200
- ✅ Multiple users appear in response when 2+ profiles exist
- ✅ People tab in app shows other users (not empty)
- ✅ Search functionality filters users in real-time
- ✅ Can send friend requests to other users
- ✅ No 404 or 500 errors in network requests

---

## Timeline Estimate

- Render deployment: **5-10 minutes**
- Register test account: **2-3 minutes**
- Verify feature: **5 minutes**
- **Total: 12-18 minutes**

---

## Key Code Locations for Reference

**If you need to debug, check these files:**

Backend:
- [back-end/src/main/java/com/nirdist/controller/SocialController.java](../back-end/src/main/java/com/nirdist/controller/SocialController.java) (lines 69-77)
- [back-end/src/main/java/com/nirdist/service/SocialGraphService.java](../back-end/src/main/java/com/nirdist/service/SocialGraphService.java) (lines 225-256)

Frontend:
- [front-end/app/messenger/lib/screens/messenger_shell.dart](../front-end/app/messenger/lib/screens/messenger_shell.dart) (People tab implementation)
- [front-end/app/messenger/lib/services/messenger_api_client.dart](../front-end/app/messenger/lib/services/messenger_api_client.dart) (API client methods)

Tests:
- [front-end/app/messenger/test/widget_test.dart](../front-end/app/messenger/test/widget_test.dart) (All 5 tests passing)
