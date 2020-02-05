# Ensure you have the module installed FIRST!!!
# https://www.powershellgallery.com/packages/MicrosoftTeams/1.0.3

# Single value parameters
$teamName = "My Team Name" # Also considered the Display Name
$teamDescription = "Contoso is a fictional company used by Microsoft as an example company and domain." # Leave blank if you don't care
$teamVisibility = "Private" # Public or Private
$teamOwnerOverride = "" # This will default to your Microsoft email if not specified. If you wish to create a team for someone else, specify their Microsoft alias email. Example: togorr@microsoft.com or dawinega@microsoft.com
$numOfTeams = 1 # Team 01...10...99

# Array value parameters
# Example of lists: "email", "email", "email"
$admins = "alias1@microsoft.com", "alias2@microsoft.com"
$coaches = "alias13@microsoft.com", "alias14@microsoft.com"


#####################################
###  DO NOT CHANGE BELOW HERE!!!  ###
#####################################


# Connect to teams with your account
try {
    Connect-MicrosoftTeams
}
catch {
    Write-Error $_.Exception.InnerException
    exit 0
}

Write-Output "Checking to see if the team owner was overriden..."

# Determing THE team owner
$teamOwner = if($teamOwnerOverride -ne "") { $teamOwnerOverride } else { "$($env:USERNAME)@microsoft.com" }

Write-Output "Team owner: $($teamOwner)"

Write-Output "Checking if the team exists..."

try {
    # Get the group, if it already exists
    $group = Get-Team -DisplayName $teamName -Visibility $teamVisibility -User $teamOwner
}
catch {
    Write-Error $_.Exception.InnerException
    exit 0
}

# If the object has a value, the team already exists
if ($group) {
    # Show all the information for the group
    Write-Output "Team Id: $($group.GroupId)"
    Write-Output ""

    $continue = Read-Host "The team [$($teamName)] already exists. Do wish to continue editing the current team? (Y or N)"

    # Do not continue if they responded NO
    if ($continue.ToLower() -ne "y") {
        Write-Output "Exiting the script..."
        exit 1
    }
}
else {
    # Creating the team
    Write-Output "Creating the team..."

    try {
       $group = New-Team -DisplayName $teamName -Description $teamDescription -Visibility $teamVisibility -Owner $teamOwner

       # There was a known bug where you have to also add the Team Owner as an Owner...don't ask me why
       Add-TeamUser -GroupId $group.GroupId -User $teamOwner -Role Owner
    }
    catch {
        Write-Error $_.Exception.InnerException
        exit 0
    }
    
    Write-Output "New TeamId: $($group.GroupId)"
}

# Cleaning up the admins
Write-Output "Removing owners, that are NOT the team owner, in case of changes"

foreach($owner in Get-TeamUser -GroupId $group.GroupId -Role Owner) {
    # Do not remove the Owner of the channel as an owner
    if($teamOwner.ToLower() -ne $owner.User) {
        Write-Output "Removing owner [$($owner.User)]..."

        try {
            Remove-TeamUser -GroupId $group.GroupId -User $owner.User -Role Owner
        }
        catch {
            Write-Error $_.Exception.InnerException
            exit 0
        }
    }
}

# Adding in admins
foreach($admin in $admins) {
    Write-Output "Adding the admin [$($admin)]..."

    try {
        Add-TeamUser -GroupId $group.GroupId -User $admin -Role Owner
    }
    catch {
        # this is thrown when they already exist
    }
}

# Cleaning up the coaches
Write-Output "Removing coaches, in case of changes"

foreach($coach in Get-TeamUser -GroupId $group.GroupId -Role Member) {
    Write-Output "Removing coach [$($coach.User)]..."

    try {
        Remove-TeamUser -GroupId $group.GroupId -User $coach.User
    }
    catch {
        Write-Error $_.Exception.InnerException
        exit 0
    }
}

# Add coaches
foreach($coach in $coaches) {
    Write-Output "Adding the coach [$($coach)]..."

    try {
        Add-TeamUser -GroupId $group.GroupId -User $coach -Role Member
    }
    catch {
        Write-Error $_.Exception.InnerException
        exit 0
    }
}

# Get all channels so we don't have to wait FOREVER!
$channels = Get-TeamChannel -GroupId $group.GroupId

Write-Output "Current # of channels: $($channels.Count)"

# Add channels
for($x=1; $x -le $numOfTeams; $x++) {
    $tNum = "{0:00}" -f $x
    $displayName = "Team $tNum"
    $channelExists = $false

    Write-Output "Checking existence of channel [$($displayName)]..."

    try {
        # Loop through any channels that exist, to ensure we don't try to create it again
        foreach($channel in $channels) {
            if($channel.DisplayName -eq $displayName) { 
                Write-Output "Team [$($displayName)] found..."
                $channelExists = $true 
            }
        }

        if(!$channelExists) {
            Write-Output "Creating channel $($displayName)"

            New-TeamChannel -GroupId $group.GroupId -DisplayName $displayName
        }
    }
    catch {
        Write-Error $_.Exception.InnerException
        exit 0
    }
}