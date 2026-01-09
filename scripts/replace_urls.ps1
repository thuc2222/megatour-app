# =============================================================================
# Windows PowerShell Script to Replace Hardcoded URLs
# Save as: scripts\replace_urls.ps1
# =============================================================================

Write-Host "🔍 Starting URL replacement..." -ForegroundColor Cyan

# Get all Dart files in lib directory
$files = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"

$replacements = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    # Pattern 1: Basic API URL
    if ($content -match "'https://megatour\.vn/api/'") {
        $content = $content -replace "'https://megatour\.vn/api/'", "'`${ApiConfig.baseUrl}'"
        $modified = $true
        Write-Host "  ✓ Replaced basic URL in: $($file.Name)" -ForegroundColor Green
    }
    
    # Pattern 2: Double quotes API URL
    if ($content -match '"https://megatour\.vn/api/"') {
        $content = $content -replace '"https://megatour\.vn/api/"', '"`${ApiConfig.baseUrl}"'
        $modified = $true
        Write-Host "  ✓ Replaced quoted URL in: $($file.Name)" -ForegroundColor Green
    }
    
    # Pattern 3: WebView URLs
    if ($content -match '"https://megatour\.vn/booking/') {
        $content = $content -replace '"https://megatour\.vn/booking/', '"`${ApiConfig.webBaseUrl}booking/'
        $modified = $true
        Write-Host "  ✓ Replaced WebView URL in: $($file.Name)" -ForegroundColor Green
    }
    
    # Pattern 4: Remove API_BASE_URL declarations
    if ($content -match "String\s+API_BASE_URL\s*=\s*'https://megatour\.vn/api/';") {
        $content = $content -replace "String\s+API_BASE_URL\s*=\s*'https://megatour\.vn/api/';", "// Removed - Use ApiConfig.baseUrl"
        $modified = $true
        Write-Host "  ✓ Removed API_BASE_URL from: $($file.Name)" -ForegroundColor Green
    }
    
    # Pattern 5: const String API_BASE_URL
    if ($content -match "const\s+String\s+API_BASE_URL\s*=\s*'https://megatour\.vn/api/';") {
        $content = $content -replace "const\s+String\s+API_BASE_URL\s*=\s*'https://megatour\.vn/api/';", "// Removed - Use ApiConfig.baseUrl"
        $modified = $true
        Write-Host "  ✓ Removed const API_BASE_URL from: $($file.Name)" -ForegroundColor Green
    }
    
    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $replacements++
    }
}

Write-Host ""
Write-Host "✅ Replacement complete!" -ForegroundColor Green
Write-Host "   Modified $replacements file(s)" -ForegroundColor Yellow

# Verification
Write-Host ""
Write-Host "🔍 Verifying remaining hardcoded URLs..." -ForegroundColor Cyan
$remaining = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | 
    Select-String -Pattern "megatour\.vn" | 
    Where-Object { $_.Line -notmatch "ApiConfig" -and $_.Line -notmatch "//" }

if ($remaining) {
    Write-Host "⚠️  Found remaining hardcoded URLs:" -ForegroundColor Yellow
    $remaining | ForEach-Object {
        Write-Host "   $($_.Filename):$($_.LineNumber) - $($_.Line.Trim())" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ No hardcoded URLs found! All URLs use ApiConfig." -ForegroundColor Green
}

Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review changes with: git diff" -ForegroundColor White
Write-Host "   2. Add imports where needed: import '../../config/api_config.dart';" -ForegroundColor White
Write-Host "   3. Test the app: flutter run" -ForegroundColor White
Write-Host "   4. Commit changes: git add . && git commit -m 'Replace hardcoded URLs with ApiConfig'" -ForegroundColor White