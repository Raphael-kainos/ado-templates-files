# Semantic Versioning Calculator
# Calculates next version based on git tags and branch strategy

# ============================================================================
# TEMPORARY DEBUGGING ENABLED - REMOVE AFTER INITIAL AZURE DEVOPS TESTING
# TODO: Remove verbose debugging output once pipeline is validated
# ============================================================================

param(
    [string]$MajorVersion = '1',
    [string]$MinorVersion = '0'
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "=== DEBUGGING: Environment Variables ==="
Write-Host "BUILD_SOURCEBRANCHNAME: $env:BUILD_SOURCEBRANCHNAME"
Write-Host "BUILD_BUILDID: $env:BUILD_BUILDID"
Write-Host "BUILD_SOURCEBRANCH: $env:BUILD_SOURCEBRANCH"
Write-Host "BUILD_REASON: $env:BUILD_REASON"
Write-Host "BUILD_SOURCEVERSION: $env:BUILD_SOURCEVERSION"
Write-Host "SYSTEM_PULLREQUEST_SOURCEBRANCH: $env:SYSTEM_PULLREQUEST_SOURCEBRANCH"

$branch = $env:BUILD_SOURCEBRANCHNAME
$buildNumber = $env:BUILD_BUILDID
$sourceBranch = $env:BUILD_SOURCEBRANCH
$reason = $env:BUILD_REASON

# Safely get commit hash
$commitHash = if ($env:BUILD_SOURCEVERSION -and $env:BUILD_SOURCEVERSION.Length -ge 7) {
    $env:BUILD_SOURCEVERSION.Substring(0, 7)
} else {
    $env:BUILD_SOURCEVERSION
}

Write-Host "##[section]Semantic Version Calculation"
Write-Host "Build Reason: $reason"
Write-Host "Source Branch: $sourceBranch"
Write-Host "Branch Name: $branch"
Write-Host "Commit: $commitHash"

# For Pull Requests, use the source branch
if ($reason -eq "PullRequest") {
    Write-Host "=== Pull Request detected ==="
    $sourceBranch = $env:SYSTEM_PULLREQUEST_SOURCEBRANCH
    $branch = $sourceBranch -replace "refs/heads/", ""
    Write-Host "PR Source Branch: $sourceBranch"
    Write-Host "Modified branch name: $branch"
}

# Ensure we have all tags from remote (optional - won't fail if no remote access)
Write-Host "##[section]Fetching tags from remote..."
Write-Host "Git remote status:"
try {
    $remotes = git remote -v 2>&1
    Write-Host "$remotes"
    git fetch --tags --quiet 2>&1 | Out-Null
    Write-Host "Tags fetched successfully"
    $allTags = git tag -l 2>&1
    Write-Host "Available tags: $allTags"
} catch {
    Write-Host "##[warning]Could not fetch tags from remote (offline mode): $_"
    Write-Host "Continuing with local tags only..."
}

# Get the latest version tag from git
Write-Host "##[section]Getting commit message safely"
$commitMessage = ""
try {
    $commitMessage = git log -1 --pretty=%B 2>$null
    Write-Host "Commit message: $commitMessage"
} catch {
    Write-Host "##[warning]Could not retrieve commit message: $_"
}

Write-Host "##[section]Fetching latest version from git tags..."
$latestTag = git tag -l "v*.*.*" --sort=-v:refname 2>$null | Select-Object -First 1

if ($latestTag) {
    Write-Host "Latest tag found: $latestTag"
    $latestVersion = $latestTag -replace "^v", ""
    $versionParts = $latestVersion -split '\.'
    Write-Host "Version parts: $versionParts"
    
    # Parse version parts safely
    try {
        $currentMajor = [int]$versionParts[0]
        $currentMinor = [int]$versionParts[1]
        $currentPatch = [int]$versionParts[2].Split('-')[0]
        Write-Host "Parsed version - Major: $currentMajor, Minor: $currentMinor, Patch: $currentPatch"
    } catch {
        Write-Host "##[warning]Could not parse version from tag: $latestTag. Error: $_"
        Write-Host "##[warning]Using base version instead."
        $currentMajor = [int]$MajorVersion
        $currentMinor = [int]$MinorVersion
        $currentPatch = 0
    }
} else {
    Write-Host "No existing tags found, starting with base version"
    $currentMajor = [int]$MajorVersion
    $currentMinor = [int]$MinorVersion
    $currentPatch = 0
    Write-Host "Base version - Major: $currentMajor, Minor: $currentMinor, Patch: $currentPatch"
}

Write-Host "Current version: $currentMajor.$currentMinor.$currentPatch"

Write-Host "=== Version Calculation Logic ==="
Write-Host "Source branch for comparison: $sourceBranch"

# Determine version based on branch
if ($sourceBranch -eq "refs/heads/main" -or $sourceBranch -eq "refs/heads/master") {
    Write-Host "Branch matches main/master - detecting merge source"
    
    # Method 1: Try to get source branch from Azure DevOps environment variable
    # This is more reliable than parsing commit messages
    $sourceBranchName = ""
    
    # Check if this is a completed PR merge
    if ($env:SYSTEM_PULLREQUEST_SOURCEBRANCH) {
        $sourceBranchName = $env:SYSTEM_PULLREQUEST_SOURCEBRANCH -replace "refs/heads/", ""
        Write-Host "Source branch from PR: $sourceBranchName"
    }
    else {
        # Method 2: Parse git merge history as fallback
        try {
            # Get the parent branches of the current commit (if it's a merge)
            $parents = git log -1 --pretty=%P 2>$null
            if ($parents -match "\s") {
                # This is a merge commit (has multiple parents)
                $lastMergeCommit = git log --merges -1 --pretty=%s 2>$null
                Write-Host "Last merge commit message: $lastMergeCommit"
                
                # Try to extract branch name from merge commit message
                if ($lastMergeCommit -match "Merge.*'([^']+)'") {
                    $sourceBranchName = $matches[1]
                }
                elseif ($lastMergeCommit -match "Merge.*from [^/]+/([^\s]+)") {
                    $sourceBranchName = $matches[1]
                }
                elseif ($lastMergeCommit -match "Merge branch ([^\s]+)") {
                    $sourceBranchName = $matches[1]
                }
                elseif ($lastMergeCommit -match "Merged PR \d+") {
                    # Azure DevOps PR format - try to get branch from previous commit
                    $prBranch = git log -2 --pretty=%s 2>$null | Select-Object -Last 1
                    Write-Host "Commit before merge: $prBranch"
                }
            }
        } catch {
            Write-Host "##[warning]Could not detect merge from git history: $_"
        }
    }
    
    Write-Host "Detected source branch: $sourceBranchName"
    
    # Determine version bump based on source branch pattern
    if ($sourceBranchName -eq "develop") {
        # Develop merged into main = new feature release (minor bump)
        $major = $currentMajor
        $minor = $currentMinor + 1
        $patch = 0
        Write-Host "##[section]MINOR version bump (develop → main: new features)"
    }
    elseif ($sourceBranchName -like "hotfix/*" -or $sourceBranchName -match "^hotfix[-/]") {
        # Hotfix merged into main = patch release
        $major = $currentMajor
        $minor = $currentMinor
        $patch = $currentPatch + 1
        Write-Host "##[section]PATCH version bump (hotfix → main: bug fix)"
    }
    elseif ($sourceBranchName -like "release/*" -or $sourceBranchName -match "^release[-/]") {
        # Release branch merged - extract version from branch name if possible
        if ($sourceBranchName -match "release[/-]v?(\d+)\.(\d+)\.(\d+)") {
            # Version found in branch name (e.g., release/1.2.0 or release/v1.2.0)
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = [int]$matches[3]
            Write-Host "##[section]VERSION from release branch name: $major.$minor.$patch"
        }
        elseif ($sourceBranchName -match "release[/-]v?(\d+)\.(\d+)") {
            # Partial version in branch name (e.g., release/1.2)
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = 0
            Write-Host "##[section]VERSION from release branch name: $major.$minor.$patch"
        }
        else {
            # No version in branch name - default to minor bump
            $major = $currentMajor
            $minor = $currentMinor + 1
            $patch = 0
            Write-Host "##[section]MINOR version bump (release → main, no version in branch name)"
        }
    }
    elseif ($commitMessage -match "BREAKING CHANGE" -or $commitMessage -match "\[major\]") {
        # Explicit major version bump via commit message
        $major = $currentMajor + 1
        $minor = 0
        $patch = 0
        Write-Host "##[section]MAJOR version bump (BREAKING CHANGE detected)"
    }
    else {
        # Direct commit to main or unknown source = patch bump (safest default)
        $major = $currentMajor
        $minor = $currentMinor
        $patch = $currentPatch + 1
        Write-Host "##[section]PATCH version bump (direct commit or unknown source)"
        if (-not $sourceBranchName) {
            Write-Host "##[warning]Could not determine source branch - using safe patch bump"
        }
    }
    
    $version = "$major.$minor.$patch"
    $preRelease = ""
}
elseif ($sourceBranch -eq "refs/heads/develop") {
    $major = $currentMajor
    $minor = $currentMinor + 1
    $patch = 0
    $version = "$major.$minor.$patch-alpha.$buildNumber"
    $preRelease = "alpha"
}
elseif ($sourceBranch -like "refs/heads/release/*") {
    $releaseVersion = $branch -replace "release/v?", ""
    if ($releaseVersion -match "^\d+\.\d+\.\d+$") {
        $version = "$releaseVersion-rc.$buildNumber"
    } else {
        $major = $currentMajor
        $minor = $currentMinor + 1
        $patch = 0
        $version = "$major.$minor.$patch-rc.$buildNumber"
    }
    $preRelease = "rc"
}
elseif ($sourceBranch -like "refs/heads/hotfix/*") {
    $hotfixVersion = $branch -replace "hotfix/v?", ""
    if ($hotfixVersion -match "^\d+\.\d+\.\d+$") {
        $version = "$hotfixVersion-hotfix.$buildNumber"
    } else {
        $major = $currentMajor
        $minor = $currentMinor
        $patch = $currentPatch + 1
        $version = "$major.$minor.$patch-hotfix.$buildNumber"
    }
    $preRelease = "hotfix"
}
else {
    $major = $currentMajor
    $minor = $currentMinor + 1
    $patch = 0
    $version = "$major.$minor.$patch-dev.$buildNumber"
    $preRelease = "dev"
}

Write-Host "##[section]Calculated Version: $version"
Write-Host "=== Final Version Components ==="
Write-Host "Major: $major"
Write-Host "Minor: $minor"
Write-Host "Patch: $patch"
Write-Host "PreRelease: $preRelease"
Write-Host "Full Version: $version"

# Set output variables
Write-Host "##vso[task.setvariable variable=version;isOutput=true]$version"
Write-Host "##vso[task.setvariable variable=major;isOutput=true]$major"
Write-Host "##vso[task.setvariable variable=minor;isOutput=true]$minor"
Write-Host "##vso[task.setvariable variable=patch;isOutput=true]$patch"

# Update build number
Write-Host "##vso[build.updatebuildnumber]$version"
Write-Host "=== Version calculation complete ==="
