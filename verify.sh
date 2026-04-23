#!/bin/bash
# VERIFICATION SCRIPT - Run this to verify the People Tab feature is ready

echo "=========================================="
echo "PEOPLE TAB FEATURE - LOCAL VERIFICATION"
echo "=========================================="
echo ""

# Check 1: DataInitializer exists
echo "[1/5] Checking DataInitializer.java exists..."
if [ -f "back-end/src/main/java/com/nirdist/init/DataInitializer.java" ]; then
    echo "✓ DataInitializer.java found"
else
    echo "✗ DataInitializer.java NOT found"
    exit 1
fi

# Check 2: Backend compiles
echo "[2/5] Compiling backend..."
cd back-end
mvn clean compile -q
if [ $? -eq 0 ]; then
    echo "✓ Backend compiles successfully"
    cd ..
else
    echo "✗ Backend compilation failed"
    cd ..
    exit 1
fi

# Check 3: Tests pass
echo "[3/5] Running Flutter tests..."
cd ../front-end/app/messenger
flutter test --no-pub 2>/dev/null | grep -q "5 passed"
if [ $? -eq 0 ]; then
    echo "✓ All 5 widget tests pass"
    cd ../../..
else
    echo "✗ Tests failed"
    cd ../../..
    exit 1
fi

# Check 4: Key endpoints exist
echo "[4/5] Verifying backend endpoints..."
grep -q "@GetMapping(\"/profiles\")" back-end/src/main/java/com/nirdist/controller/SocialController.java
if [ $? -eq 0 ]; then
    echo "✓ Backend endpoints verified"
else
    echo "✗ Backend endpoints not found"
    exit 1
fi

# Check 5: Frontend integration exists
echo "[5/5] Verifying frontend integration..."
grep -q "listProfiles" front-end/app/messenger/lib/screens/messenger_shell.dart
if [ $? -eq 0 ]; then
    echo "✓ Frontend integration verified"
else
    echo "✗ Frontend integration not found"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ ALL CHECKS PASSED"
echo "=========================================="
echo ""
echo "Feature is ready for deployment:"
echo "1. git pull origin main"
echo "2. Redeploy backend on Render"
echo "3. Open People tab to see test users"
echo ""
