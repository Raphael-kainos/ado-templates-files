# Push Git Tag Script
# Creates and pushes an annotated git tag for the version

# ============================================================================
# TEMPORARY DEBUGGING ENABLED - REMOVE AFTER INITIAL AZURE DEVOPS TESTING
# TODO: Remove verbose debugging output once pipeline is validated
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

# Set error action preference
$ErrorActionPreference = "Stop"

$tagName = "v$Version"

Write-Host "##[section]Creating and pushing git tag: $tagName"
Write-Host "Input version: $Version"
Write-Host "Tag name: $tagName"

try {
    # Configure git
    Write-Host "Configuring git user..."
    git config user.email "azure-pipelines@azuredevops.com"
    git config user.name "Azure Pipelines"
    
    # Check if tag already exists
    Write-Host "Checking for existing tag..."
    $existingTag = git tag -l $tagName 2>$null
    if ($existingTag) {
        Write-Host "##[warning]Tag $tagName already exists. Skipping tag creation."
        Write-Host "Existing tag: $existingTag"
        exit 0
    }
    
    # Create annotated tag
    Write-Host "Creating annotated tag..."
    git tag -a $tagName -m "Release version $Version"
    $createdTag = git tag -l $tagName 2>$null
    Write-Host "Tag created: $createdTag"
    
    # Push tag to origin
    Write-Host "Pushing tag to origin..."
    $pushOutput = git push origin $tagName 2>&1
    Write-Host "Push output: $pushOutput"
    
    Write-Host "##[section]Successfully pushed tag: $tagName to repository"
} catch {
    Write-Host "##[error]Failed to push git tag: $_"
    Write-Host "Error details: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
