###################################################################################################################
#   
#   Title       :   Shared Mailbox Creation Tool.
#   Version     :   1.6
#   Author      :   Alexandros Pantazopoulos
#   
#   Description :   Creates a shared mailbox with proper attributes.
#   
#   Revision    
#   History     :   V1.0    -   Initial Release.
#               :   V1.1    -   Added notes changer and Owner.
#               :   V1.2    -   Added description changer.
#               :   V1.3    -   Added radio boxes to window.
#               :   V1.4    -   Updating variable naming.
#               :   V1.5    -   Added secondary owner
#               :   V1.6    -   Radio Boxes usable.
#               :   V1.7    -   Streamline path-files.
#               :   V1.8(WIP)-  Refactor XAML code.
#   
###################################################################################################################

# XAML module add-in.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Xaml

# GLOBALS
$UPNPattern  = '^[\w\.\-]+@xx\.org\.uk$'
$InfoPattern = '^\d{6}$'

<#================================================ FilePath setup ================================================#>

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ParentDir = Split-Path -Parent $ScriptDir

$LogFolder   = Join-Path $ParentDir "Logs"
$XAMLFolder  = Join-Path $ParentDir "XAML"
$AssetFolder = Join-Path $ParentDir "Assets"

$xamlPath  = Join-Path $XamlFolder "SharedMailboxGUI.xaml"
$IconPath  = Join-Path $AssetFolder "xx.ico" 



if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
$LogFile = Join-Path $LogFolder "MailboxCreationLog.txt"

function Write-Log {
    param([string]$Message)
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$Timestamp - $Message"
}
<#===============================================================================================================#>


<#===                                              = LOAD XAML =                                              ===#>

# Read XAML file.
[xml]$XAML = Get-Content $xamlPath
$reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($reader)
$Window.Icon = $IconPath


# Capture Info controls.
$TextMailboxName               = $Window.FindName("TextMailboxName")
$TextMailboxAddress            = $Window.FindName("TextMailboxAddress")
$TextPrimaryOwner              = $Window.FindName("TextPrimaryOwner")
$TextSecondaryOwner            = $Window.FindName("TextSecondaryOwner")
$TextInfo                      = $Window.FindName("TextInfo")
$RadioActiveType               = $Window.FindName("ActiveType")
$RadioDynamicsCRM              = $Window.FindName("DynamicsCRMType")
$RadioSystemType               = $Window.FindName("SystemType")

# Button and Status.
$ButtonCreate                  = $Window.FindName("ButtonCreate")
$LabelStatus                   = $Window.FindName("LabelStatus")
<#===============================================================================================================#>

