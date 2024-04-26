function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        [ValidateSet('Yes')]
        $IsSingleInstance,

        [Parameter()]
        [System.String]
        [ValidateSet('Audit','Enforce')]
        $BannedPasswordCheckOnPremisesMode,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheckOnPremises,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheck,

        [Parameter()]
        [System.Int32]
        $LockoutDurationInSeconds,

        [Parameter()]
        [System.Int32]
        $LockoutThreshold,

        [Parameter()]
        [System.String]
        $BannedPasswordList,

        #Auth
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    Write-Verbose -Message 'Getting configuration of AzureAD Groups Settings'
    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $nullReturn = $PSBoundParameters
    $nullReturn.Ensure = 'Absent'
    try
    {
        $consentSettingsTemplateId = '5cf42378-d67d-4f36-ba46-e8b86229381d' # Consent Policy Settings
        $Policy = Get-MgBetaDirectorySetting -ErrorAction Stop
        $Policy = Get-MgBetaDirectorySetting | Where-Object { $_.TemplateId -eq $consentSettingsTemplateId }

        if ($null -eq $Policy)
        {
            return $nullReturn
        }
        else
        {
            Write-Verbose -Message 'Get-TargetResource: Found existing directory setting'

            $result = @{
                IsSingleInstance                                = 'Yes'
                BannedPasswordCheckOnPremisesMode               = [String]($Policy.Values[0].Value)
                EnableBannedPasswordCheckOnPremises             = [Boolean]::Parse($Policy.Values[1].Value)
                EnableBannedPasswordCheck                      = [Boolean]::Parse($Policy.Values[2].Value)
                LockoutDurationInSeconds                        = [Int32]::Parse($Policy.Values[3].Value)
                LockoutThreshold                                = [Int32]::Parse($Policy.Values[4].Value)
                BannedPasswordList                              = [String]($Policy.Values[5].Value)
                Ensure                                          = 'Present'
                Credential                                      = $Credential
                ApplicationSecret                               = $ApplicationSecret
                ApplicationId                                   = $ApplicationId
                TenantId                                        = $TenantId
                CertificateThumbprint                           = $CertificateThumbprint
                Managedidentity                                 = $ManagedIdentity.IsPresent
            }

            Write-Verbose -Message "Get-TargetResource Result: `n $(Convert-M365DscHashtableToString -Hashtable $result)"
            return [System.Collections.Hashtable] $result
        }
    }
    catch
    {
        New-M365DSCLogEntry -Message 'Error retrieving data:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return $nullReturn
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        [ValidateSet('Yes')]
        $IsSingleInstance,

        [Parameter()]
        [System.String]
        [ValidateSet('Audit','Enforce')]
        $BannedPasswordCheckOnPremisesMode,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheckOnPremises,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheck,

        [Parameter()]
        [System.Int32]
        $LockoutDurationInSeconds,

        [Parameter()]
        [System.Int32]
        $LockoutThreshold,

        [Parameter()]
        [System.String]
        $BannedPasswordList,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    Write-Verbose -Message 'Setting configuration of Entra ID Groups Settings'

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentPolicy = Get-TargetResource @PSBoundParameters

    # Policy should exist but it doesn't
    $needToUpdate = $false
    if ($Ensure -eq 'Present' -and $currentPolicy.Ensure -eq 'Absent')
    {
        Write-Verbose 'Consent Policy not present'
        $consentSettingsTemplateId = '5cf42378-d67d-4f36-ba46-e8b86229381d' # Consent Policy Settings
        $params = @{
            TemplateId = $consentSettingsTemplateId
            Values     = @(
                @{
                    Name  = 'BannedPasswordCheckOnPremisesMode'
                    Value = 'Audit'

                }
                @{
                    Name  = 'ConstrainGroupSpecificConsentToMembersOfGroupId'
                    Value = ''
                }
                @{
                    Name  = 'EnableBannedPasswordCheckOnPremises'
                    Value = 'False'
                }
                @{
                    Name  = 'EnableBannedPasswordCheck'
                    Value = 'True'
                }
                @{
                    Name  = 'LockoutDurationInSeconds'
                    Value = '60'
                }
                @{
                    Name  = 'LockoutThreshold'
                    Value = '10'
                }
                @{
                    Name  = 'BannedPasswordList'
                    Value = ''
                }
            )
        }
        $ConsentSetting = New-MgBetaDirectorySetting -BodyParameter $params
        $needToUpdate = $true
    }

    $Policy = Get-MgBetaDirectorySetting | Where-Object -FilterScript { $_.DisplayName -eq 'Consent Policy Settings' }

    if (($Ensure -eq 'Present' -and $currentPolicy.Ensure -eq 'Present') -or $needToUpdate)
    {
        foreach ($property in $Policy.Values)
        {
            if ($property.Name -eq 'BannedPasswordCheckOnPremisesMode')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'BannedPasswordCheckOnPremisesMode' }
                $entry.Value = [System.String]$BannedPasswordCheckOnPremisesMode
            }
            elseif ($property.Name -eq 'EnableBannedPasswordCheckOnPremises')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'EnableBannedPasswordCheckOnPremises' }
                $entry.Value = [System.Boolean]$EnableBannedPasswordCheckOnPremises
            }
            elseif ($property.Name -eq 'EnableBannedPasswordCheck')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'EnableBannedPasswordCheck' }
                $entry.Value = [System.Boolean]$EnableBannedPasswordCheck
            }
            elseif ($property.Name -eq 'LockoutDurationInSeconds')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'LockoutDurationInSeconds' }
                $entry.Value = [System.Int32]$LockoutDurationInSeconds
            }
            elseif ($property.Name -eq 'LockoutThreshold')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'LockoutThreshold' }
                $entry.Value = [System.Int32]$LockoutThreshold
            }
            elseif ($property.Name -eq 'BannedPasswordList')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'BannedPasswordList' }
                $entry.Value = [System.String]$BannedPasswordList
            }
        }

        Write-Verbose -Message "Updating Policy's Values with $($Policy.Values | Out-String)"
        Update-MgBetaDirectorySetting -DirectorySettingId $Policy.id -Values $Policy.Values | Out-Null
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        [ValidateSet('Yes')]
        $IsSingleInstance,

        [Parameter()]
        [System.String]
        [ValidateSet('Audit','Enforce')]
        $BannedPasswordCheckOnPremisesMode,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheckOnPremises,

        [Parameter()]
        [System.Boolean]
        $EnableBannedPasswordCheck,

        [Parameter()]
        [System.Int32]
        $LockoutDurationInSeconds,

        [Parameter()]
        [System.Int32]
        $LockoutThreshold,

        [Parameter()]
        [System.String]
        $BannedPasswordList,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )


    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message 'Testing configuration of Entra ID Consent Settings'

    $CurrentValues = Get-TargetResource @PSBoundParameters

    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    $ValuesToCheck = $PSBoundParameters

    $TestResult = Test-M365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck $ValuesToCheck.Keys

    Write-Verbose -Message "Test-TargetResource returned $TestResult"

    return $TestResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ApplicationSecret,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    $ConnectionMode = New-M365DSCConnection -Workload 'MicrosoftGraph' `
        -InboundParameters $PSBoundParameters

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        $Params = @{
            ApplicationId         = $ApplicationId
            TenantId              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
            IsSingleInstance      = 'Yes'
            ApplicationSecret     = $ApplicationSecret
            Credential            = $Credential
            Managedidentity       = $ManagedIdentity.IsPresent
        }
        $dscContent = ''
        $Results = Get-TargetResource @Params
        $Results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
            -Results $Results
        $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
            -ConnectionMode $ConnectionMode `
            -ModulePath $PSScriptRoot `
            -Results $Results `
            -Credential $Credential
        $dscContent += $currentDSCBlock
        Save-M365DSCPartialExport -Content $currentDSCBlock `
            -FileName $Global:PartialExportFileName
        Write-Host $Global:M365DSCEmojiGreenCheckMark
        return $dscContent
    }
    catch
    {
        Write-Host $Global:M365DSCEmojiRedX

        New-M365DSCLogEntry -Message 'Error during Export:' `
            -Exception $_ `
            -Source $($MyInvocation.MyCommand.Source) `
            -TenantId $TenantId `
            -Credential $Credential

        return ''
    }
}

Export-ModuleMember -Function *-TargetResource
