<#
Developed by Peter Nelson
Stern Security
www.sternsecurity.com


This powershell script requires the powershell module developed by Matt Began(mbegan).
https://github.com/mbegan/Duo-PSModule

This script does not take nested AD groups into account and will be ignored.
Duo does not currently have a way to clear the trash bin using the API.
If users are going to continue using the applications from a trusted network
their login will fail if they are not removed from the trash bin in Duo.

The last_login value in the Duo API is for any login, remote using 2FA or 
from a trusted network.  This should be taken into account when managing remote access,
user login activity should still be monitored.  If a user has 2FA access and only
logs in from trusted networks, this script will not remove them.
#>

#User Custom Variables- Change to fit needs
$staleDate = '-90'
$adDuoGroup = Get-ADGroup -Filter {name -like "Duo"} -SearchBase "OU=Duo,OU=Applications,OU=Groups,DC=domain_name,DC=org"

##########
#Time Variables
$unixStaletime=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime().AddDays($staleDate) -UFormat %s)))
$dateStaletime = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($unixStaletime))
$unixCurrenttime=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime() -UFormat %s)))
##########

#Log Output- Change to fit needs
$outputpath = "C:\temp\Duo_User_Cleanup_$unixCurrenttime.csv"
$lineout = "Username,Stale_Days,Stale_Date,LastLogin_Created,Change"
#Write column header to log file
$lineout | Out-File -FilePath $outputpath


#Pull users from Duo
$duoUsers = duoGetUser

#Create a list of users from Duo that have been synced from AD
$adUsers = $duoUsers | Select-Object -Property username,status,last_login,last_directory_sync,created | Where-Object{($_.status -ne "pending deletion") -and ($_.last_directory_sync -ne $null)}

$noLogin = $null
$count = 0

<#
Loop the AD synced users
If Duo last login is null, compare the stale time variable with the Duo created date
If the difference is less than or equal to -1, remove the user from the AD group
Append CSV output line to log file
#>
foreach($item in $adUsers){
    If($item.last_login -eq $null){
        $createdDate = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($item.created))
        $timespan = New-TimeSpan -Start $dateStaletime -End $createdDate
        If($timespan -le -1.0){
            $adDetails = Get-ADUser -Identity $item.username -Properties SamAccountName
            Remove-ADGroupMember -Identity $adDuoGroup.SamAccountName -Member $adDetails.SamAccountName -Confirm:$false
            #Debug Output
            <#
            Write-Host $item.username
            Write-Host $timespan
            Write-Host $item.status
            Write-Host "Created: "$createdDate
            Write-Host "Stale: "$dateStaletime
            #>
            $count = $count + 1
            $lineout = $item.username+","+$timespan+","+$dateStaletime+","+$createdDate+",User Removed From Group"
            $lineout | Out-File -FilePath $outputpath -Append
        }
    }
    <#
    Compare the stale time variable with the Duo last login date
	If the difference is less than or equal to -1, remove the user from the AD group
	Append CSV output line to log file
    #>
    Else{
        $loginDate = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($item.last_login))
        $timespan = New-TimeSpan -Start $dateStaletime -End $loginDate
        If($timespan -le -1.0){
            $adDetails = Get-ADUser -Identity $item.username -Properties SamAccountName
            Remove-ADGroupMember -Identity $adDuoGroup.SamAccountName -Member $adDetails.SamAccountName -Confirm:$false
            #Debug Output
            <#
            Write-Host $item.username
            Write-Host $timespan
            Write-Host $item.status
            Write-Host "Last Login: "$loginDate
            Write-Host "Stale: "$dateStaletime
            #>
            $count = $count + 1
            $lineout = $item.username+","+$timespan+","+$dateStaletime+","+$loginDate+",User Removed From Group"
            $lineout | Out-File -FilePath $outputpath -Append
        }
    }
}
Write-Host $count
