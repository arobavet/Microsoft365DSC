<#
This example is used to test new resources and showcase the usage of new resources being worked on.
It is not meant to use as a production baseline.
#>

Configuration Example
{
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $credsCredential
    )

    Import-DscResource -ModuleName Microsoft365DSC

    Node localhost
    {
        AADDirectorySetting "AADDirectorySetting"
        {
            BlockUserConsentForRiskyApps                    = "True";
            ConstrainGroupSpecificConsentToMembersOfGroupId = "";
            Credential                                      = $Credscredential;
            DisplayName                                     = "Consent Policy Settings";
            EnableAdminConsentRequests                      = "False";
            EnableGroupSpecificConsent                      = "True";
            Ensure                                          = "Present";
            Id                                              = "6b79d399-25e5-4528-ba41-219d0b32ec46";
            IsSingleInstance                                = "Yes";
        }
    }
}