# Button Click Event.
$ButtonCreate.Add_Click({
    $MailboxName        = $TextMailboxName.Text.Trim()
    $MailboxAddress     = $TextMailboxAddress.Text.Trim()
    $PrimaryOwnerUPN    = $TextPrimaryOwner.Text.Trim()
    $SecondaryOwnerUPN  = $TextSecondaryOwner.Text.Trim()
    $Info               = $TextInfo.Text.Trim()
   
    if ($RadioActiveType.IsChecked) {
        $OU          = "OU=Active,OU=Shared Mailboxes,DC=internal,DC=xx,DC=org,DC=uk"
        $MailboxType = "Shared Mailbox"
    }
    elseif ($RadioDynamicsCRM.IsChecked) {
        $OU          = "OU=Dynamics CRM,OU=Shared Mailboxes,DC=internal,DC=xx,DC=org,DC=uk"
        $MailboxType = "Dynamics CRM Mailbox"
    }
    elseif ($RadioSystemType.IsChecked) {
        $OU          = "OU=System Mailboxes,OU=Shared Mailboxes,DC=internal,DC=xx,DC=org,DC=uk"
        $MailboxType = "System Mailbox"
    }


    <#                                              Basic Validation                                             #>
    
    # Checking if all fields are filled.
    if (!$MailboxName -or !$MailboxAddress -or !$PrimaryOwnerUPN -or !$SecondaryOwnerUPN -or !$Info) {
        [System.Windows.MessageBox]::Show("Please fill in all fields.", "Validation Error")
        Write-Log "Validation failed: Missing fields."
        return
    }

    # Checking UPN format.
    if ($MailboxAddress -notmatch $UPNPattern) {
        [System.Windows.MessageBox]::Show("Email must match format: name@domain.com", "Invalid Format")
        Write-Log "Invalid Mailbox Address format: $MailboxAddress"
        return
    }
    
    # Checking SD+ Ticket format.
    if ($Info -notmatch $InfoPattern) {
        [System.Windows.MessageBox]::Show("SD+ Ticket must match format: XXXXXX.")
        Write-Log "Invalid SD+ format: $Info"
        return
    }
    
    # Checks Owners Exist in AD.
    try {
        $PrimaryOwnerObject   = Get-ADUser -Filter "UserPrincipalName -eq '$PrimaryOwnerUPN'" -ErrorAction Stop
        $SecondaryOwnerObject = Get-ADUser -Filter "UserPrincipalName -eq '$SecondaryOwnerUPN'" -ErrorAction Stop
    }
    catch {
        $PrimaryOwnerObject   = $null
        $SecondaryOwnerObject = $null
    }
    
    if (-not $PrimaryOwnerObject) {
        [System.Windows.MessageBox]::Show(
            "Primary Owner '$PrimaryOwnerUPN' does not exist in Active Directory. Please enter a valid UPN.",
            "Invalid Owner",
            "OK",
            "Error"
        )
        Write-Log "Invalid owner UPN: $PrimaryOwnerUPN"
        return
    }
    
    if (-not $SecondaryOwnerObject) {
        [System.Windows.MessageBox]::Show(
            "Secondary Owner '$SecondaryOwnerUPN' does not exist in Active Directory. Please enter a valid UPN.",
            "Invalid Owner",
            "OK",
            "Error"
        )
        Write-Log "Invalid owner UPN: $SecondaryOwnerUPN"
        return
    }
    
    if ( $PrimaryOwnerUPN -eq $SecondaryOwnerUPN) {
        [System.Windows.MessageBox]::Show(
            "Please enter two unique UPNs.",
            "Duplicate Owners",
            "OK",
            "Error"
        )
        Write-Log "Invalid owner UPN: $SecondaryOwnerUPN"
        return
    }    
    ##### Should probably add a check that people don't use the same UPN twice.
    
    # Mailbox duplicate in AD check
    try {
        $ADCheck = Get-ADUser -Filter "UserPrincipalName -eq '$MailboxAddress'" -ErrorAction SilentlyContinue
    } catch {
        $ADCheck = $null
        Write-Log "Error checking AD for duplicate UPN $MailboxAddress : $($_.Exception.Message)"
    }

    if ($ADCheck) {
        [System.Windows.MessageBox]::Show(
            "A mailbox already exists with this email:`n$MailboxAddress`n`nMailbox will not be created.",
            "Duplicate Found",
            "OK",
            "Error"
        )
        Write-Log "Duplicate detected in AD for UPN $MailboxAddress. Mailbox creation aborted."
        return
    }
    #####
    
    <#===========================================================================================================#>
    
    # Confirmation dialog.
    $Confirm = [System.Windows.MessageBox]::Show(
        "Create the following mailbox?`n`nMailbox Name: $MailboxName`nEmail: $MailboxAddress`n" +
        "Primary Owner: $PrimaryOwnerUPN`nSecondary Owner: $SecondaryOwnerUPN`nSD+ Ticket: $Info",
        "Confirm",
        "YesNo",
        "Question"
    )
    if ($Confirm -ne "Yes") {
        Write-Log "User cancelled mailbox creation for $MailboxName"
        return
    }
    #####
    
    # UI status and UI updating
    $LabelStatus.Content = "Creating mailbox..."
    $LabelStatus.Dispatcher.Invoke([Action]{
        $LabelStatus.InvalidateVisual()
    }, [System.Windows.Threading.DispatcherPriority]::Render)

    $ButtonCreate.IsEnabled = $false
    $Window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)


    <#===                              Creating Mailbox and Updating Attributes                               ===#>
    try {
        # Connect to Exchange
        $ConnectionUri = "http://xx.internal.xx.org.uk/PowerShell/"
        $PSSessionParams = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri     = $ConnectionUri
            Authentication    = 'Kerberos'
        }
        
        $Session = New-PSSession @PSSessionParams
        Import-PSSession $Session -DisableNameChecking -AllowClobber | Out-Null

        # Exchange duplicate detection
        $ExistingMailbox = Get-RemoteMailbox -Identity $MailboxAddress -ErrorAction SilentlyContinue
        if ($ExistingMailbox) {
            Remove-PSSession $Session
            [System.Windows.MessageBox]::Show("A mailbox already exists for $MailboxAddress.", "Duplicate")
            Write-Log "A mailbox already exists for $MailboxAddress."
            return
        }

        # Create mailbox
        $NewRemoteMailboxParams = @{
            Name = $MailboxName
            UserPrincipalName = $MailboxAddress
            OnPremisesOrganizationalUnit = $OU
            Shared = $True
        }
        
        New-RemoteMailbox @NewRemoteMailboxParams
        
        # Wait for AD user creation
        $ExistingUser = $null
        $ExistingUserParams = @{
            Server      = 'internal.xx.org.uk' # Need this as we are in a PSsession
            Filter      = "UserPrincipalName -eq '$MailboxAddress'"
            ErrorAction = 'SilentlyContinue'
        }
        
        for ($i = 1; $i -le 10; $i++) {
            $ExistingUser = Get-ADUser @ExistingUserParams
            if ($ExistingUser) { break }
            Start-Sleep -Seconds 5
        }

        if ($ExistingUser) {
            $MailboxDN = $ExistingUser.DistinguishedName
            $MailboxNotes = "Owners: $($PrimaryOwnerObject.Name), $($SecondaryOwnerObject.Name)" +
            "`r`n`r`n`r`nHistory`r`n=====`r`nCreation: (SD+ $Info)"
            
            # Update attributes - probably add these as a try/catch for logging
            Set-ADUser -Identity $MailboxDN -Description "$($MailboxType): $MailboxAddress"
            Set-ADUser -Identity $MailboxDN -Replace @{ info = $MailboxNotes }
            Set-ADUser -Identity $MailboxDN -Manager $PrimaryOwnerObject.DistinguishedName

            Remove-PSSession $Session
            [System.Windows.MessageBox]::Show("Mailbox created successfully.", "Success")
            Write-Log "Mailbox created successfully."
        }
        else {
            Remove-PSSession $Session
            [System.Windows.MessageBox]::Show("Mailbox created, but AD user could not be found.", "Warning")
            Write-Log "Mailbox created, but AD user could not be found."
        }

    }
    catch {
        [System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)", "Error")
        Write-Log "Error: $($_.Exception.Message)"
    }
    finally {
        $LabelStatus.Content = ""
        $ButtonCreate.IsEnabled = $true
    }
    <#===========================================================================================================#>
})

# Show window
$Window.ShowDialog() | Out-Null
