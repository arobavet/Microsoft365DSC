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
        $DisplayName,

        [Parameter()]
        [System.Boolean]
        $EnableGroupSpecificConsent,

        [Parameter()]
        [System.Boolean]
        $BlockUserConsentForRiskyApps,

        [Parameter()]
        [System.Boolean]
        $EnableAdminConsentRequests,

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
        $consentSettingsTemplateId = 'dffd5d46-495d-40a9-8e21-954ff55e198a' # Consent Policy Settings
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
                DisplayName                                     = $Policy.DisplayName
                EnableGroupSpecificConsent                      = [System.Boolean]$Policy.Values[0].Value
                BlockUserConsentForRiskyApps                    = [System.Boolean]$Policy.Values[1].Value
                EnableAdminConsentRequests                      = [System.Boolean]$Policy.Values[2].Value
                ConstrainGroupSpecificConsentToMembersOfGroupId = [System.String]$Policy.Values[3].Value
                Ensure                                          = 'Present'
                Credential                                      = $Credential
                ApplicationSecret                               = $ApplicationSecret
                ApplicationId                                   = $ApplicationId
                TenantId                                        = $TenantId
                CertificateThumbprint                           = $CertificateThumbprint
                Managedidentity                                 = $ManagedIdentity.IsPresent
                Id                                              = $Policy.Id
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
        $DisplayName,

        [Parameter()]
        [System.Boolean]
        $EnableGroupSpecificConsent,

        [Parameter()]
        [System.Boolean]
        $BlockUserConsentForRiskyApps,

        [Parameter()]
        [System.Boolean]
        $EnableAdminConsentRequests,

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
        $consentSettingsTemplateId = 'dffd5d46-495d-40a9-8e21-954ff55e198a' # Consent Policy Settings
        $params = @{
            TemplateId = $consentSettingsTemplateId
            Values     = @(
                @{
                    Name  = 'BlockUserConsentForRiskyApps'
                    Value = 'True'
                }
                @{
                    Name  = 'ConstrainGroupSpecificConsentToMembersOfGroupId'
                    Value = ''
                }
                @{
                    Name  = 'EnableAdminConsentRequests'
                    Value = 'True'
                }
                @{
                    Name  = 'EnableGroupSpecificConsent'
                    Value = 'True'
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
            if ($property.Name -eq 'EnableGroupSpecificConsent')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'EnableGroupSpecificConsent' }
                $entry.Value = [System.Boolean]$EnableGroupSpecificConsent
            }
            elseif ($property.Name -eq 'BlockUserConsentForRiskyApps')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'BlockUserConsentForRiskyApps' }
                $entry.Value = [System.Boolean]$BlockUserConsentForRiskyApps
            }
            elseif ($property.Name -eq 'EnableAdminConsentRequests')
            {
                $entry = $Policy.Values | Where-Object -FilterScript { $_.Name -eq 'EnableAdminConsentRequests' }
                $entry.Value = [System.Boolean]$EnableAdminConsentRequests
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
        $DisplayName,

        [Parameter()]
        [System.Boolean]
        $EnableGroupSpecificConsent,

        [Parameter()]
        [System.Boolean]
        $BlockUserConsentForRiskyApps,

        [Parameter()]
        [System.Boolean]
        $EnableAdminConsentRequests,

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
