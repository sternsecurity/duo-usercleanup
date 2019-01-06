# duo-usercleanup
Developed by Peter Nelson
Stern Security
www.sternsecurity.com


This powershell script requires the powershell module developed by Matt Began(mbegan).
https://github.com/mbegan/Duo-PSModule

Utilizes the Duo Admin API to remove users that have not logged in within a specified amount of time.

## Considerations:

This script does not take nested groups into account and will be ignored.

Duo does not currently have a way to clear the trash bin using the API.

If users are going to continue using the applications from a trusted network their login will fail if they are not removed from the trash bin in Duo.  Normally users are automatically removed after seven days.

The last_login value in the Duo API is for any login, remote using 2FA or from a trusted network.  This should be taken into account when managing remote access, user login activity should still be monitored.  If a user has 2FA access and only logs in from trusted networks, this script will not remove them.

## Modify Variables for your environment
### Set the -Filter value to the Duo AD group name and set the -SearchBase Value to the UO AD Path
$adDuoGroup = Get-ADGroup -Filter {name -like "\<Duo group\>"} -SearchBase "<OU=Duo,OU=Groups,DC=example,DC=com>"

### Set this value to remove users after N of days
$staleDate = '-90'

### Set this AD attribute to record Duo last login
$adUserAttribute1 = '\<Duo last login attrib\>'

### Set this AD attribute to record when user was removed from the group
$adUserAttribute2 = '\<Duo stale user attrib\>'

### This Value is used in many date time conversions, this is the current unix date/time with $staleDate
$unixtime=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime().AddDays($staleDate) -UFormat %s)))

### Log output path
$outputpath = "C:\temp\Duo_User_Cleanup_$unixtimeCurrent.csv"
