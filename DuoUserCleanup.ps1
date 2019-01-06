###Developed by Peter Nelson
###Stern Security
###www.sternsecurity.com


###This powershell script requires the powershell module developed by Matt Began(mbegan).
###https://github.com/mbegan/Duo-PSModule

###This script does not take nested groups into account and will be ignored.
###Duo does not currently have a way to clear the trash bin using the API.
###If users are going to continue using the applications from a trusted network
###their login will fail if they are not removed from the trash bin in Duo.

###The last_login value in the Duo API is for any login, remote using 2FA or 
###from a trusted network.  This should be taken into account when managing remote access,
###user login activity should still be monitored.  If a user has 2FA access and only
###logs in from trusted networks, this script will not remove them.


###Initialize arrays
$adUsers = @()
$members = @()
$memberList = @()
$skipGroup = @()
$duoCreatedUsers = @()
$nestedGroup = @()

###Initialize variables
$unixtimeCurrent=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime() -UFormat %s)))
$temptimestamp = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($unixtime))
$temptimestampCurrent = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($unixtimeCurrent))
$timeAttrib = $temptimestampCurrent.ToString("MMM dd HH:mm:ss")
$compareTime = $temptimestamp.ToString("MMM dd HH:mm:ss")

###Modify these values for your environment
##########
#Set this to get Duo group members
$adDuoGroup = Get-ADGroup -Filter {name -like "<Duo group>"} -SearchBase "<OU=Duo,OU=Groups,DC=example,DC=com>"

#Remove users after N of days
$staleDate = '-90'

#AD attribute to record Duo last login
$adUserAttribute1 = '<Duo last login attrib>'

#AD attribute to record when user was removed from the group
$adUserAttribute2 = '<Duo stale user attrib>'

#This Value is used in many date time conversions, this is the current unix date/time with $staleDate
$unixtime=[int][double]::Parse(((get-date -date (Get-Date).ToUniversalTime().AddDays($staleDate) -UFormat %s)))

#Log output path
$outputpath = "C:\temp\Duo_User_Cleanup_$unixtimeCurrent.csv"
##########


###Pull users from Duo API
$duoUsers = duoGetUser
#Set the <username> value to pull a single user
#$duoUsers = duoGetUser -username <username>

###Build array of all users and attributes in $adDuoGroup
foreach($item in $adDuoGroup){
    $members = (Get-ADGroup $item -properties members).members
    foreach($item2 in $members){
        $memberList = Get-ADObject -Identity $item2 -Properties SamAccountName,$adUserAttribute1,$adUserAttribute2 | Select-Object SamAccountName,Name,$adUserAttribute1,$adUserAttribute2,ObjectClass
        If($memberList.ObjectClass -eq 'user'){
            If($adUsers.Name -notcontains $memberList.SamAccountName){
                If($memberList.$adUserAttribute1 -eq $null){
                    #Update user last login attribute in AD
                    Set-ADUser $memberList.SamAccountName  -Replace @{$adUserAttribute1="$temptimestampCurrent"}
                    #Clear stale date attribute in AD
                    Set-ADUser $memberList.SamAccountName  -Clear $adUserAttribute2
                    $lineout = $memberList.SamAccountName+", SetDuoLoginDate "+$temptimestampCurrent+", ClearedStaleAttirbute,, User Login Updated"
                    $lineout | Out-File -FilePath $outputpath -Append
                }
                
                #Get Duo last_login value
                $duoLoginAttribute = $null
                $duoLoginAttribute = $duoUsers | Select-Object -Property username,last_login | Where-Object{$_.username -contains $memberList.SamAccountName}

                #If the Duo last_login value is null compare the AD attribute and the current date
                If($duoLoginAttribute.last_login -eq $null){
                    $createdDate = Get-ADUser $memberList.SamAccountName -Properties $adUserAttribute1
                    $timespan = New-TimeSpan -Start $temptimestamp -End $createdDate.$adUserAttribute1
                    If($timespan.Days -LE 0){
                        Set-ADUser $memberList.SamAccountName  -Clear $adUserAttribute1
                        Set-ADUser $memberList.SamAccountName  -Replace @{$adUserAttribute2="$temptimestampCurrent"}
                        Remove-ADGroupMember -Identity $item.SamAccountName -Member $memberList.SamAccountName -Confirm:$false
                        $lineout = $memberList.SamAccountName+", CurrentDate "+$temptimestamp+", ADCreatedDate "+$createdDate.$adUserAttribute1+", NullDuoLoginTimespan "+$timespan.Days+", User Removed From Group"
                        $lineout | Out-File -FilePath $outputpath -Append
                    }
                }
                #Compare the AD value to Duo last_login and remove from group
                Else{
                    $temptimeLastLogin = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($duoLoginAttribute.last_login))
                    $timespan = New-TimeSpan -Start $temptimestamp -End $temptimeLastLogin
                    $createdDate = Get-ADUser $memberList.SamAccountName -Properties $adUserAttribute1
                    If($timespan.Days -LE $staleDate){
                        Set-ADUser $memberList.SamAccountName  -Clear $adUserAttribute1
                        Set-ADUser $memberList.SamAccountName  -Replace @{$adUserAttribute2="$temptimestampCurrent"}
                        Remove-ADGroupMember -Identity $item.SamAccountName -Member $memberList.SamAccountName -Confirm:$false
                        $lineout = $memberList.SamAccountName+", DuoLastLogin "+$temptimeLastLogin+", PreviousLogin "+$createdDate.$adUserAttribute1+", DuoLoginTimespan "+$timespan.Days+", User Removed From Group"
                        $lineout | Out-File -FilePath $outputpath -Append
                    }
                    #Update AD with the Duo last_login value
                    Else{
                        Set-ADUser $memberList.SamAccountName  -Replace @{$adUserAttribute1="$temptimeLastLogin"}
                        $lineout = $memberList.SamAccountName+", DuoLastLogin "+$temptimeLastLogin+", PreviousLogin "+$createdDate.$adUserAttribute1+", DuoLoginTimespan "+$timespan.Days+", AD Last Login Updated"
                        $lineout | Out-File -FilePath $outputpath -Append
                    }
                }
                #Build list of users in AD
                $adUsers += $memberList
            }
        }
        #Populate an array of nested group if any exist
        Else{
            If($nestedGroup.Name -notcontains $memberList.SamAccountName){
                $nestedGroup += $memberList
            }
        }
    }
}

###Compare $duoUsers to $adUsers and produce a list of any not in AD.
###These users were created in Duo and not created by AD sync and will need to be managed manually.
###Output $duoCreatedUsers to file if needed.
#ForEach($dUser in $duoUsers){
#    If($adUsers.Name -notcontains $dUser.username){
#        $duoCreatedUsers += $dUser
#    }
#}
