# duo-usercleanup
Developed by Peter Nelson<br>
Stern Security<br>
www.sternsecurity.com


This powershell script requires the powershell module developed by Matt Began(mbegan).<br>
https://github.com/mbegan/Duo-PSModule

Utilizes the Duo Admin API to remove users from Active Directory that have not logged in within a specified amount of time.  By default, Duo has no way of removing inactive users from the Duo group when "Directory Sync" is enabled.  This script allows you to remove users from the Duo group in Active Directory after a defined number of days of inactivity.

## Considerations:
This script needs to be run from a system and account with access to modify the "Duo" group in Active Directory.

This script does not take nested groups into account and will be ignored.

Duo does not currently have a way to clear the trash bin using the API so you should manually empty the Duo trash bin after this script runs and the directory is sync'd.

If users are going to continue using the protected applications from a trusted network, their login will fail if they are not removed from the trash bin in Duo.  Normally users are automatically removed after seven days.

The last_login value in the Duo API is for any login, remote using 2FA or from a trusted network.  This should be taken into account when managing remote access, user login activity should still be monitored.  If a user has 2FA access and only logs in from trusted networks, this script will not remove them.

## Modify Variables for your environment
### Set the -Filter value to the Duo AD group name and set the -SearchBase Value to the OU AD Path
$adDuoGroup = Get-ADGroup -Filter {name -like "\<Duo group\>"} -SearchBase "<OU=Duo,OU=Groups,DC=example,DC=com>"

### Set this value to remove users after N of days
$staleDate = '-90'

### This Value is used in many date time conversions, this is the current unix date/time with $staleDate
$unixtime=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime().AddDays($staleDate) -UFormat %s)))

### Log output path
$outputpath = "C:\temp\Duo_User_Cleanup_$unixtimeCurrent.csv"
