# Dont-Hit-Stuff.ps1
#
# A tiny humorous PowerShell script based on the long-circulating
# "going to hit stuff / don't" programming meme.
#
# AI tools may have assisted with review, documentation, or refinement.

Write-Host "Evaluating: GoingToHitStuff..."
$GoingToHitStuff = Get-Random -Minimum 0 -Maximum 2
Write-Host "GoingToHitStuff = $GoingToHitStuff"

function Dont {
    Write-Host "Dont"
}

if ($GoingToHitStuff -eq 1) {
    Write-Host "Condition met. Executing Dont."
    Dont
}
else {
    Write-Host "Condition not met. Doing nothing."
}
